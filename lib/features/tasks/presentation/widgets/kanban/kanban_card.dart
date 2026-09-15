import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/shared/ui/widgets/bouncy_checkbox.dart';
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

  bool _isTaskFeedbackEnabled(BuildContext context) {
    try {
      final themeService = Provider.of<ThemeService>(context, listen: false);
      final dynamic val = themeService.taskCompletionFeedback;
      return val == true;
    } catch (_) {
      return true;
    }
  }

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
    final hasTaskFeedback = _isTaskFeedbackEnabled(context);

    final subtasks = task.subTasks ?? [];
    final completedSubtasks = subtasks.where((st) => st.isCompleted).length;

    Widget cardContent({bool isDragging = false}) {
      return GlassContainer(
        borderRadius: BorderRadius.circular(16),
        color: task.isCompleted
            ? (isDark ? Colors.grey.shade900 : Colors.grey.shade200)
            : null,
        tintColor: primaryCategory != null ? categoryColor : null,
        border: Border.all(
          color: isDark
              ? (primaryCategory != null
                    ? categoryColor.withValues(alpha: 0.25)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.2))
              : (primaryCategory != null
                    ? categoryColor.withValues(alpha: 0.18)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
          width: 1.0,
        ),
        elevation: isDragging ? 8.0 : 1.5,
        child: InkWell(
          onTap:
              onTap ??
              () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TaskDetailScreen(task: task, category: primaryCategory),
                  ),
                );
              },
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (primaryCategory != null)
                  Container(
                    width: 3.5,
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                    ).copyWith(left: 6),
                    decoration: BoxDecoration(
                      color: task.isCompleted
                          ? categoryColor.withValues(alpha: 0.4)
                          : categoryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: primaryCategory != null ? 8 : 12,
                      right: 12,
                      top: 12,
                      bottom: 12,
                    ),
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
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.7,
                                  ),
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
                            Padding(
                              padding: const EdgeInsets.only(top: 1, right: 8),
                              child: BouncyCheckbox(
                                isChecked: task.isCompleted,
                                size: 20,
                                activeColor: primaryCategory != null
                                    ? categoryColor
                                    : theme.colorScheme.primary,
                                borderColor:
                                    (primaryCategory != null
                                            ? categoryColor
                                            : theme.colorScheme.primary)
                                        .withValues(alpha: 0.5),
                                enableHaptics: hasTaskFeedback,
                                enableSparkles: true,
                                onTap: () {
                                  if (onToggle != null) {
                                    onToggle!();
                                  } else {
                                    Provider.of<TaskProvider>(
                                      context,
                                      listen: false,
                                    ).toggleTaskCompletion(task);
                                  }
                                },
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
                                      ? theme.colorScheme.onSurface.withValues(
                                          alpha: 0.45,
                                        )
                                      : theme.colorScheme.onSurface,
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  decorationColor: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Description preview if available
                        if (task.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              task.description.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Footer row: Category chips, Subtasks count, Due Date
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Category chip
                                  if (categories.isNotEmpty) ...[
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(
                                            categories.first.colorValue,
                                          ).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          categories.first.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Color(
                                              categories.first.colorValue,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (categories.length > 1) ...[
                                      const SizedBox(width: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '+${categories.length - 1}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                  ],

                                  // Subtasks indicator (Linear style progress pill)
                                  if (subtasks.isNotEmpty) ...[
                                    Builder(
                                      builder: (context) {
                                        final allDone =
                                            completedSubtasks ==
                                            subtasks.length;
                                        final progress = subtasks.isEmpty
                                            ? 0.0
                                            : (completedSubtasks /
                                                  subtasks.length);
                                        final pillColor = allDone
                                            ? const Color(0xFF10B981)
                                            : theme.colorScheme.primary;

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: pillColor.withValues(
                                              alpha: allDone ? 0.15 : 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: pillColor.withValues(
                                                alpha: allDone ? 0.35 : 0.15,
                                              ),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (allDone)
                                                Icon(
                                                  Icons.check_rounded,
                                                  size: 11,
                                                  color: pillColor,
                                                )
                                              else
                                                Container(
                                                  width: 16,
                                                  height: 3.5,
                                                  margin: const EdgeInsets.only(
                                                    right: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: theme
                                                        .colorScheme
                                                        .outline
                                                        .withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          2,
                                                        ),
                                                  ),
                                                  child: FractionallySizedBox(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    widthFactor: progress.clamp(
                                                      0.0,
                                                      1.0,
                                                    ),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: pillColor,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              2,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              Text(
                                                '$completedSubtasks/${subtasks.length}',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: allDone
                                                      ? pillColor
                                                      : theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Due Date Chip
                            if (task.dueDate != null) ...[
                              const SizedBox(width: 6),
                              Builder(
                                builder: (context) {
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
                                          ? theme.colorScheme.errorContainer
                                                .withValues(alpha: 0.4)
                                          : theme.colorScheme.primaryContainer
                                                .withValues(alpha: 0.3),
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
                                },
                              ),
                            ],
                          ],
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

    final isDesktopOrWeb =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;

    final feedbackWidget = Material(
      color: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        width: 260,
        child: Transform.rotate(
          angle: -0.04,
          child: Opacity(opacity: 0.92, child: cardContent(isDragging: true)),
        ),
      ),
    );

    final childWhenDragging = Opacity(opacity: 0.3, child: cardContent());

    final draggableCard = isDesktopOrWeb
        ? Draggable<Task>(
            data: task,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: feedbackWidget,
            childWhenDragging: childWhenDragging,
            child: cardContent(),
          )
        : LongPressDraggable<Task>(
            data: task,
            hapticFeedbackOnStart: true,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: feedbackWidget,
            childWhenDragging: childWhenDragging,
            child: cardContent(),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: draggableCard,
    );
  }
}
