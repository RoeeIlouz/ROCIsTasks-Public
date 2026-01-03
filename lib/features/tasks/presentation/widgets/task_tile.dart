import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/theme/theme_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/core/utils/icon_utils.dart';

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
    // These colors are semantic and generally safe for both themes,
    // but could be moved to theme extension if strict adherence is needed.
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }

  static final _dateFormat = DateFormat('dd/MM/yy');
  static final _timeFormat24 = DateFormat.Hm();
  static final _timeFormat12 = DateFormat.jm();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final _lang = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);

    return Dismissible(
      key: Key(task.id),
      direction: enableSwipeToDelete
          ? DismissDirection.startToEnd
          : DismissDirection.none,
      onDismissed: (_) => onDelete(),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.deleteTaskTitle),
              content: Text(l10n.deleteTaskConfirmation),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.delete),
                ),
              ],
            ),
          );
        }
        return false;
      },
      background: Container(
        alignment: _lang == 'he' ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20, right: 20),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        elevation: 1,
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 90),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (category != null)
                Container(width: 4, color: Color(category!.colorValue)),
              Expanded(
                child: ListTile(
                  isThreeLine: true,
                  dense: true,
                  titleAlignment: ListTileTitleAlignment.titleHeight,
                  minVerticalPadding: 0,
                  horizontalTitleGap: 0,
                  onTap: onTap,
                  leading: Checkbox(
                    value: task.isCompleted,
                    onChanged: (_) => onToggle(),
                    activeColor: category != null
                        ? Color(category!.colorValue)
                        : theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  title: Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted ? theme.disabledColor : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Task Desc + DueDate + Category
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      task.description.isNotEmpty
                          ? SizedBox(
                              height: 25,
                              child: SingleChildScrollView(
                                primary: false,
                                child: Text(
                                  task.description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: task.isCompleted
                                        ? theme.disabledColor
                                        : theme.textTheme.bodySmall?.color
                                              ?.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            )
                          : SizedBox(),
                      const SizedBox(height: 4),
                      // DueDate Icon and text
                      if (task.dueDate != null ||
                          (task.categoryId != null &&
                              task.categoryId!.isNotEmpty))
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            if (category != null)
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(
                                    category!.colorValue,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      IconUtils.getIconData(category!.iconCode),
                                      size: 12,
                                      color: Color(category!.colorValue),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      category!.name,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: Color(category!.colorValue),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            if (task.dueDate != null) ...[
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                themeService.use24HourFormat
                                    ? '${l10n.duePrefix}${_dateFormat.format(task.dueDate!)} | ${_timeFormat24.format(task.dueDate!)}'
                                    : '${l10n.duePrefix}${_dateFormat.format(task.dueDate!)} | ${_timeFormat12.format(task.dueDate!)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  overflow: TextOverflow.clip,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (enablePin)
                        IconButton(
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
                            final provider = Provider.of<TaskProvider>(
                              context,
                              listen: false,
                            );
                            provider.toggleTaskPin(task);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getPriorityColor(context, task.priority),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
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
