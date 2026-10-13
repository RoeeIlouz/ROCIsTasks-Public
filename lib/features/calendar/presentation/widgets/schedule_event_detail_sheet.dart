import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_tasks/core/services/schedule_bridge_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/core/utils/app_date_formats.dart';
import 'package:rocis_tasks/core/utils/bidi_utils.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

/// Detail popup for a ROCIs Schedule class, the counterpart of
/// GoogleCalendarEventDetailSheet.
class ScheduleEventDetailSheet extends StatelessWidget {
  final SyncedScheduleEvent event;

  /// The calendar day the user tapped. Recurring classes carry the date of
  /// their first occurrence, so the sheet shows this day's occurrence instead.
  final DateTime day;

  const ScheduleEventDetailSheet({
    super.key,
    required this.event,
    required this.day,
  });

  /// Start and end of the occurrence on [day].
  ({DateTime start, DateTime end}) get occurrence {
    if (!event.recurring) {
      return (start: event.startTime, end: event.endTime);
    }
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      event.startTime.hour,
      event.startTime.minute,
    );
    return (start: start, end: start.add(event.endTime.difference(event.startTime)));
  }

  /// Display title: the course name, falling back to the event title.
  String displayTitle(AppLocalizations l10n) {
    if (event.courseName.trim().isNotEmpty) return event.courseName.trim();
    if (event.title.trim().isNotEmpty) return event.title.trim();
    return l10n.noTitle;
  }

  /// The event title, when it adds something beyond the course name.
  String? get subtitle {
    final title = event.title.trim();
    if (title.isEmpty || event.courseName.trim().isEmpty) return null;
    if (title.toLowerCase() == event.courseName.trim().toLowerCase()) return null;
    return title;
  }

  // Mirrors EventType in ROCIs Schedule: class, exam, lab, study, other.
  static IconData typeIcon(int typeIndex) {
    switch (typeIndex) {
      case 1:
        return Icons.assignment_outlined;
      case 2:
        return Icons.science_outlined;
      case 3:
        return Icons.menu_book_outlined;
      case 4:
        return Icons.event_outlined;
      default:
        return Icons.school_rounded;
    }
  }

  static String typeLabel(AppLocalizations l10n, int typeIndex) {
    switch (typeIndex) {
      case 1:
        return l10n.scheduleTypeExam;
      case 2:
        return l10n.scheduleTypeLab;
      case 3:
        return l10n.scheduleTypeStudy;
      case 4:
        return l10n.scheduleTypeOther;
      default:
        return l10n.scheduleTypeClass;
    }
  }

  /// Localized short weekday names for the schedule's days, Sunday first
  /// (Schedule convention: 0=Sun ... 6=Sat).
  static String weekdayList(List<int> daysOfWeek, String locale) {
    final format = DateFormat.E(locale);
    final days = daysOfWeek.where((d) => d >= 0 && d <= 6).toSet().toList()
      ..sort();
    // 2026-10-11 is a Sunday.
    return days
        .map((d) => format.format(DateTime(2026, 10, 11 + d)))
        .join(', ');
  }

  Future<void> _copyToRocisTasks(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context)!;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    final sub = subtitle;
    final title = sub != null
        ? '${displayTitle(l10n)} - $sub'
        : displayTitle(l10n);
    final notes = event.notes.trim();
    final location = event.location.trim();

    final descBuffer = StringBuffer();
    if (notes.isNotEmpty) descBuffer.write(notes);
    if (location.isNotEmpty) {
      if (descBuffer.isNotEmpty) descBuffer.write('\n\n');
      descBuffer.write('📍 $location');
    }

    await taskProvider.addTask(
      title,
      descBuffer.toString(),
      occurrence.start,
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
    final locale = Localizations.localeOf(context).toString();
    final eventColor = event.color;

    final title = displayTitle(l10n);
    final sub = subtitle;
    final notes = event.notes.trim();
    final location = event.location.trim();
    final occ = occurrence;

    final timeFormat = AppDateFormats.time(
      context,
      use24h: themeService.use24HourFormat,
    );
    final dateFormat = DateFormat.yMMMMEEEEd(locale);

    var timeRangeStr =
        '${timeFormat.format(occ.start)} – ${timeFormat.format(occ.end)}';
    final diff = occ.end.difference(occ.start);
    if (diff.inMinutes > 0) {
      if (diff.inHours > 0) {
        final mins = diff.inMinutes % 60;
        timeRangeStr += ' (${diff.inHours}h${mins > 0 ? ' ${mins}m' : ''})';
      } else {
        timeRangeStr += ' (${diff.inMinutes}m)';
      }
    }

    final repeatDays = event.recurring
        ? weekdayList(event.daysOfWeek, locale)
        : '';

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
                        typeIcon(event.typeIndex),
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
                          if (sub != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              sub,
                              textDirection: BidiUtils.of(context, sub),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: eventColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Chip(
                                label: typeLabel(l10n, event.typeIndex),
                                color: eventColor,
                              ),
                              if (event.courseCode.trim().isNotEmpty)
                                _Chip(
                                  label: event.courseCode.trim(),
                                  color: eventColor,
                                ),
                              _Chip(label: 'ROCIs Schedule', color: eventColor),
                            ],
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
              _InfoRow(
                icon: Icons.calendar_today_rounded,
                color: eventColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(occ.start),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeRangeStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Weekly recurrence
              if (repeatDays.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.repeat_rounded,
                  color: eventColor,
                  child: Text(
                    l10n.scheduleRepeatsWeekly(repeatDays),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              // Location
              if (location.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  color: eventColor,
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
                          _LinkAction(
                            icon: Icons.directions_outlined,
                            label: l10n.openInMaps,
                            color: eventColor,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final mapUri = Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}',
                              );
                              launchUrl(
                                mapUri,
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          _LinkAction(
                            icon: Icons.copy_rounded,
                            label: l10n.copyLocation,
                            color: eventColor,
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Notes
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.notes_rounded,
                  color: eventColor,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: SelectableText(
                      notes,
                      textDirection: BidiUtils.of(context, notes),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(height: 1, indent: 20, endIndent: 20),
              const SizedBox(height: 16),

              // Bottom Actions: Open in ROCIs Schedule + Copy to ROCIs Tasks
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ScheduleBridgeService.openScheduleEvent(
                            eventId: event.id,
                          );
                        },
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
                          l10n.openInRocisSchedule,
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
                        icon: const Icon(Icons.add_task_rounded, size: 18),
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

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Widget child;

  const _InfoRow({required this.icon, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _LinkAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LinkAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
