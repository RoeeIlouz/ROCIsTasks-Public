import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';

void main() {
  group('SubTask Model', () {
    group('constructor', () {
      test('should create subtask with required fields', () {
        final sub = SubTask(title: 'Do laundry');
        expect(sub.title, 'Do laundry');
        expect(sub.isCompleted, false);
        expect(sub.id, isNotEmpty);
      });

      test('should generate unique IDs', () {
        final s1 = SubTask(title: 'A');
        final s2 = SubTask(title: 'B');
        expect(s1.id, isNot(equals(s2.id)));
      });

      test('should accept custom ID', () {
        final sub = SubTask(id: 'custom', title: 'X');
        expect(sub.id, 'custom');
      });
    });

    group('copyWith', () {
      test('should copy unchanged', () {
        final sub = SubTask(id: '1', title: 'Original', isCompleted: true);
        final copy = sub.copyWith();
        expect(copy.id, '1');
        expect(copy.title, 'Original');
        expect(copy.isCompleted, true);
      });

      test('should copy with changed title', () {
        final sub = SubTask(id: '1', title: 'Old');
        final copy = sub.copyWith(title: 'New');
        expect(copy.title, 'New');
        expect(copy.id, '1');
      });

      test('should copy with changed completion', () {
        final sub = SubTask(id: '1', title: 'X');
        final copy = sub.copyWith(isCompleted: true);
        expect(copy.isCompleted, true);
      });
    });

    group('toMap / fromMap', () {
      test('should roundtrip', () {
        final sub = SubTask(id: 'st-1', title: 'Task', isCompleted: true);
        final map = sub.toMap();
        final restored = SubTask.fromMap(map);
        expect(restored.id, 'st-1');
        expect(restored.title, 'Task');
        expect(restored.isCompleted, true);
      });

      test('should default isCompleted to false', () {
        final map = {'id': 'x', 'title': 'Y'};
        final sub = SubTask.fromMap(map);
        expect(sub.isCompleted, false);
      });

      test('should default title to empty', () {
        final map = {'id': 'x'};
        final sub = SubTask.fromMap(map);
        expect(sub.title, '');
      });
    });
  });
}
