import 'package:rrule/rrule.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

enum RecurrencePreset {
  none,
  daily,
  weekdays,
  weekly,
  monthly,
  yearly,
  custom,
}

enum RecurrenceFrequency {
  daily,
  weekly,
  monthly,
  yearly,
}

class TaskRecurrenceService {
  static const String rruleDaily = 'FREQ=DAILY;INTERVAL=1';
  static const String rruleWeekdays = 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR';
  static const String rruleWeekly = 'FREQ=WEEKLY;INTERVAL=1';
  static const String rruleMonthly = 'FREQ=MONTHLY;INTERVAL=1';
  static const String rruleYearly = 'FREQ=YEARLY;INTERVAL=1';

  static String buildCustomRule({
    required RecurrenceFrequency frequency,
    required int interval,
  }) {
    final freqStr = switch (frequency) {
      RecurrenceFrequency.daily => 'DAILY',
      RecurrenceFrequency.weekly => 'WEEKLY',
      RecurrenceFrequency.monthly => 'MONTHLY',
      RecurrenceFrequency.yearly => 'YEARLY',
    };
    final clampedInterval = interval < 1 ? 1 : interval;
    return 'FREQ=$freqStr;INTERVAL=$clampedInterval';
  }

  static RecurrencePreset getPresetFromRule(String? rule) {
    if (rule == null || rule.trim().isEmpty) return RecurrencePreset.none;

    final normalized = _normalizeRule(rule);
    if (normalized == rruleDaily) return RecurrencePreset.daily;
    if (normalized == rruleWeekdays) return RecurrencePreset.weekdays;
    if (normalized == rruleWeekly) return RecurrencePreset.weekly;
    if (normalized == rruleMonthly) return RecurrencePreset.monthly;
    if (normalized == rruleYearly) return RecurrencePreset.yearly;

    return RecurrencePreset.custom;
  }

  static String _normalizeRule(String rule) {
    var cleaned = rule.trim();
    if (cleaned.startsWith('RRULE:')) {
      cleaned = cleaned.substring(6).trim();
    }
    return cleaned;
  }

