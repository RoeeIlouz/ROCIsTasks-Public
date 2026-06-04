import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/core/utils/icon_utils.dart';
import 'package:rocis_tasks/core/services/security_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_unlock_dialog.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final Category? category;

  const TaskDetailScreen({
    super.key,
    required this.task,
    this.category,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _authorized = false;
  bool _promptScheduled = false;

  @override
  void dispose() {
    PrivateModeService? privateModeService;
    try {
      privateModeService = Provider.of<PrivateModeService>(context, listen: false);
    } catch (_) {
      privateModeService = null;
    }
    privateModeService?.lock();
    super.dispose();
  }

  Future<void> _promptUnlock(
    TaskProvider provider, {
    required bool popOnCancel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => const TaskUnlockDialog(),
    );

    if (!mounted) return;

    if (ok == true) {
      setState(() {
        _authorized = true;
      });
      await provider.updateHomeWidgetWithNotification();
    } else if (popOnCancel) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        final updatedTask = provider.getTaskById(widget.task.id) ?? widget.task;
        final updatedCategory =
            provider.getCategoryById(updatedTask.categoryId) ?? widget.category;

        PrivateModeService? privateModeService;
        try {
          privateModeService = Provider.of<PrivateModeService>(context);
        } catch (_) {
          privateModeService = null;
        }

        SubscriptionService? subscriptionService;
        try {
          subscriptionService = Provider.of<SubscriptionService>(context);
        } catch (_) {
          subscriptionService = null;
        }

        final requiresUnlock =
            (subscriptionService?.isPremium ?? false) &&
            (updatedCategory?.isPrivate == true) &&
            (privateModeService?.isEnabled ?? false) &&
            (privateModeService?.hasPin ?? false);

        if (requiresUnlock && !_authorized) {
          if (!_promptScheduled) {
            _promptScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _promptUnlock(provider, popOnCancel: true);
            });
          }

          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.privateTask,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.privateTaskSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => _promptUnlock(provider, popOnCancel: false),
                      child: Text(l10n.unlock),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.editTask,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTaskScreen(task: updatedTask),
                      fullscreenDialog: true,
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.deleteTaskTitle,
                color: theme.colorScheme.error,
                onPressed: () => _confirmDelete(context, provider, l10n),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        provider.toggleTaskCompletion(updatedTask);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12, top: 4),
                        child: Icon(
                          updatedTask.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 28,
                          color: updatedTask.isCompleted
                              ? theme.colorScheme.primary
                              : theme.disabledColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        updatedTask.title,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          decoration: updatedTask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: updatedTask.isCompleted
                              ? theme.disabledColor
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (updatedCategory != null)
                      Chip(
                        avatar: Icon(
                          IconUtils.getIconData(updatedCategory.iconCode),
                          color: Color(updatedCategory.colorValue),
                          size: 18,
                        ),
                        label: Text(updatedCategory.name),
                        backgroundColor: Color(updatedCategory.colorValue)
                            .withValues(alpha: 0.1),
                        side: BorderSide.none,
                      ),
                    if (updatedTask.dueDate != null)
                      Chip(
                        avatar: Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: _getDueDateColor(updatedTask.dueDate!, theme),
                        ),
                        label: Text(
                          DateFormat('MMM d, y, HH:mm').format(updatedTask.dueDate!),
                          style: TextStyle(
                            color: _getDueDateColor(updatedTask.dueDate!, theme),
                          ),
                        ),
                        backgroundColor: _getDueDateColor(updatedTask.dueDate!, theme)
                            .withValues(alpha: 0.1),
                        side: BorderSide.none,
                      ),
                    Chip(
                      avatar: Icon(
                        Icons.flag_rounded,
                        size: 18,
                        color: _getPriorityColor(updatedTask.priority),
                      ),
                      label: Text(
                        _getPriorityLabel(updatedTask.priority, l10n),
                        style: TextStyle(
                          color: _getPriorityColor(updatedTask.priority),
                        ),
                      ),
                      backgroundColor: _getPriorityColor(updatedTask.priority)
                          .withValues(alpha: 0.1),
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                if (updatedTask.description.isNotEmpty) ...[
                  Text(
                    l10n.description,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    updatedTask.description,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 32),
                ],

                if (updatedTask.subTasks != null && updatedTask.subTasks!.isNotEmpty) ...[
                  Text(
                    l10n.subtasks,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...updatedTask.subTasks!.map((subtask) {
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        subtask.title,
                        style: TextStyle(
                          decoration: subtask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: subtask.isCompleted
                              ? theme.disabledColor
                              : null,
                        ),
                      ),
                      value: subtask.isCompleted,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        provider.toggleSubTask(updatedTask, subtask.id);
                      },
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getDueDateColor(DateTime date, ThemeData theme) {
    if (date.isBefore(DateTime.now())) {
      return theme.colorScheme.error;
    }
    return theme.colorScheme.primary;
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.blue;
    }
  }

  String _getPriorityLabel(TaskPriority priority, AppLocalizations l10n) {
    switch (priority) {
      case TaskPriority.high:
        return l10n.high;
      case TaskPriority.medium:
        return l10n.medium;
      case TaskPriority.low:
        return l10n.low;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskProvider provider,
    AppLocalizations l10n,
  ) async {
    final result = await showDialog<bool>(
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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      provider.deleteTask(widget.task.id);
      Navigator.pop(context);
    }
  }
}
