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
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_unlock_dialog.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final Category? category;
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
    this.category,
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
        (privateModeService?.shouldHidePrivateContent ?? false) &&
        (category?.isPrivate == true);

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
              category: category,
              dueDate: task.dueDate,
              priority: task.priority,
              isSelected: isSelected,
              onTap: onTap,
              onLongPress: onLongPress,
              isSelectionMode: isSelectionMode,
            )
          : Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (category != null
                  ? Color(category!.colorValue).withValues(alpha: 0.1)
                  : theme.colorScheme.primaryContainer)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? (category != null
                    ? Color(category!.colorValue)
                    : theme.colorScheme.primary)
                : (theme.brightness == Brightness.light
                    ? Colors.grey.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? (category != null
                          ? Color(category!.colorValue)
                          : theme.colorScheme.primary)
                      .withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
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
                          onTap: isSelectionMode
                              ? () => onLongPress?.call()
                              : () {
                                  HapticFeedback.lightImpact();
                                  onToggle();
                                },
                          child: Semantics(
                            label: isSelectionMode
                                ? (isSelected ? 'Selected' : 'Not selected')
                                : (task.isCompleted
                                    ? l10n.markAsIncomplete
                                    : l10n.markAsComplete),
                            checked: isSelectionMode ? isSelected : task.isCompleted,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: (isSelectionMode ? isSelected : task.isCompleted)
                                    ? (category != null
                                        ? Color(category!.colorValue)
                                        : theme.colorScheme.primary)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (isSelectionMode ? isSelected : task.isCompleted)
                                      ? Colors.transparent
                                      : (category != null
                                              ? Color(category!.colorValue)
                                              : theme.colorScheme.primary)
                                          .withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: (isSelectionMode ? isSelected : task.isCompleted)
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
                                      if (task.syncWithGoogleCalendar) ...[
                                        const SizedBox(width: 6),
                                        const _GCalendarBadge(),
                                      ],
                                    ],
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
                                  if (task.subTasks != null &&
                                      task.subTasks!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildSubTasksList(context),
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
                                          color: (!task.isCompleted &&
                                                  task.dueDate!.isBefore(
                                                    DateTime.now(),
                                                  ))
                                              ? theme.colorScheme.error
                                              : theme.colorScheme.primary,
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
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            )
                          else
                            const SizedBox(height: 40),
                          Semantics(
                            label: '${l10n.priority}: ${task.priority.name}',
                            child: Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(bottom: 4),
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
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    spreadRadius: 1,
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
                      ? (category != null
                            ? Color(category!.colorValue)
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
  final Category? category;
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
    required this.category,
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primaryContainer : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : (theme.brightness == Brightness.light
                  ? Colors.grey.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
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
                        if (category != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Color(category!.colorValue).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
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
                                  style: GoogleFonts.outfit(
                                    color: Color(category!.colorValue),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (dueDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.10),
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

// ─── Google Calendar Sync Badge ──────────────────────────────────────────────

class _GCalendarBadge extends StatelessWidget {
  const _GCalendarBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'Synced with Google Calendar',
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white,
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
