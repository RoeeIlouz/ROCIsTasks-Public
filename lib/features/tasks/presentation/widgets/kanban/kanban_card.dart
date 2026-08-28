import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class KanbanCard extends StatelessWidget {
  final Task task;
  final List<Category> categories;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  const KanbanCard({
    super.key,
    required this.task,
    this.categories = const [],
    this.onToggle,
    this.onTap,
  });

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return const Color(0xFFEF4444);
      case TaskPriority.medium:
        return const Color(0xFFF59E0B);
      case TaskPriority.low:
        return const Color(0xFF10B981);
    }
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    final difference = taskDate.difference(today).inDays;

    if (difference == 0) {
      return DateFormat.jm().format(date);
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference > 1 && difference < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  bool _isOverdue(DateTime date) {
    final now = DateTime.now();
    return date.isBefore(now) && !task.isCompleted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final priorityColor = _getPriorityColor(task.priority);
    final primaryCategory = categories.isNotEmpty ? categories.first : null;
    final categoryColor = primaryCategory != null
        ? Color(primaryCategory.colorValue)
        : theme.colorScheme.primary;

    final subtasks = task.subTasks ?? [];
    final completedSubtasks = subtasks.where((st) => st.isCompleted).length;

    Widget cardContent({bool isDragging = false}) {
      return GlassContainer(
        borderRadius: BorderRadius.circular(16),
        color: primaryCategory != null
            ? categoryColor
            : (task.isCompleted
                ? (isDark ? Colors.grey.shade900 : Colors.grey.shade200)
                : null),
        elevation: isDragging ? 8.0 : 1.5,
        child: InkWell(
          onTap: onTap ??
              () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetailScreen(
                      task: task,
                      category: primaryCategory,
                    ),
                  ),
                );
              },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Priority, Categories & Sync Icons Row
                Row(
                  children: [
                    // Priority pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: priorityColor.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: priorityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.priority.name.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (task.syncWithGoogleTasks)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.sync_rounded,
                          size: 13,
                          color: theme.colorScheme.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    if (task.recurrenceRule != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.repeat_rounded,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (task.isPinned ?? false)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.push_pin_rounded,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Checkbox and Title Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (onToggle != null) {
                          onToggle!();
                        } else {
                          Provider.of<TaskProvider>(
                            context,
                            listen: false,
                          ).toggleTaskCompletion(task);
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2, right: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: task.isCompleted
                                ? (primaryCategory != null
                                    ? categoryColor
                                    : theme.colorScheme.primary)
                                : Colors.transparent,
                            border: Border.all(
                              color: task.isCompleted
                                  ? (primaryCategory != null
                                      ? categoryColor
                                      : theme.colorScheme.primary)
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: task.isCompleted
                              ? const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: task.isCompleted
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                              : theme.colorScheme.onSurface,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),

                // Description preview if available
                if (task.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      task.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Footer row: Category chips, Due Date, Subtask count
                Row(
                  children: [
                    // Category dots / chips
                    if (categories.isNotEmpty) ...[
                      Wrap(
                        spacing: 4,
                        children: categories.take(2).map((cat) {
                          final cColor = Color(cat.colorValue);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cat.name,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: cColor,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Subtasks indicator
                    if (subtasks.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.checklist_rounded,
                              size: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$completedSubtasks/${subtasks.length}',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],

                    const Spacer(),

                    // Due Date Chip
                    if (task.dueDate != null) ...[
                      Builder(builder: (context) {
                        final isOverdue = _isOverdue(task.dueDate!);
                        final dateColor = isOverdue
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                                : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 10,
                                color: dateColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatDueDate(task.dueDate!),
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: dateColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final draggableCard = LongPressDraggable<Task>(
      data: task,
      hapticFeedbackOnStart: true,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          width: 260,
          child: Transform.rotate(
            angle: -0.04,
            child: Opacity(
              opacity: 0.92,
              child: cardContent(isDragging: true),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: cardContent(),
      ),
      child: cardContent(),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: draggableCard,
    );
  }
}
