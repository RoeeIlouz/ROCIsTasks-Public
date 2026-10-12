import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_tasks/core/utils/app_date_formats.dart';
import 'package:rocis_tasks/core/utils/bidi_utils.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class GoogleCalendarEventDetailSheet extends StatelessWidget {
  final Event event;
  final Color eventColor;
  final String calendarName;

  const GoogleCalendarEventDetailSheet({
    super.key,
    required this.event,
    required this.eventColor,
    required this.calendarName,
  });

  /// Strips HTML tags, decodes common entities, and formats line breaks.
  static String cleanHtmlDescription(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    var text = raw
        .replaceAll(RegExp(r'<br\s*[\/]?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\/p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
        .replaceAll(RegExp(r'&lt;', caseSensitive: false), '<')
        .replaceAll(RegExp(r'&gt;', caseSensitive: false), '>')
        .replaceAll(RegExp(r'&quot;', caseSensitive: false), '"')
        .replaceAll(RegExp(r'&#39;|&apos;', caseSensitive: false), "'");

    // Remove remaining HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // Collapse 3+ consecutive newlines into 2
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  /// Detects Google Meet, Zoom, Teams, or Webex links from URL, location, and description.
  ({String label, IconData icon, Uri url})? _detectMeetingLink() {
    final pool = <String>[
      if (event.url != null) event.url.toString(),
      if (event.location != null) event.location!,
      if (event.description != null) event.description!,
    ].join(' ');

    // 1. Google Meet
    final meetMatch = RegExp(
      r'https?:\/\/meet\.google\.com\/[a-z0-9\-]+',
      caseSensitive: false,
    ).firstMatch(pool);
    if (meetMatch != null) {
      final uri = Uri.tryParse(meetMatch.group(0)!);
      if (uri != null) {
        return (label: 'Google Meet', icon: Icons.videocam_rounded, url: uri);
      }
    }

    // 2. Zoom
    final zoomMatch = RegExp(
      r'https?:\/\/[a-z0-9\.\-]*zoom\.us\/[j|s|my|w]\/[a-zA-Z0-9\?=\-_&]+',
      caseSensitive: false,
    ).firstMatch(pool);
    if (zoomMatch != null) {
      final uri = Uri.tryParse(zoomMatch.group(0)!);
      if (uri != null) {
        return (label: 'Zoom Meeting', icon: Icons.videocam_rounded, url: uri);
      }
    }

    // 3. Microsoft Teams
    final teamsMatch = RegExp(
      r'https?:\/\/teams\.microsoft\.com\/l\/meetup-join\/[^\s<>"]+',
      caseSensitive: false,
    ).firstMatch(pool);
    if (teamsMatch != null) {
      final uri = Uri.tryParse(teamsMatch.group(0)!);
      if (uri != null) {
        return (label: 'Microsoft Teams', icon: Icons.videocam_rounded, url: uri);
      }
    }

    // 4. Webex
    final webexMatch = RegExp(
      r'https?:\/\/[a-z0-9\.\-]*webex\.com\/[^\s<>"]+',
      caseSensitive: false,
    ).firstMatch(pool);
    if (webexMatch != null) {
      final uri = Uri.tryParse(webexMatch.group(0)!);
      if (uri != null) {
        return (label: 'Webex Meeting', icon: Icons.videocam_rounded, url: uri);
      }
    }

    return null;
  }

  Future<void> _openInGoogleCalendar(BuildContext context) async {
    HapticFeedback.lightImpact();

    // 1. If explicit URL exists, launch it
    if (event.url != null) {
      final launched = await launchUrl(
        event.url!,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    }

    // 2. Try native android calendar event URI if eventId is available
    final eventId = event.eventId;
    if (eventId != null && eventId.isNotEmpty) {
      final nativeUri = Uri.parse('content://com.android.calendar/events/$eventId');
      try {
        final launched = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {}
    }

    // 3. Fallback to Google Calendar web search by event title
    final title = event.title?.trim() ?? '';
    final searchUri = Uri.https('calendar.google.com', '/calendar/r/search', {
      if (title.isNotEmpty) 'q': title,
    });
    try {
      await launchUrl(searchUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _copyToRocisTasks(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context)!;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    final title = event.title?.trim().isNotEmpty == true
        ? event.title!.trim()
        : l10n.noTitle;
    final cleanDesc = cleanHtmlDescription(event.description);
    final location = event.location?.trim() ?? '';

    final descBuffer = StringBuffer();
    if (cleanDesc.isNotEmpty) {
      descBuffer.write(cleanDesc);
    }
    if (location.isNotEmpty) {
      if (descBuffer.isNotEmpty) descBuffer.write('\n\n');
      descBuffer.write('📍 $location');
    }

    final dueDate = event.start?.toLocal();

    await taskProvider.addTask(
      title,
      descBuffer.toString(),
      dueDate,
      TaskPriority.medium,
      null,
    );

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.eventCopiedToTasks),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final themeService = Provider.of<ThemeService>(context, listen: false);

    final title = event.title?.trim().isNotEmpty == true
        ? event.title!.trim()
        : l10n.noTitle;
    final cleanDesc = cleanHtmlDescription(event.description);
    final location = event.location?.trim() ?? '';
    final meeting = _detectMeetingLink();
    final isAllDay = event.allDay == true;

    final timeFormat = AppDateFormats.time(
      context,
      use24h: themeService.use24HourFormat,
    );
    final dateFormat = DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString());

    final startTime = event.start?.toLocal();
    final endTime = event.end?.toLocal();

    String timeRangeStr = '';
    if (isAllDay) {
      timeRangeStr = l10n.allDay;
    } else if (startTime != null && endTime != null) {
      timeRangeStr = '${timeFormat.format(startTime)} – ${timeFormat.format(endTime)}';
      final diff = endTime.difference(startTime);
      if (diff.inMinutes > 0) {
        if (diff.inHours > 0) {
          final mins = diff.inMinutes % 60;
          timeRangeStr += ' (${diff.inHours}h${mins > 0 ? ' ${mins}m' : ''})';
        } else {
          timeRangeStr += ' (${diff.inMinutes}m)';
        }
      }
    } else if (startTime != null) {
      timeRangeStr = timeFormat.format(startTime);
    }

    final attendees = event.attendees
        ?.where((a) => a != null && (a.name?.isNotEmpty == true || a.emailAddress?.isNotEmpty == true))
        .cast<Attendee>()
        .toList() ??
        [];

    return GlassContainer(
      opacity: 0.95,
      tintColor: eventColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      border: Border.all(
        color: isDark
            ? eventColor.withValues(alpha: 0.28)
            : eventColor.withValues(alpha: 0.18),
        width: 1.2,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: eventColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.event_note_rounded,
                        color: eventColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            textDirection: BidiUtils.of(context, title),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: eventColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              calendarName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: eventColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, indent: 20, endIndent: 20),
              const SizedBox(height: 16),

              // Date & Time
              if (startTime != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: eventColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateFormat.format(startTime),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (timeRangeStr.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                timeRangeStr,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Meeting Callout (Google Meet, Zoom, Teams)
              if (meeting != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: eventColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: eventColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: eventColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            meeting.icon,
                            color: eventColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meeting.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                meeting.url.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            launchUrl(
                              meeting.url,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: eventColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.videocam_rounded, size: 16),
                          label: Text(
                            l10n.joinMeeting,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Location
              if (location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: eventColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              location,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    final mapUri = Uri.parse(
                                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}',
                                    );
                                    launchUrl(mapUri, mode: LaunchMode.externalApplication);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.directions_outlined, size: 14, color: eventColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          l10n.openInMaps,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: eventColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Clipboard.setData(ClipboardData(text: location));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.locationCopied),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.copy_rounded, size: 14, color: eventColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          l10n.copyLocation,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: eventColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Description / Notes
              if (cleanDesc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.notes_rounded,
                          size: 18,
                          color: eventColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: SelectableText(
                            cleanDesc,
                            textDirection: BidiUtils.of(context, cleanDesc),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Attendees
              if (attendees.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: eventColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.attendees} (${attendees.length})',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: attendees.map((att) {
                                final label = att.name?.isNotEmpty == true
                                    ? att.name!
                                    : (att.emailAddress ?? '');
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: att.isOrganiser
                                        ? eventColor.withValues(alpha: 0.15)
                                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: att.isOrganiser
                                          ? eventColor.withValues(alpha: 0.3)
                                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (att.isOrganiser) ...[
                                        Icon(
                                          Icons.stars_rounded,
                                          size: 12,
                                          color: eventColor,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: att.isOrganiser
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: att.isOrganiser
                                              ? eventColor
                                              : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(height: 1, indent: 20, endIndent: 20),
              const SizedBox(height: 16),

              // Bottom Actions: Open in Google Calendar + Copy to ROCIs Tasks
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openInGoogleCalendar(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: eventColor.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        icon: Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                          color: eventColor,
                        ),
                        label: Text(
                          l10n.openInGoogleCalendar,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: eventColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _copyToRocisTasks(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: eventColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.add_task_rounded,
                          size: 18,
                        ),
                        label: Text(
                          l10n.copyToTasks,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
