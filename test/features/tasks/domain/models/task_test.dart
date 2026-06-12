import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';

void main() {
  group('Task Model', () {
    group('constructor', () {
      test('should create task with required fields', () {
        final task = Task(title: 'Test Task');
        expect(task.title, 'Test Task');
        expect(task.description, '');
        expect(task.isCompleted, false);
        expect(task.isDeleted, false);
        expect(task.isPinned, false);
        expect(task.priority, TaskPriority.medium);
        expect(task.dueDate, isNull);
        expect(task.categoryId, isNull);
        expect(task.id, isNotEmpty);
        expect(task.createdAt, isNotNull);
      });

      test('should generate unique IDs', () {
        final task1 = Task(title: 'Task 1');
        final task2 = Task(title: 'Task 2');
        expect(task1.id, isNot(equals(task2.id)));
      });

      test('should accept custom ID', () {
        final task = Task(id: 'custom-id', title: 'Test');
        expect(task.id, 'custom-id');
      });
    });

    group('copyWith', () {
      test('should copy with all fields unchanged', () {
        final task = Task(
          id: '1',
          title: 'Original',
          description: 'Desc',
          isCompleted: true,
          priority: TaskPriority.high,
          categoryId: 'cat-1',
          isDeleted: true,
          isPinned: true,
        );

        final copy = task.copyWith();
        expect(copy.id, task.id);
        expect(copy.title, task.title);
        expect(copy.description, task.description);
        expect(copy.isCompleted, task.isCompleted);
        expect(copy.priority, task.priority);
        expect(copy.categoryId, task.categoryId);
        expect(copy.isDeleted, task.isDeleted);
        expect(copy.isPinned, task.isPinned);
      });

      test('should copy with changed fields', () {
        final task = Task(id: '1', title: 'Original');
        final copy = task.copyWith(title: 'Updated', isCompleted: true);
        expect(copy.id, '1');
        expect(copy.title, 'Updated');
        expect(copy.isCompleted, true);
      });

      test('should copy with subtasks', () {
        final task = Task(id: '1', title: 'Original');
        final subTasks = [
          SubTask(id: 'st-1', title: 'Sub 1'),
          SubTask(id: 'st-2', title: 'Sub 2'),
        ];
        final copy = task.copyWith(subTasks: subTasks);
        expect(copy.subTasks, hasLength(2));
        expect(copy.subTasks![0].title, 'Sub 1');
      });

      test('should copy with attachment paths', () {
        final task = Task(id: '1', title: 'Original');
        final copy = task.copyWith(attachmentPaths: ['file1.pdf', 'image.png']);
        expect(copy.attachmentPaths, ['file1.pdf', 'image.png']);
      });
    });

    group('toMap / fromMap roundtrip', () {
      test('should roundtrip basic task', () {
        final task = Task(
          id: 'test-1',
          title: 'Test Task',
          description: 'A description',
          isCompleted: true,
          priority: TaskPriority.high,
          categoryId: 'cat-1',
          isDeleted: false,
          isPinned: true,
          createdAt: DateTime(2025, 1, 15, 10, 30),
        );

        final map = task.toMap();
        final restored = Task.fromMap(map);

        expect(restored.id, task.id);
        expect(restored.title, task.title);
        expect(restored.description, task.description);
        expect(restored.isCompleted, task.isCompleted);
        expect(restored.priority, task.priority);
        expect(restored.categoryId, task.categoryId);
        expect(restored.isDeleted, task.isDeleted);
        expect(restored.isPinned, task.isPinned);
        expect(restored.createdAt.year, task.createdAt.year);
      });

      test('should roundtrip task with dueDate', () {
        final dueDate = DateTime(2025, 6, 15, 14, 30);
        final task = Task(
          id: 'test-2',
          title: 'Task with date',
          dueDate: dueDate,
        );

        final map = task.toMap();
        final restored = Task.fromMap(map);

        expect(restored.dueDate, isNotNull);
        expect(restored.dueDate!.year, dueDate.year);
        expect(restored.dueDate!.month, dueDate.month);
        expect(restored.dueDate!.day, dueDate.day);
      });

      test('should roundtrip task with subtasks', () {
        final task = Task(
          id: 'test-3',
          title: 'Task with subtasks',
          subTasks: [
            SubTask(id: 'st-1', title: 'Sub 1', isCompleted: true),
            SubTask(id: 'st-2', title: 'Sub 2', isCompleted: false),
          ],
        );

        final map = task.toMap();
        final restored = Task.fromMap(map);

        expect(restored.subTasks, isNotNull);
        expect(restored.subTasks, hasLength(2));
        expect(restored.subTasks![0].title, 'Sub 1');
        expect(restored.subTasks![0].isCompleted, true);
        expect(restored.subTasks![1].isCompleted, false);
      });

      test('should roundtrip task with completedAt', () {
        final completedAt = DateTime(2025, 6, 10, 9, 0);
        final task = Task(
          id: 'test-4',
          title: 'Completed',
          isCompleted: true,
          completedAt: completedAt,
        );

        final map = task.toMap();
        final restored = Task.fromMap(map);

        expect(restored.isCompleted, true);
        expect(restored.completedAt, isNotNull);
        expect(restored.completedAt!.year, completedAt.year);
      });

      test('should handle null optional fields', () {
        final task = Task(id: 'test-5', title: 'Minimal');
        final map = task.toMap();
        final restored = Task.fromMap(map);

        expect(restored.dueDate, isNull);
        expect(restored.categoryId, isNull);
        expect(restored.completedAt, isNull);
        expect(restored.recurrenceRule, isNull);
        expect(restored.calendarEventId, isNull);
        expect(restored.calendarId, isNull);
      });
    });

    group('toFirestoreMap', () {
      test('should produce Firestore-compatible map', () {
        final task = Task(
          id: 'fs-1',
          title: 'Firestore Task',
          isCompleted: false,
          isDeleted: false,
          isPinned: true,
          priority: TaskPriority.medium,
        );

        final map = task.toFirestoreMap();
        expect(map['id'], 'fs-1');
        expect(map['title'], 'Firestore Task');
        expect(map['isCompleted'], false);
        expect(map['isDeleted'], false);
        expect(map['isPinned'], true);
        expect(map['priority'], 1); // medium = index 1
      });

      test('should default isDeleted and isPinned to false', () {
        final task = Task(id: 'fs-2', title: 'Minimal');
        final map = task.toFirestoreMap();
        expect(map['isDeleted'], false);
        expect(map['isPinned'], false);
      });
    });

    group('TaskPriority', () {
      test('should have correct enum values', () {
        expect(TaskPriority.low.index, 0);
        expect(TaskPriority.medium.index, 1);
        expect(TaskPriority.high.index, 2);
      });
    });
  });
}
