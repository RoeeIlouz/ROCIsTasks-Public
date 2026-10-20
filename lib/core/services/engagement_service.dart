import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';

/// Opt-in retention features: completion streak, the weekly recap
/// notification and the one-time glass theme preview offer.
class EngagementService extends ChangeNotifier {
  static const int weeklyRecapNotificationId = 900001;
  static const int glassOfferAfterCompletions = 3;

  static const String _recapKey = 'weekly_recap_enabled';
  static const String _completionsKey = 'engagement_completions';
  static const String _glassOfferedKey = 'glass_preview_offered';

  final NotificationService? _injectedNotifications;

  EngagementService({NotificationService? notifications})
    : _injectedNotifications = notifications;

  // Resolved on first use: the singleton binds a platform channel.
  NotificationService get _notifications =>
      _injectedNotifications ?? NotificationService();

  Box? get _box => Hive.isBoxOpen('settings') ? Hive.box('settings') : null;

  bool get weeklyRecapEnabled =>
      _box?.get(_recapKey, defaultValue: false) as bool? ?? false;

  Future<void> setWeeklyRecap(
    bool enabled, {
    required String title,
    required String body,
  }) async {
    await _box?.put(_recapKey, enabled);
    notifyListeners();
    if (enabled) {
      await _notifications.requestPermissions();
      await _notifications.scheduleWeeklyRecap(
        id: weeklyRecapNotificationId,
        title: title,
        body: body,
      );
    } else {
      await _notifications.cancelNotification(weeklyRecapNotificationId);
    }
  }

  /// Counts a completion. Returns true exactly once, on the
  /// [glassOfferAfterCompletions]th completion, when the glass preview
  /// should be offered to a free user.
  bool recordCompletion({required bool isPremium}) {
    final box = _box;
    if (box == null || kIsWeb) return false;
    try {
      final count = (box.get(_completionsKey, defaultValue: 0) as int) + 1;
      box.put(_completionsKey, count);
      if (isPremium || count < glassOfferAfterCompletions) return false;
      if (box.get(_glassOfferedKey, defaultValue: false) as bool) return false;
      box.put(_glassOfferedKey, true);
      return true;
    } catch (e) {
      AppLogger.error('Engagement: recordCompletion failed', error: e);
      return false;
    }
  }

  /// Consecutive days, ending today (or yesterday if nothing is done yet
  /// today), with at least one completed task.
  static int streak(Iterable<Task> tasks, DateTime now) {
    final days = <DateTime>{
      for (final t in tasks)
        if (t.isCompleted && t.completedAt != null && t.isDeleted != true)
          _day(t.completedAt!.toLocal()),
    };
    var day = _day(now);
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// Tasks completed in the 7 days up to [now].
  static int completedThisWeek(Iterable<Task> tasks, DateTime now) {
    final since = _day(now).subtract(const Duration(days: 6));
    return tasks
        .where(
          (t) =>
              t.isCompleted &&
              t.isDeleted != true &&
              t.completedAt != null &&
              !t.completedAt!.toLocal().isBefore(since),
        )
        .length;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
