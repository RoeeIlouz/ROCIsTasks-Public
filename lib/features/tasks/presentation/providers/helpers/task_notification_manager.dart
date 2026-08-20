import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class TaskNotificationManager {
  static const int maxNagNotifications = 5;

  final NotificationService _notificationService;

  TaskNotificationManager({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  DateTime applyQuietHours(
    DateTime date, {
    required bool quietHoursEnabled,
    required int quietStartMinutes,
    required int quietEndMinutes,
  }) {
    if (!quietHoursEnabled) return date;
    if (quietStartMinutes == quietEndMinutes) return date;

    final minutes = date.hour * 60 + date.minute;
    final spansMidnight = quietStartMinutes > quietEndMinutes;
    final inQuiet = spansMidnight
        ? (minutes >= quietStartMinutes || minutes < quietEndMinutes)
        : (minutes >= quietStartMinutes && minutes < quietEndMinutes);

    if (!inQuiet) return date;

    final endHour = quietEndMinutes ~/ 60;
    final endMinute = quietEndMinutes % 60;
    final endDate = (spansMidnight && minutes >= quietStartMinutes)
        ? date.add(const Duration(days: 1))
        : date;
    return DateTime(endDate.year, endDate.month, endDate.day, endHour, endMinute);
  }

  List<int> getNotificationIdsForTask(Task task) {
    final baseId = NotificationService.getNotificationId(task.id);
    final ids = <int>[baseId];
    for (var i = 1; i <= maxNagNotifications; i++) {
      ids.add(NotificationService.getNotificationId('${task.id}_nag_$i'));
    }
    return ids;
  }

  Future<void> cancelTaskNotifications(Task task) async {
    final ids = getNotificationIdsForTask(task);
    for (final id in ids) {
      await _notificationService.cancelNotification(id);
    }
  }

  Future<void> cancelTaskNotificationsById(String taskId) async {
    final ids = <int>[NotificationService.getNotificationId(taskId)];
    for (var i = 1; i <= maxNagNotifications; i++) {
      ids.add(NotificationService.getNotificationId('${taskId}_nag_$i'));
    }
    for (final id in ids) {
      await _notificationService.cancelNotification(id);
    }
  }

  DateTime getSnoozedDate(DateTime base, String? actionId) {
    if (actionId == 'snooze_10') {
      return base.add(const Duration(minutes: 10));
    }
    if (actionId == 'snooze_60') {
      return base.add(const Duration(hours: 1));
    }
    if (actionId == 'snooze_tomorrow_morning') {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day).add(
        const Duration(days: 1),
      );
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
    }
    return base.add(const Duration(minutes: 15));
  }

  Future<void> scheduleTaskNotifications(
    Task task, {
    required AppLocalizations l10n,
    required bool isPremium,
    required bool advancedRemindersEnabled,
    required bool nagRemindersEnabled,
    required int nagCount,
    required int nagIntervalMinutes,
    required bool quietHoursEnabled,
    required int quietStartMinutes,
    required int quietEndMinutes,
    required bool isPrivate,
    required bool shouldHidePrivate,
  }) async {
    if (task.isCompleted || (task.isDeleted ?? false)) return;
    if (task.skipReminders) return;
    if (task.dueDate == null) return;
    if (!task.dueDate!.isAfter(DateTime.now())) return;

    await cancelTaskNotifications(task);

    if (isPremium &&
        task.requireSubTasksBeforeReminders &&
        (task.subTasks?.isNotEmpty ?? false) &&
        (task.subTasks?.any((st) => !st.isCompleted) ?? false)) {
      return;
    }

    final shouldHide = shouldHidePrivate && isPrivate;

    final title = shouldHide
        ? l10n.taskReminderTitle(l10n.privateLabel)
        : l10n.taskReminderTitle(task.title);
    final body = shouldHide
        ? l10n.taskDueNowBody
        : (task.description.isNotEmpty ? task.description : l10n.taskDueNowBody);

    final actions = <AndroidNotificationAction>[
      if (advancedRemindersEnabled) ...[
        AndroidNotificationAction(
          'snooze_10',
          l10n.snooze10m,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze',
          l10n.notificationSnooze,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze_60',
          l10n.snooze1h,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze_tomorrow_morning',
          l10n.tomorrowAtNine,
          showsUserInterface: true,
        ),
      ] else ...[
        AndroidNotificationAction(
          'snooze',
          l10n.notificationSnooze,
          showsUserInterface: true,
        ),
      ],
      AndroidNotificationAction(
        'complete',
        l10n.notificationMarkCompleted,
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        'open_task',
        l10n.notificationOpenTask,
        showsUserInterface: true,
      ),
    ];

    final baseScheduledDate = applyQuietHours(
      task.dueDate!,
      quietHoursEnabled: quietHoursEnabled,
      quietStartMinutes: quietStartMinutes,
      quietEndMinutes: quietEndMinutes,
    );
    if (!baseScheduledDate.isAfter(DateTime.now())) return;

    await _notificationService.scheduleNotification(
      id: NotificationService.getNotificationId(task.id),
      title: title,
      body: body,
      scheduledDate: baseScheduledDate,
      taskId: task.id,
      androidActions: actions,
    );

    if (nagRemindersEnabled) {
      final effectiveCount = nagCount.clamp(0, maxNagNotifications);
      final effectiveInterval = nagIntervalMinutes.clamp(1, 24 * 60);
      final scheduledTimes = <int>{baseScheduledDate.millisecondsSinceEpoch};

      for (var i = 1; i <= effectiveCount; i++) {
        final rawDate = baseScheduledDate.add(
          Duration(minutes: effectiveInterval * i),
        );
        final scheduledDate = applyQuietHours(
          rawDate,
          quietHoursEnabled: quietHoursEnabled,
          quietStartMinutes: quietStartMinutes,
          quietEndMinutes: quietEndMinutes,
        );
        if (!scheduledDate.isAfter(DateTime.now())) continue;
        if (!scheduledTimes.add(scheduledDate.millisecondsSinceEpoch)) continue;
        await _notificationService.scheduleNotification(
          id: NotificationService.getNotificationId('${task.id}_nag_$i'),
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          taskId: task.id,
          androidActions: actions,
        );
      }
    }
  }

  Future<void> updateTaskCounterNotification({
    required List<Task> uncompletedTasks,
    required bool isDarkMode,
    required AppLocalizations l10n,
    String? largeIconPath,
    List<String>? formattedTitles,
  }) async {
    try {
      final titles = formattedTitles ?? uncompletedTasks.map((t) => t.title).toList();

      await _notificationService.showTaskCountNotification(
        uncompletedTasks.length,
        titles,
        largeIconPath: largeIconPath,
        isDarkText: !isDarkMode,
        uncompletedTasksLabel: l10n.notificationUncompletedTasks(
          uncompletedTasks.length,
        ),
        tasksRemainingLabel: l10n.notificationTasksRemaining,
        tasksSummaryLabel: l10n.notificationTasksSummary(uncompletedTasks.length),
      );
    } catch (_) {}
  }
}
