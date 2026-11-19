import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/models/schedule_assignment.dart';
import 'package:rocis_tasks/core/utils/app_date_formats.dart';
import 'package:rocis_tasks/core/utils/bidi_utils.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/schedule_assignments_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/screens/schedule_assignments_screen.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';

/// Marks a ROCIs Schedule assignment done (or not) and says so when ROCIs
/// Schedule could not be updated, in which case it stays as it was.
Future<void> setScheduleAssignmentDone(
  BuildContext context,
  ScheduleAssignment assignment,
  bool done,
) async {
  final provider = context.read<ScheduleAssignmentsProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final tasks = context.read<TaskProvider?>();
  final message = AppLocalizations.of(context)!.scheduleAssignmentSaveFailed;
  HapticFeedback.lightImpact();
  final saved = await provider.setCompleted(assignment, done);
  if (!saved) {
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  } else {
    // Home-screen widgets list assignments too.
    tasks?.updateAllWidgets();
  }
}

/// The unfinished ROCIs Schedule assignments, as their own collapsible
/// section above the task list, each drawn as a task card. They have no swipe or delete: an assignment only leaves this
/// list once it is marked done.
class ScheduleAssignmentsSection extends StatefulWidget {
  const ScheduleAssignmentsSection({super.key});

  @override
  State<ScheduleAssignmentsSection> createState() =>
      _ScheduleAssignmentsSectionState();
}

class _ScheduleAssignmentsSectionState
    extends State<ScheduleAssignmentsSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleAssignmentsProvider>();
    final pending = provider.pending;
    if (pending.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // Soonest due first, like tasks sorted by date.
    final sorted = [...pending]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final maxHeight = MediaQuery.sizeOf(context).height * 0.4;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _expanded,
            onExpansionChanged: (v) => setState(() => _expanded = v),
            leading: Icon(
              Icons.assignment_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            title: Text(
              l10n.scheduleAssignmentsSection('${pending.length}'),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final a in sorted)
                        ScheduleAssignmentTaskTile(
                          key: ValueKey('assignment-${a.id}'),
                          assignment: a,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An unfinished assignment drawn like a task card in the task list: a
/// checkbox (or a swipe right) marks it done, chips show its course and due
/// date, and tapping it opens the assignments screen. It has no delete or
/// pin, since the assignment belongs to ROCIs Schedule.
class ScheduleAssignmentTaskTile extends StatelessWidget {
  final ScheduleAssignment assignment;

  const ScheduleAssignmentTaskTile({super.key, required this.assignment});

  static const _priorityColors = [
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.redAccent,
  ];

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const ScheduleAssignmentsScreen()),
  );

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final themeService = context.watch<ThemeService>();
    final a = assignment;
    final course = a.courseName.isEmpty ? a.courseCode : a.courseName;
    final overdue = a.isOverdue(DateTime.now());
    final hasTime = a.dueDate.hour != 0 || a.dueDate.minute != 0;
    final dueLabel = [
      AppDateFormats.pattern(context, 'EEE, MMM d').format(a.dueDate),
      if (hasTime)
        AppDateFormats.time(
          context,
          use24h: themeService.use24HourFormat,
        ).format(a.dueDate),
    ].join(' ');
    final priority =
        TaskPriority.values[a.priority.clamp(0, TaskPriority.values.length - 1)];
    final priorityColor = _priorityColors[priority.index];
    final feedback = themeService.taskCompletionFeedback;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RepaintBoundary(
        child: Dismissible(
          key: ValueKey('schedule-assignment-${a.id}'),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (_) async {
            if (feedback) HapticFeedback.heavyImpact();
            await setScheduleAssignmentDone(context, a, true);
            return false;
          },
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.markAsComplete,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          child: GlassContainer(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            tintColor: a.color,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 6,
                right: 16,
                top: 10,
                bottom: 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BouncyCheckbox(
                    isChecked: false,
                    onTap: () => setScheduleAssignmentDone(context, a, true),
                    size: 26,
                    activeColor: a.color,
                    borderColor: a.color.withValues(alpha: 0.5),
                    enableHaptics: feedback,
                    semanticsLabel: l10n.scheduleAssignmentMarkDone,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: () => _open(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              a.title,
                              textDirection: BidiUtils.of(context, a.title),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (a.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  a.description,
                                  textDirection: BidiUtils.of(
                                    context,
                                    a.description,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (course.isNotEmpty)
                                  _chip(
                                    icon: Icons.school_rounded,
                                    label: course,
                                    color: a.color,
                                  ),
                                _chip(
                                  icon: Icons.event_rounded,
                                  label: dueLabel,
                                  color: overdue
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary,
                                ),
                                if (a.attachments.isNotEmpty)
                                  _chip(
                                    icon: Icons.attach_file_rounded,
                                    label: '${a.attachments.length}',
                                    color: theme.colorScheme.primary,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: priorityColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        AppDateFormats.priority(l10n, priority).toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
