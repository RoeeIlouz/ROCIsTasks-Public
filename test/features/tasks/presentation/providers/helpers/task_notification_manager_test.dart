import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/helpers/task_notification_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskNotificationManager Tests', () {
    late TaskNotificationManager manager;

    setUp(() {
      manager = TaskNotificationManager();
    });

    test('getSnoozedDate calculates correct offsets', () {
      final base = DateTime(2026, 8, 1, 10, 0);

      expect(
        manager.getSnoozedDate(base, 'snooze_10'),
        equals(base.add(const Duration(minutes: 10))),
      );

      expect(
        manager.getSnoozedDate(base, 'snooze_60'),
        equals(base.add(const Duration(hours: 1))),
      );

      expect(
        manager.getSnoozedDate(base, 'default'),
        equals(base.add(const Duration(minutes: 15))),
      );
    });

    test('applyQuietHours shifts time into post-quiet-hours when inside quiet range', () {
      // Quiet hours: 22:00 (1320m) to 07:00 (420m) next morning
      final quietStart = 22 * 60;
      final quietEnd = 7 * 60;

      // 23:30 is in quiet hours
      final insideQuiet = DateTime(2026, 8, 1, 23, 30);
      final shifted = manager.applyQuietHours(
        insideQuiet,
        quietHoursEnabled: true,
        quietStartMinutes: quietStart,
        quietEndMinutes: quietEnd,
      );

      // Should shift to 07:00 next day
      expect(shifted.day, equals(2));
      expect(shifted.hour, equals(7));
      expect(shifted.minute, equals(0));
    });

    test('applyQuietHours leaves date unchanged when outside quiet hours', () {
      final quietStart = 22 * 60;
      final quietEnd = 7 * 60;

      // 14:00 is outside quiet hours
      final outsideQuiet = DateTime(2026, 8, 1, 14, 0);
      final result = manager.applyQuietHours(
        outsideQuiet,
        quietHoursEnabled: true,
        quietStartMinutes: quietStart,
        quietEndMinutes: quietEnd,
      );

      expect(result, equals(outsideQuiet));
    });

    test('getNotificationIdsForTask returns base ID plus nag IDs', () {
      final task = Task(id: 'test_task_123', title: 'Test');
      final ids = manager.getNotificationIdsForTask(task);

      expect(ids.length, equals(TaskNotificationManager.maxNagNotifications + 1));
      expect(ids.toSet().length, equals(ids.length)); // All unique IDs
    });
  });
}
