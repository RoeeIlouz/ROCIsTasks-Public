import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/models/schedule_assignment.dart';
import 'package:rocis_tasks/core/utils/app_date_formats.dart';
import 'package:rocis_tasks/core/utils/attachment_utils.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/schedule_assignments_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

/// ROCIs Schedule assignments: what is due, which lecture each came from,
/// and the photos and files attached to it.
class ScheduleAssignmentsScreen extends StatefulWidget {
  const ScheduleAssignmentsScreen({super.key});

  @override
  State<ScheduleAssignmentsScreen> createState() =>
      _ScheduleAssignmentsScreenState();
}

class _ScheduleAssignmentsScreenState extends State<ScheduleAssignmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ScheduleAssignmentsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<ScheduleAssignmentsProvider>();
    final now = DateTime.now();

    final sections = <(String, List<ScheduleAssignment>)>[
      (l10n.scheduleAssignmentsOverdue, provider.overdue(now)),
      (l10n.scheduleAssignmentsUpcoming, provider.upcoming(now)),
      (l10n.scheduleAssignmentsCompleted, provider.completed()),
    ].where((s) => s.$2.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.scheduleAssignmentsTitle,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.load(forceRefresh: true),
        child: provider.isLoading && !provider.hasLoaded
            ? const Center(child: CircularProgressIndicator())
            : sections.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      l10n.scheduleAssignmentsEmpty,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      l10n.scheduleAssignmentsHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                children: [
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                      child: Text(
                        '${section.$1}  (${section.$2.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    for (final a in section.$2)
                      _AssignmentCard(assignment: a, now: now),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Text(
                      l10n.scheduleAssignmentsHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final ScheduleAssignment assignment;
  final DateTime now;

  const _AssignmentCard({required this.assignment, required this.now});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final provider = context.read<ScheduleAssignmentsProvider>();
    final a = assignment;
    final overdue = a.isOverdue(now);
    final dateFormat = AppDateFormats.pattern(context, 'EEE, MMM d');

    final String? lectureLine;
    if (a.hasLecture) {
      final lecture = provider.lectureFor(a);
      final date = dateFormat.format(a.lectureDate!);
      final title = lecture?.title.trim() ?? '';
      lectureLine = title.isEmpty
          ? l10n.scheduleAssignmentGivenOn(date)
          : l10n.scheduleAssignmentGivenIn(title, date);
    } else {
      lectureLine = null;
    }

    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return GlassContainer(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      tintColor: a.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: a.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.courseName.isEmpty ? a.courseCode : a.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: a.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (a.priority == 2)
                Text(
                  l10n.high,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            a.title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              decoration: a.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 14,
                color: overdue ? Colors.red : muted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.scheduleAssignmentDue(dateFormat.format(a.dueDate)),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: overdue ? FontWeight.w600 : FontWeight.normal,
                    color: overdue ? Colors.red : muted,
                  ),
                ),
              ),
            ],
          ),
          if (lectureLine != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.school_rounded, size: 14, color: muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    lectureLine,
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ),
              ],
            ),
          ],
          if (a.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(a.description.trim(), style: const TextStyle(fontSize: 13)),
          ],
          if (a.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final att in a.attachments)
                  ActionChip(
                    avatar: Icon(
                      AttachmentUtils.getFileIcon(att.name),
                      size: 16,
                    ),
                    label: Text(att.name, overflow: TextOverflow.ellipsis),
                    onPressed: () => _open(context, provider, att),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    ScheduleAssignmentsProvider provider,
    ScheduleAttachment att,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await provider.bytesFor(assignment, att);
    if (!context.mounted) return;
    if (bytes == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.scheduleAssignmentAttachmentUnavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await AttachmentUtils.openBytes(
      context,
      name: att.name,
      mime: att.mime,
      bytes: bytes,
    );
  }
}
