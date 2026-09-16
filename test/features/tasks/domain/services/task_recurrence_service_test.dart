import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/services/task_recurrence_service.dart';

void main() {
  group('TaskRecurrenceService Tests', () {
    test('Preset identification', () {
      expect(
        TaskRecurrenceService.getPresetFromRule(null),
        RecurrencePreset.none,
      );
      expect(
        TaskRecurrenceService.getPresetFromRule(''),
        RecurrencePreset.none,
      );
      expect(
        TaskRecurrenceService.getPresetFromRule('FREQ=DAILY;INTERVAL=1'),
        RecurrencePreset.daily,
      );
      expect(
        TaskRecurrenceService.getPresetFromRule('RRULE:FREQ=DAILY;INTERVAL=1'),
        RecurrencePreset.daily,
      );
      expect(
        TaskRecurrenceService.getPresetFromRule(
          'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
        ),
        RecurrencePreset.weekdays,
      );
      expect(
        TaskRecurrenceService.getPresetFromRule('FREQ=WEEKLY;INTERVAL=1'),
        RecurrencePreset.weekly,
      );
      expect(
        TaskRecurrenceService.getPresetFromRule('FREQ=MONTHLY;INTERVAL=1'),
        RecurrencePreset.monthly,
      );
      expect(
        TaskRecurrenceService.getPresetFromRule('FREQ=YEARLY;INTERVAL=1'),
        RecurrencePreset.yearly,
      );
      expect(
        TaskRecurrenceService.getPresetFromRule('FREQ=DAILY;INTERVAL=3'),
        RecurrencePreset.custom,
      );
    });

    test('Custom rule builder & parser', () {
      final rule = TaskRecurrenceService.buildCustomRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
      );
      expect(rule, 'FREQ=WEEKLY;INTERVAL=2');

      final (freq, interval) = TaskRecurrenceService.parseCustomRule(rule);
      expect(freq, RecurrenceFrequency.weekly);
      expect(interval, 2);
    });

    test('Daily recurrence calculation preserves time', () {
      final baseDate = DateTime(2026, 8, 15, 14, 30);
      final nextDate = TaskRecurrenceService.getNextDueDate(
        baseDate,
        TaskRecurrenceService.rruleDaily,
      );

      expect(nextDate, isNotNull);
      expect(nextDate!.year, 2026);
      expect(nextDate.month, 8);
      expect(nextDate.day, 16);
      expect(nextDate.hour, 14);
      expect(nextDate.minute, 30);
    });

    test('Weekday recurrence skips weekends', () {
      // 2026-08-14 is Friday
      final friday = DateTime(2026, 8, 14, 9, 0);
      final nextDate = TaskRecurrenceService.getNextDueDate(
        friday,
        TaskRecurrenceService.rruleWeekdays,
      );

      expect(nextDate, isNotNull);
      expect(nextDate!.weekday, DateTime.monday);
      expect(nextDate.day, 17);
      expect(nextDate.hour, 9);
      expect(nextDate.minute, 0);
    });

    test('Weekly recurrence calculation adds 7 days', () {
      final baseDate = DateTime(2026, 8, 15, 10, 0);
      final nextDate = TaskRecurrenceService.getNextDueDate(
        baseDate,
        TaskRecurrenceService.rruleWeekly,
      );

      expect(nextDate, isNotNull);
      expect(nextDate!.day, 22);
      expect(nextDate.hour, 10);
      expect(nextDate.minute, 0);
    });

    test('Monthly recurrence calculation adds 1 month', () {
      final baseDate = DateTime(2026, 8, 15, 18, 45);
      final nextDate = TaskRecurrenceService.getNextDueDate(
        baseDate,
        TaskRecurrenceService.rruleMonthly,
      );

      expect(nextDate, isNotNull);
      expect(nextDate!.year, 2026);
      expect(nextDate.month, 9);
      expect(nextDate.day, 15);
      expect(nextDate.hour, 18);
      expect(nextDate.minute, 45);
    });

    test('Yearly recurrence calculation adds 1 year', () {
      final baseDate = DateTime(2026, 8, 15, 12, 0);
      final nextDate = TaskRecurrenceService.getNextDueDate(
        baseDate,
        TaskRecurrenceService.rruleYearly,
      );

      expect(nextDate, isNotNull);
      expect(nextDate!.year, 2027);
      expect(nextDate.month, 8);
      expect(nextDate.day, 15);
      expect(nextDate.hour, 12);
      expect(nextDate.minute, 0);
    });

    test('createNextRecurringTask clones task and resets subtasks', () {
      final original = Task(
        id: 'task-1',
        title: 'Water plants',
        description: 'Living room and balcony',
        isCompleted: true,
        dueDate: DateTime(2026, 8, 15, 10, 0),
        priority: TaskPriority.high,
        categoryId: 'cat-home',
        categoryIds: ['cat-home'],
        recurrenceRule: TaskRecurrenceService.rruleDaily,
        subTasks: [
          SubTask(title: 'Living room', isCompleted: true),
          SubTask(title: 'Balcony', isCompleted: true),
        ],
        attachmentPaths: ['path/to/guide.pdf'],
        isGroceryList: false,
      );

      final nextDue = DateTime(2026, 8, 16, 10, 0);
      final nextTask = TaskRecurrenceService.createNextRecurringTask(
        original,
        nextDue,
      );

      expect(nextTask.id, isNot(equals(original.id)));
      expect(nextTask.title, 'Water plants');
      expect(nextTask.description, 'Living room and balcony');
      expect(nextTask.isCompleted, isFalse);
      expect(nextTask.dueDate, nextDue);
      expect(nextTask.priority, TaskPriority.high);
      expect(nextTask.categoryId, 'cat-home');
      expect(nextTask.categoryIds, ['cat-home']);
      expect(nextTask.recurrenceRule, TaskRecurrenceService.rruleDaily);
      expect(nextTask.attachmentPaths, ['path/to/guide.pdf']);

      // Subtasks must be cloned and uncompleted
      expect(nextTask.subTasks, isNotNull);
      expect(nextTask.subTasks!.length, 2);
      expect(nextTask.subTasks![0].title, 'Living room');
      expect(nextTask.subTasks![0].isCompleted, isFalse);
      expect(nextTask.subTasks![1].title, 'Balcony');
      expect(nextTask.subTasks![1].isCompleted, isFalse);

      // Parent ID linkage must be assigned
      expect(nextTask.recurringParentId, original.id);
    });

    test(
      'Overdue recurrence advances strictly past after target and preserves time',
      () {
        // Due 10 days ago at 09:30 AM
        final baseDate = DateTime(2026, 8, 1, 9, 30);
        final currentMoment = DateTime(
          2026,
          8,
          11,
          14,
          0,
        ); // 2:00 PM on the 11th

        // Daily recurrence: Since 9:30 AM on the 11th has passed, next should be 12th at 09:30 AM
        final nextDaily = TaskRecurrenceService.getNextDueDate(
          baseDate,
          TaskRecurrenceService.rruleDaily,
          after: currentMoment,
        );
        expect(nextDaily, isNotNull);
        expect(nextDaily!.year, 2026);
        expect(nextDaily.month, 8);
        expect(nextDaily.day, 12);
        expect(nextDaily.hour, 9);
        expect(nextDaily.minute, 30);

        // Weekly recurrence: next weekly instance after currentMoment
        final nextWeekly = TaskRecurrenceService.getNextDueDate(
          baseDate,
          TaskRecurrenceService.rruleWeekly,
          after: currentMoment,
        );
        expect(nextWeekly, isNotNull);
        expect(nextWeekly!.year, 2026);
        expect(nextWeekly.month, 8);
        expect(nextWeekly.day, 15); // Aug 1 + 14 days
        expect(nextWeekly.hour, 9);
        expect(nextWeekly.minute, 30);
      },
    );

    test('Overdue recurrence when target day time has not yet passed', () {
      // Due 3 days ago at 18:00 (6:00 PM)
      final baseDate = DateTime(2026, 8, 1, 18, 0);
      final currentMoment = DateTime(2026, 8, 4, 10, 0); // 10:00 AM on the 4th

      // Since 6:00 PM on the 4th has NOT passed yet, it should be today (Aug 4) at 18:00
      final nextDaily = TaskRecurrenceService.getNextDueDate(
        baseDate,
        TaskRecurrenceService.rruleDaily,
        after: currentMoment,
      );
      expect(nextDaily, isNotNull);
      expect(nextDaily!.year, 2026);
      expect(nextDaily.month, 8);
      expect(nextDaily.day, 4);
      expect(nextDaily.hour, 18);
      expect(nextDaily.minute, 0);
    });

    test(
      'Anchoring recurrence to createdAt preserves original creation time',
      () {
        final createdAt = DateTime(2026, 8, 10, 16, 45, 12);
        final currentMoment = DateTime(2026, 8, 15, 10, 0);

        final nextDate = TaskRecurrenceService.getNextDueDate(
          createdAt,
          TaskRecurrenceService.rruleDaily,
          after: currentMoment,
        );
        expect(nextDate, isNotNull);
        expect(nextDate!.year, 2026);
        expect(nextDate.month, 8);
        expect(nextDate.day, 15); // Aug 15 16:45 is after 10:00
        expect(nextDate.hour, 16);
        expect(nextDate.minute, 45);
        expect(nextDate.second, 12);
      },
    );

    test(
      'adjustDueDateForCatchUp catches up overdue scheduled date to today',
      () {
        final scheduledDate = DateTime(2026, 8, 10, 9, 30);
        final today = DateTime(2026, 8, 15, 14, 0);

        final adjusted = TaskRecurrenceService.adjustDueDateForCatchUp(
          scheduledDate,
          today,
        );
        expect(adjusted.year, 2026);
        expect(adjusted.month, 8);
        expect(adjusted.day, 15);
        expect(adjusted.hour, 9);
        expect(adjusted.minute, 30);

        // When scheduledDate is today or future, it should not change
        final futureDate = DateTime(2026, 8, 16, 9, 30);
        final notAdjusted = TaskRecurrenceService.adjustDueDateForCatchUp(
          futureDate,
          today,
        );
        expect(notAdjusted, futureDate);
      },
    );

    test('createUpcomingPreviewTask creates preview task with preview_ ID', () {
      final completed = Task(
        id: 'task-100',
        title: 'Daily Standup',
        isCompleted: true,
        dueDate: DateTime(2026, 8, 15, 9, 0),
        recurrenceRule: TaskRecurrenceService.rruleDaily,
      );
      final nextDue = DateTime(2026, 8, 16, 9, 0);
      final preview = TaskRecurrenceService.createUpcomingPreviewTask(
        completed,
        nextDue,
      );

      expect(preview.id, 'preview_task-100');
      expect(preview.title, 'Daily Standup');
      expect(preview.dueDate, nextDue);
      expect(preview.isCompleted, isFalse);
      expect(preview.recurringParentId, 'task-100');
    });
  });
}
