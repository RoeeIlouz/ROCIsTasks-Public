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
        TaskRecurrenceService.getPresetFromRule('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'),
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
    });
  });
}
