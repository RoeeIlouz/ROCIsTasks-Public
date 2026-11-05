import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/models/schedule_assignment.dart';
import 'package:rocis_tasks/core/utils/app_date_formats.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/schedule_assignments_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/screens/schedule_assignments_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

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

/// The unfinished ROCIs Schedule assignments, as their own section above the
/// task list. They have no swipe or delete: an assignment only leaves this
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
    final now = DateTime.now();
    final dateFormat = AppDateFormats.pattern(context, 'EEE, MMM d');
    final maxHeight = MediaQuery.sizeOf(context).height * 0.32;

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
                      for (final a in pending)
                        ScheduleAssignmentRow(
                          assignment: a,
                          overdue: a.isOverdue(now),
                          dateLabel: dateFormat.format(a.dueDate),
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

/// One unfinished assignment: a checkbox that marks it done, its course and
/// due date. Tapping the rest opens the full assignments screen.
class ScheduleAssignmentRow extends StatelessWidget {
  final ScheduleAssignment assignment;
  final bool overdue;
  final String dateLabel;

  const ScheduleAssignmentRow({
    super.key,
    required this.assignment,
    required this.overdue,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final a = assignment;
    final course = a.courseName.isEmpty ? a.courseCode : a.courseName;
    final due = l10n.scheduleAssignmentDue(dateLabel);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Tooltip(
        message: l10n.scheduleAssignmentMarkDone,
        child: Checkbox(
          value: false,
          shape: const CircleBorder(),
          side: BorderSide(color: a.color, width: 2),
          onChanged: (_) => setScheduleAssignmentDone(context, a, true),
        ),
      ),
      title: Text(
        a.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        course.isEmpty ? due : '$course  ·  $due',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: overdue
              ? Colors.red
              : theme.colorScheme.onSurface.withValues(alpha: 0.65),
          fontWeight: overdue ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: a.color, shape: BoxShape.circle),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ScheduleAssignmentsScreen()),
      ),
    );
  }
}
