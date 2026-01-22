import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/core/utils/icon_utils.dart';
import 'package:google_fonts/google_fonts.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final Category? category;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final bool enableSwipeToDelete;
  final bool enablePin;

  const TaskTile({
    super.key,
    required this.task,
    this.category,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
    this.enableSwipeToDelete = true,
    this.enablePin = true,
  });

  Color _getPriorityColor(BuildContext context, TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.redAccent;
      case TaskPriority.medium:
        return Colors.orangeAccent;
      case TaskPriority.low:
        return Colors.greenAccent;
    }
  }

  static final _timeFormat24 = DateFormat.Hm();
  static final _timeFormat12 = DateFormat.jm();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);

    return Dismissible(
      key: Key(task.id),
      direction: enableSwipeToDelete
          ? DismissDirection.startToEnd
          : DismissDirection.none,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.delete_outline, color: Colors.white, size: 28),
            const Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.brightness == Brightness.light
                ? Colors.grey.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category Color Edge
              if (category != null)
                Container(width: 6, color: Color(category!.colorValue)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: GestureDetector(
                          onTap: onToggle,
                          child: Semantics(
                            label: task.isCompleted
                                ? 'Mark task as incomplete'
                                : 'Mark task as complete',
                            checked: task.isCompleted,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: task.isCompleted
                                    ? (category != null
                                          ? Color(category!.colorValue)
                                          : theme.colorScheme.primary)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: task.isCompleted
                                      ? Colors.transparent
                                      : (category != null
                                                ? Color(category!.colorValue)
                                                : theme.colorScheme.primary)
                                            .withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: task.isCompleted
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 18,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Semantics(
                            label: 'Task: ${task.title}',
                            hint: 'Double tap to edit task details',
                            container: true,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    task.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: task.isCompleted
                                              ? theme.disabledColor
                                              : theme.colorScheme.onSurface,
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                  ),
                                  if (task.description.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      task.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                            height: 1.4,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (category != null) ...[
                                        _buildChip(
                                          context,
                                          icon: IconUtils.getIconData(
                                            category!.iconCode,
                                          ),
                                          label: category!.name,
                                          color: Color(category!.colorValue),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (task.dueDate != null)
                                        _buildChip(
                                          context,
                                          icon: Icons.access_time_rounded,
                                          label: themeService.use24HourFormat
                                              ? _timeFormat24.format(
                                                  task.dueDate!,
                                                )
                                              : _timeFormat12.format(
                                                  task.dueDate!,
                                                ),
                                          color: theme.colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (enablePin)
                            Semantics(
                              label: (task.isPinned ?? false)
                                  ? 'Unpin task'
                                  : 'Pin task',
                              button: true,
                              child: IconButton(
                                icon: Icon(
                                  (task.isPinned ?? false)
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  size: 20,
                                  color: (task.isPinned ?? false)
                                      ? theme.colorScheme.primary
                                      : theme.disabledColor,
                                ),
                                onPressed: () {
                                  Provider.of<TaskProvider>(
                                    context,
                                    listen: false,
                                  ).toggleTaskPin(task);
                                },
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            )
                          else
                            const SizedBox(height: 40),
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(context, task.priority),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _getPriorityColor(
                                    context,
                                    task.priority,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildChip(
    BuildContext context, {
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
          Text(
            label,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
