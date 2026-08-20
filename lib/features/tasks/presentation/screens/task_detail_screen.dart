import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
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
import 'package:rocis_tasks/core/utils/attachment_utils.dart';
import 'package:rocis_tasks/features/tasks/domain/services/custom_field_action_service.dart';
import 'package:rocis_tasks/features/tasks/domain/services/task_recurrence_service.dart';

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
  final TextEditingController _newGroceryItemController = TextEditingController();
  final TextEditingController _newGroceryQtyController = TextEditingController();

  @override
  void dispose() {
    _newGroceryItemController.dispose();
    _newGroceryQtyController.dispose();
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
        final categoryIds = updatedTask.categoryIds.isNotEmpty 
            ? updatedTask.categoryIds 
            : (updatedTask.categoryId != null ? [updatedTask.categoryId!] : []);
        final updatedCategories = categoryIds
            .map((id) => provider.getCategoryById(id))
            .where((c) => c != null)
            .cast<Category>()
            .toList();
        if (updatedCategories.isEmpty && widget.category != null) {
          updatedCategories.add(widget.category!);
        }

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
            (updatedCategories.any((c) => c.isPrivate)) &&
            (privateModeService?.isEnabled ?? false) &&
            (privateModeService?.hasPin ?? false) &&
            (privateModeService?.isUnlocked != true);

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
                    if (!updatedTask.isGroceryList)
                      InkWell(
                        onTap: () {
                          final themeService = Provider.of<ThemeService>(context, listen: false);
                          if (themeService.taskCompletionFeedback) {
                            if (!updatedTask.isCompleted) {
                              HapticFeedback.mediumImpact();
                            } else {
                              HapticFeedback.lightImpact();
                            }
                          }
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
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 12, top: 4),
                        child: Icon(
                          updatedTask.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.checklist_rounded,
                          size: 28,
                          color: updatedTask.isCompleted
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(alpha: 0.7),
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

                GlassContainer(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ...updatedCategories.map((c) => Chip(
                          avatar: Icon(
                            IconUtils.getIconData(c.iconCode),
                            color: Color(c.colorValue),
                            size: 18,
                          ),
                          label: Text(c.name),
                          backgroundColor: Color(c.colorValue).withValues(alpha: 0.1),
                          side: BorderSide.none,
                        )),
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
                        if (updatedTask.recurrenceRule != null &&
                            updatedTask.recurrenceRule!.trim().isNotEmpty)
                          Chip(
                            avatar: Icon(
                              Icons.repeat_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            label: Text(
                              TaskRecurrenceService.getRecurrenceLabel(
                                updatedTask.recurrenceRule,
                                l10n,
                              ),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            side: BorderSide.none,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (updatedTask.description.isNotEmpty) ...[
                  Text(
                    l10n.description,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GlassContainer(
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        updatedTask.description,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (updatedTask.isGroceryList)
                  _buildGroceryListSection(context, updatedTask, provider, l10n, theme)
                else if (updatedTask.subTasks != null && updatedTask.subTasks!.isNotEmpty) ...[
                  Text(
                    l10n.subtasks,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: List.generate(updatedTask.subTasks!.length, (index) {
                        final subtask = updatedTask.subTasks![index];
                        return Column(
                          children: [
                            CheckboxListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                            ),
                            if (index < updatedTask.subTasks!.length - 1)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.dividerColor.withValues(alpha: 0.08),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (updatedTask.customFields != null && updatedTask.customFields!.isNotEmpty) ...[
                  Text(
                    l10n.customFields,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...updatedTask.customFields!.map((field) {
                    final icon = CustomFieldActionService.getIcon(field.type, field.value);
                    final actionIcon = CustomFieldActionService.getActionIcon(field.type, field.value);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          CustomFieldActionService.performAction(context, field);
                        },
                        onLongPress: () {
                          CustomFieldActionService.copyToClipboard(
                            context,
                            field.value,
                            message: l10n.copiedToClipboard,
                          );
                        },
                        child: GlassContainer(
                          borderRadius: BorderRadius.circular(16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  icon,
                                  size: 22,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (field.label.isNotEmpty)
                                      Text(
                                        field.label,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    Text(
                                      field.value.isNotEmpty ? field.value : '—',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(actionIcon, size: 20),
                                color: theme.colorScheme.primary,
                                tooltip: field.value,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  CustomFieldActionService.performAction(context, field);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                if (updatedTask.attachmentPaths.isNotEmpty) ...[
                  Text(
                    'Attachments',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GlassContainer(
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: updatedTask.attachmentPaths.map((path) {
                          final filename = AttachmentUtils.getFilename(path);
                          final icon = AttachmentUtils.getFileIcon(path);
                          return InputChip(
                            avatar: Icon(icon, size: 18),
                            label: Text(
                              filename,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            onPressed: () => AttachmentUtils.openAttachment(context, path),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
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

  Widget _buildGroceryListSection(
    BuildContext context,
    Task task,
    TaskProvider provider,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final subtasks = task.subTasks ?? [];
    final toBuyItems = subtasks.where((st) => !st.isCompleted).toList();
    final inCartItems = subtasks.where((st) => st.isCompleted).toList();
    final total = subtasks.length;
    final completed = inCartItems.length;
    final progress = total > 0 ? completed / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shopping_cart_rounded, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              l10n.groceryListMode,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const Spacer(),
            if (subtasks.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  provider.resetGroceryList(task);
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(l10n.resetCart, style: GoogleFonts.outfit(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar card
        GlassContainer(
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.itemsInCart(completed, total),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Quick add item card
        GlassContainer(
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _newGroceryItemController,
                  decoration: InputDecoration(
                    hintText: l10n.addItemHint,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: GoogleFonts.outfit(fontSize: 14),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      provider.addGroceryItem(task, val, quantity: _newGroceryQtyController.text);
                      _newGroceryItemController.clear();
                      _newGroceryQtyController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _newGroceryQtyController,
                  decoration: InputDecoration(
                    hintText: l10n.quantityHint,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_rounded),
                color: theme.colorScheme.primary,
                onPressed: () {
                  final title = _newGroceryItemController.text;
                  if (title.trim().isNotEmpty) {
                    provider.addGroceryItem(task, title, quantity: _newGroceryQtyController.text);
                    _newGroceryItemController.clear();
                    _newGroceryQtyController.clear();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // To Buy Section
        if (toBuyItems.isNotEmpty) ...[
          Text(
            '${l10n.toBuy} (${toBuyItems.length})',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          GlassContainer(
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: List.generate(toBuyItems.length, (index) {
                final item = toBuyItems[index];
                return CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(item.title, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                  secondary: item.quantity != null && item.quantity!.isNotEmpty
                      ? Chip(
                          label: Text(item.quantity!, style: GoogleFonts.outfit(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          side: BorderSide.none,
                        )
                      : null,
                  value: item.isCompleted,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    provider.toggleSubTask(task, item.id);
                  },
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // In Cart Section
        if (inCartItems.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.inCart} (${inCartItems.length})',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  provider.clearCompletedSubTasks(task);
                },
                child: Text(l10n.clearCartItems, style: GoogleFonts.outfit(fontSize: 12, color: theme.colorScheme.error)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GlassContainer(
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: List.generate(inCartItems.length, (index) {
                final item = inCartItems[index];
                return CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    item.title,
                    style: GoogleFonts.outfit(
                      decoration: TextDecoration.lineThrough,
                      color: theme.disabledColor,
                    ),
                  ),
                  secondary: item.quantity != null && item.quantity!.isNotEmpty
                      ? Chip(
                          label: Text(item.quantity!, style: GoogleFonts.outfit(fontSize: 11, color: theme.disabledColor)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          side: BorderSide.none,
                        )
                      : null,
                  value: item.isCompleted,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    provider.toggleSubTask(task, item.id);
                  },
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
