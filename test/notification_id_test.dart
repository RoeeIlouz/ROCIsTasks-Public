import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';

void main() {
  group('NotificationService.getNotificationId', () {
    test('should return the same ID for the same string', () {
      const id = 'task-123';
      final result1 = NotificationService.getNotificationId(id);
      final result2 = NotificationService.getNotificationId(id);
      expect(result1, equals(result2));
    });

    test('should return different IDs for different strings', () {
      const id1 = 'task-123';
      const id2 = 'task-456';
      final result1 = NotificationService.getNotificationId(id1);
      final result2 = NotificationService.getNotificationId(id2);
      expect(result1, isNot(equals(result2)));
    });
  });
}
