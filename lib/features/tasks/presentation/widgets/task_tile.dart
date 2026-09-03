import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/core/utils/icon_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/core/services/security_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/features/tasks/domain/services/task_recurrence_service.dart';
import 'package:rocis_tasks/features/tasks/domain/services/custom_field_action_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_unlock_dialog.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final List<Category> categories;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableSwipeToDelete;
  final bool enablePin;
  final bool isSelected;
  final bool isSelectionMode;

  const TaskTile({
    super.key,
    required this.task,
    this.categories = const [],
    required this.onToggle,
    required this.onDelete,
    this.onTap,
    this.onLongPress,
    this.enableSwipeToDelete = true,
    this.enablePin = true,
    this.isSelected = false,
    this.isSelectionMode = false,
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
    final l10n = AppLocalizations.of(context)!;
    SubscriptionService? subscriptionService;
    try {
      subscriptionService = Provider.of<SubscriptionService>(context);
    } catch (_) {
      subscriptionService = null;
    }

    PrivateModeService? privateModeService;
    try {
      privateModeService = Provider.of<PrivateModeService>(context);
    } catch (_) {
      privateModeService = null;
    }

    final bool shouldMaskPrivate =
        (subscriptionService?.isPremium ?? false) &&
        (privateModeService?.hasPin ?? false) &&
        (categories.any((c) => c.isPrivate));

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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ],
        ),
      ),
      child: shouldMaskPrivate
          ? _MaskedPrivateTaskTile(
              title: l10n.privateTask,
              categories: categories,
              dueDate: task.dueDate,
              priority: task.priority,
              isSelected: isSelected,
              onTap: onTap,
              onLongPress: onLongPress,
              isSelectionMode: isSelectionMode,
            )
          : GlassContainer(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              isSelected: isSelected,
              selectedBorderColor: categories.isNotEmpty
                  ? Color(categories.first.colorValue)
                  : theme.colorScheme.primary,
              color: isSelected
                  ? (categories.isNotEmpty
                        ? Color(categories.first.colorValue)
                        : theme.colorScheme.primary)
                  : null,
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
                    if (!isSelectionMode && task.isGroceryList)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 10,
                          right: 10,
                          top: 2,
                          bottom: 18,
                        ),
                        child: Icon(
                          task.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.checklist_rounded,
                          color: task.isCompleted
                              ? theme.colorScheme.primary
                              : (categories.isNotEmpty
                                        ? Color(categories.first.colorValue)
                                        : theme.colorScheme.primary)
                                    .withValues(alpha: 0.7),
                          size: 26,
                        ),
                      )
                    else
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: isSelectionMode
                            ? () => onLongPress?.call()
                            : () {
                                if (themeService.taskCompletionFeedback) {
                                  // Stronger impact when completing, lighter when un-completing
                                  if (!task.isCompleted) {
                                    HapticFeedback.mediumImpact();
                                  } else {
                                    HapticFeedback.lightImpact();
                                  }
                                }
                                onToggle();
                              },
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 10,
                            right: 10,
                            top: 2,
                            bottom: 18,
                          ),
                          child: Semantics(
                            label: isSelectionMode
                                ? (isSelected ? 'Selected' : 'Not selected')
                                : (task.isCompleted
                                      ? l10n.markAsIncomplete
                                      : l10n.markAsComplete),
                            checked: isSelectionMode
                                ? isSelected
                                : task.isCompleted,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color:
                                    (isSelectionMode
                                        ? isSelected
                                        : task.isCompleted)
                                    ? (categories.isNotEmpty
                                          ? Color(categories.first.colorValue)
                                          : theme.colorScheme.primary)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      (isSelectionMode
                                          ? isSelected
                                          : task.isCompleted)
                                      ? Colors.transparent
                                      : (categories.isNotEmpty
                                                ? Color(
                                                    categories.first.colorValue,
                                                  )
                                                : theme.colorScheme.primary)
                                            .withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child:
                                  (isSelectionMode
                                      ? isSelected
                                      : task.isCompleted)
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
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: isSelectionMode ? onLongPress : onTap,
                        onLongPress: onLongPress,
                        borderRadius: BorderRadius.circular(12),
                        child: Semantics(
                          label: '${l10n.tasks}: ${task.title}',
                          hint: l10n.editTaskDetailsHint,
                          container: true,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
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
                                    ),
                                    if (task.syncWithGoogleTasks) ...[
                                      const SizedBox(width: 6),
                                      const _GTasksBadge(),
                                    ],
                                  ],
                                ),
                                if (task.description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    task.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                if (task.subTasks != null &&
                                    task.subTasks!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildSubTasksList(context),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    ...categories.map(
                                      (c) => _buildChip(
                                        context,
                                        icon: IconUtils.getIconData(c.iconCode),
                                        label: c.name,
                                        color: Color(c.colorValue),
                                        onTap: isSelectionMode
                                            ? null
                                            : () {
                                                HapticFeedback.lightImpact();
                                                Provider.of<TaskProvider>(
                                                  context,
                                                  listen: false,
                                                ).selectSingleCategoryFilter(
                                                  c.id,
                                                );
                                              },
                                      ),
                                    ),
                                    if (task.isGroceryList)
                                      _buildChip(
                                        context,
                                        icon: Icons.checklist_rounded,
                                        label:
                                            '${task.subTasks?.where((st) => st.isCompleted).length ?? 0}/${task.subTasks?.length ?? 0}',
                                        color: theme.colorScheme.primary,
                                      ),
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
                                        color:
                                            (!task.isCompleted &&
                                                task.dueDate!.isBefore(
                                                  DateTime.now(),
                                                ))
                                            ? theme.colorScheme.error
                                            : theme.colorScheme.primary,
                                        onTap:
                                            isSelectionMode || task.isCompleted
                                            ? null
                                            : () => _showRescheduleSheet(
                                                context,
                                                task,
                                                l10n,
                                                theme,
                                              ),
                                      ),
                                    if (task.recurrenceRule != null &&
                                        task.recurrenceRule!.trim().isNotEmpty)
                                      _buildChip(
                                        context,
                                        icon: Icons.repeat_rounded,
                                        label:
                                            TaskRecurrenceService.getRecurrenceLabel(
                                              task.recurrenceRule,
                                              l10n,
                                            ),
                                        color: theme.colorScheme.primary,
                                      ),
                                    if (task.customFields != null &&
                                        task.customFields!.isNotEmpty)
                                      ...task.customFields!
                                          .where(
                                            (cf) =>
                                                cf.value.isNotEmpty ||
                                                cf.label.isNotEmpty,
                                          )
                                          .map((cf) {
                                            final icon =
                                                CustomFieldActionService.getIcon(
                                                  cf.type,
                                                  cf.value,
                                                );
                                            final displayLabel =
                                                cf.value.isNotEmpty
                                                ? cf.value
                                                : cf.label;
                                            return _buildChip(
                                              context,
                                              icon: icon,
                                              label: displayLabel,
                                              color: theme.colorScheme.primary,
                                            );
                                          }),
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
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (enablePin)
                          Semantics(
                            label: (task.isPinned ?? false)
                                ? l10n.unpinTask
                                : l10n.pinTask,
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
                                HapticFeedback.lightImpact();
                                Provider.of<TaskProvider>(
                                  context,
                                  listen: false,
                                ).toggleTaskPin(task);
                              },
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              padding: const EdgeInsets.all(8),
                            ),
                          )
                        else
                          const SizedBox(height: 40),
                        const SizedBox(height: 8),
                        Semantics(
                          label: '${l10n.priority}: ${task.priority.name}',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(
                                context,
                                task.priority,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getPriorityColor(
                                  context,
                                  task.priority,
                                ).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(
                                      context,
                                      task.priority,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getPriorityColor(
                                          context,
                                          task.priority,
                                        ).withValues(alpha: 0.6),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  task.priority.name.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: _getPriorityColor(
                                      context,
                                      task.priority,
                                    ),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showRescheduleSheet(
    BuildContext context,
    Task task,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    HapticFeedback.lightImpact();
    final provider = Provider.of<TaskProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.rescheduleTask,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.wb_sunny_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    l10n.plusOneDay,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    DateFormat.yMMMd().format(
                      (task.dueDate ?? DateTime.now()).add(
                        const Duration(days: 1),
                      ),
                    ),
                    style: GoogleFonts.outfit(fontSize: 12),
                  ),
                  onTap: () {
                    final base = task.dueDate ?? DateTime.now();
                    final newDate = base.add(const Duration(days: 1));
                    provider.updateTask(task, dueDate: newDate);
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                  },
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.next_week_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    l10n.plusOneWeek,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    DateFormat.yMMMd().format(
                      (task.dueDate ?? DateTime.now()).add(
                        const Duration(days: 7),
                      ),
                    ),
                    style: GoogleFonts.outfit(fontSize: 12),
                  ),
                  onTap: () {
                    final base = task.dueDate ?? DateTime.now();
                    final newDate = base.add(const Duration(days: 7));
                    provider.updateTask(task, dueDate: newDate);
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                  },
                ),
              ),
              if (task.dueDate != null &&
                  task.dueDate!.isBefore(DateTime.now()))
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.today_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      l10n.moveToToday,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      DateFormat.yMMMd().format(DateTime.now()),
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                    onTap: () {
                      final now = DateTime.now();
                      final newDate = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        18,
                        0,
                      );
                      provider.updateTask(task, dueDate: newDate);
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final chip = Container(
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

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: chip,
      );
    }
    return chip;
  }

  Widget _buildSubTasksList(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<TaskProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: task.subTasks!.map((subTask) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InkWell(
            onTap: () => provider.toggleSubTask(task, subTask.id),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(
                  subTask.isCompleted
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 16,
                  color: subTask.isCompleted
                      ? (categories.isNotEmpty
                            ? Color(categories.first.colorValue)
                            : theme.colorScheme.primary)
                      : theme.disabledColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subTask.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: subTask.isCompleted
                          ? theme.disabledColor
                          : theme.colorScheme.onSurface,
                      decoration: subTask.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MaskedPrivateTaskTile extends StatelessWidget {
  final String title;
  final List<Category> categories;
  final DateTime? dueDate;
  final TaskPriority priority;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;

  static final _timeFormat24 = DateFormat.Hm();
  static final _timeFormat12 = DateFormat.jm();

  const _MaskedPrivateTaskTile({
    required this.title,
    required this.categories,
    required this.dueDate,
    required this.priority,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.isSelectionMode,
  });

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.redAccent;
      case TaskPriority.medium:
        return Colors.orangeAccent;
      case TaskPriority.low:
        return Colors.greenAccent;
    }
  }

  Future<void> _handleTap(BuildContext context) async {
    if (isSelectionMode) {
      onTap?.call();
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => const TaskUnlockDialog(),
    );
    if (!context.mounted) return;
    if (ok == true) {
      onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final priorityColor = _getPriorityColor(priority);

    return GlassContainer(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      isSelected: isSelected,
      selectedBorderColor: theme.colorScheme.primary,
      color: isSelected ? theme.colorScheme.primary : null,
      child: InkWell(
        onTap: () => _handleTap(context),
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.lock_rounded,
                color: theme.colorScheme.primary.withValues(alpha: 0.9),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ...categories.map(
                          (c) => InkWell(
                            onTap: isSelectionMode
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    Provider.of<TaskProvider>(
                                      context,
                                      listen: false,
                                    ).selectSingleCategoryFilter(c.id);
                                  },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Color(
                                  c.colorValue,
                                ).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    IconUtils.getIconData(c.iconCode),
                                    size: 12,
                                    color: Color(c.colorValue),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    c.name,
                                    style: GoogleFonts.outfit(
                                      color: Color(c.colorValue),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (dueDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  themeService.use24HourFormat
                                      ? _timeFormat24.format(dueDate!)
                                      : _timeFormat12.format(dueDate!),
                                  style: GoogleFonts.outfit(
                                    color: theme.colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: priorityColor.withValues(alpha: 0.35),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Google Tasks Sync Badge ──────────────────────────────────────────────────

class _GTasksBadge extends StatelessWidget {
  const _GTasksBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'Synced with Google Tasks',
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: SvgPicture.asset(
            'assets/icons/google-icon.svg',
            width: 14,
            height: 14,
          ),
        ),
      ),
    );
  }
}
