import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              title: task.title,
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
                                      if (task.syncWithGoogleCalendar &&
                                          task.calendarEventId != null) ...[
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
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;

  const _MaskedPrivateTaskTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.isSelectionMode,
  });

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
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
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

// ─── Google Calendar Sync Badge ──────────────────────────────────────────────

class _GCalendarBadge extends StatelessWidget {
  const _GCalendarBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'Synced with Google Calendar',
      child: Container(
        width: 18,
        height: 18,
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
        child: const Padding(
          padding: EdgeInsets.all(2.5),
          child: CustomPaint(
            painter: _GoogleGPainter(),
          ),
        ),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  // Official Google brand palette
  static const _blue   = Color(0xFF4285F4);
  static const _red    = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC04);
  static const _green  = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy);
    final strokeW = radius * 0.42;
    final arcR = radius - strokeW / 2;
    final rect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: arcR,
    );

    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    // Angles in radians, measured clockwise from the 3 o'clock position.
    // Blue  : 225° → 315°  (large left arc, ~270° sweep)
    // Red   : 315° → 45°   (top-right,       ~90° sweep)
    // Yellow: 45°  → 135°  (bottom-right,     ~90° sweep)
    // Green : 135° → 225°  (bottom-left,      ~90° sweep)
    const deg = math.pi / 180;
    canvas
      ..drawArc(rect, 225 * deg, 270 * deg, false, arc(_blue))
      ..drawArc(rect, 315 * deg,  90 * deg, false, arc(_red))
      ..drawArc(rect,  45 * deg,  90 * deg, false, arc(_yellow))
      ..drawArc(rect, 135 * deg,  90 * deg, false, arc(_green));

    // Horizontal bar of the "G" (right half, centred vertically)
    final barH = strokeW;
    final barTop = cy - barH / 2;
    canvas.drawRect(
      Rect.fromLTRB(cx, barTop, cx + arcR + strokeW / 2, barTop + barH),
      Paint()
        ..color = _blue
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