  static (RecurrenceFrequency, int) parseCustomRule(String? rule) {
    if (rule == null || rule.isEmpty) {
      return (RecurrenceFrequency.daily, 1);
    }
    final normalized = _normalizeRule(rule);
    final parts = normalized.split(';');
    RecurrenceFrequency freq = RecurrenceFrequency.daily;
    int interval = 1;

    for (final part in parts) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      final key = kv[0].toUpperCase().trim();
      final val = kv[1].toUpperCase().trim();

      if (key == 'FREQ') {
        freq = switch (val) {
          'DAILY' => RecurrenceFrequency.daily,
          'WEEKLY' => RecurrenceFrequency.weekly,
          'MONTHLY' => RecurrenceFrequency.monthly,
          'YEARLY' => RecurrenceFrequency.yearly,
          _ => RecurrenceFrequency.daily,
        };
      } else if (key == 'INTERVAL') {
        interval = int.tryParse(val) ?? 1;
      }
    }
    return (freq, interval < 1 ? 1 : interval);
  }

  static String getRecurrenceLabel(String? rule, AppLocalizations l10n) {
    if (rule == null || rule.trim().isEmpty) {
      return l10n.repeatNone;
    }

    final normalized = _normalizeRule(rule);
    if (normalized == rruleDaily) return l10n.repeatDaily;
    if (normalized == rruleWeekdays) return l10n.repeatWeekdays;
    if (normalized == rruleWeekly) return l10n.repeatWeekly;
    if (normalized == rruleMonthly) return l10n.repeatMonthly;
    if (normalized == rruleYearly) return l10n.repeatYearly;

    final (freq, interval) = parseCustomRule(rule);
    final unitLabel = switch (freq) {
      RecurrenceFrequency.daily =>
        interval == 1 ? l10n.daySingular : l10n.daysPlural,
      RecurrenceFrequency.weekly =>
        interval == 1 ? l10n.weekSingular : l10n.weeksPlural,
      RecurrenceFrequency.monthly =>
        interval == 1 ? l10n.monthSingular : l10n.monthsPlural,
      RecurrenceFrequency.yearly =>
        interval == 1 ? l10n.yearSingular : l10n.yearsPlural,
    };

    return '${l10n.repeatsEvery} $interval $unitLabel';
  }

  static DateTime? getNextDueDate(
    DateTime currentDueDate,
    String recurrenceRule, {
    DateTime? after,
  }) {
    try {
      final normalized = _normalizeRule(recurrenceRule);
      final rrule = RecurrenceRule.fromString('RRULE:$normalized');
      final targetAfter = after ?? currentDueDate;

      // Start evaluation from start date in UTC
      final startUtc = currentDueDate.toUtc();
      final targetAfterUtc = targetAfter.toUtc();

      // Retrieve instances
      final instances = rrule.getInstances(start: startUtc);
      for (final dt in instances) {
        if (dt.isAfter(targetAfterUtc)) {
          // Reconstruct in local time preserving original hour/minute/second
          return DateTime(
            dt.year,
            dt.month,
            dt.day,
            currentDueDate.hour,
            currentDueDate.minute,
            currentDueDate.second,
            currentDueDate.millisecond,
          );
        }
      }
    } catch (_) {
      // Fallback manual recurrence calculation if RRULE parser encounters edge cases
      return _calculateNextDateFallback(currentDueDate, recurrenceRule, after: after);
    }

    return _calculateNextDateFallback(currentDueDate, recurrenceRule, after: after);
  }

  static DateTime _calculateNextDateFallback(
    DateTime currentDueDate,
    String recurrenceRule, {
    DateTime? after,
  }) {
    final (freq, interval) = parseCustomRule(recurrenceRule);
    final target = after ?? currentDueDate;
    var next = currentDueDate;

    final normalized = _normalizeRule(recurrenceRule);
    final isWeekdays = normalized.contains('BYDAY=MO,TU,WE,TH,FR');

    while (!next.isAfter(target)) {
      if (isWeekdays) {
        next = next.add(const Duration(days: 1));
        while (next.weekday == DateTime.saturday || next.weekday == DateTime.sunday) {
          next = next.add(const Duration(days: 1));
        }
      } else {
        switch (freq) {
          case RecurrenceFrequency.daily:
            next = next.add(Duration(days: interval));
            break;
          case RecurrenceFrequency.weekly:
            next = next.add(Duration(days: interval * 7));
            break;
          case RecurrenceFrequency.monthly:
            final newMonth = next.month + interval;
            final targetYear = next.year + ((newMonth - 1) ~/ 12);
            final targetMonth = ((newMonth - 1) % 12) + 1;
            final daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
            final targetDay = currentDueDate.day > daysInTargetMonth
                ? daysInTargetMonth
                : currentDueDate.day;
            next = DateTime(
              targetYear,
              targetMonth,
              targetDay,
              currentDueDate.hour,
              currentDueDate.minute,
              currentDueDate.second,
            );
            break;
          case RecurrenceFrequency.yearly:
            final targetYear = next.year + interval;
            final daysInTargetMonth = DateTime(targetYear, currentDueDate.month + 1, 0).day;
            final targetDay = currentDueDate.day > daysInTargetMonth
                ? daysInTargetMonth
                : currentDueDate.day;
            next = DateTime(
              targetYear,
              currentDueDate.month,
              targetDay,
              currentDueDate.hour,
              currentDueDate.minute,
              currentDueDate.second,
            );
            break;
        }
      }
    }

    return next;
  }

  static Task createNextRecurringTask(Task completedTask, DateTime nextDueDate) {
    return Task(
      title: completedTask.title,
      description: completedTask.description,
      isCompleted: false,
      dueDate: nextDueDate,
      priority: completedTask.priority,
      categoryId: completedTask.categoryId,
      categoryIds: List<String>.from(completedTask.categoryIds),
      isDeleted: false,
      isPinned: completedTask.isPinned ?? false,
      subTasks: completedTask.subTasks
          ?.map((st) => SubTask(
                title: st.title,
                isCompleted: false,
              ))
          .toList(),
      recurrenceRule: completedTask.recurrenceRule,
      requireSubTasksBeforeReminders: completedTask.requireSubTasksBeforeReminders,
      syncWithGoogleTasks: completedTask.syncWithGoogleTasks,
      attachmentPaths: List<String>.from(completedTask.attachmentPaths),
      skipReminders: completedTask.skipReminders,
      isGroceryList: completedTask.isGroceryList,
      customFields: completedTask.customFields
          ?.map((cf) => cf.copyWith())
          .toList(),
    );
  }
}
