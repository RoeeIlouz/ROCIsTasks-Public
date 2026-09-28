import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/services/task_share_service.dart';

void main() {
  late TaskShareService service;

  setUp(() {
    service = TaskShareService();
  });

  group('TaskShareService - Offline Encoding & Decoding', () {
    test('encodes and decodes simple task payload correctly', () {
      final task = Task(
        title: 'Buy Groceries',
        description: 'Milk, Eggs, Bread',
        priority: TaskPriority.high,
        dueDate: DateTime(2026, 10, 15, 14, 30),
      );

      final payload = service.generateOfflinePayload(
        task,
        categoryName: 'Personal',
      );

      expect(payload.startsWith(TaskShareService.offlineScheme), isTrue);
      expect(payload, contains('?d='));

      final decoded = service.decodeOfflinePayload(payload);
      expect(decoded, isNotNull);
      expect(decoded!['t'], equals('Buy Groceries'));
      expect(decoded['d'], equals('Milk, Eggs, Bread'));
      expect(decoded['p'], equals(TaskPriority.high.index));
      expect(decoded['c'], equals('Personal'));
      expect(decoded['due'], contains('2026-10-15'));
    });

    test('resets all subtasks to uncompleted upon resolution', () async {
      final task = Task(
        title: 'Project Launch',
        description: 'Checklist for launch day',
        subTasks: [
          SubTask(title: 'Step 1', isCompleted: true),
          SubTask(title: 'Step 2', isCompleted: true),
          SubTask(title: 'Step 3', isCompleted: false),
        ],
      );

      final payload = service.generateOfflinePayload(task);
      final shareData = await service.resolveQrString(payload, []);

      expect(shareData.task.title, equals('Project Launch'));
      expect(shareData.task.subTasks, isNotNull);
      expect(shareData.task.subTasks!.length, equals(3));
      for (final st in shareData.task.subTasks!) {
        expect(
          st.isCompleted,
          isFalse,
          reason: 'Subtask must be reset to uncompleted',
        );
      }
    });

    test('generates fresh UUID and strips local sync metadata', () async {
      final task = Task(
        id: 'original-uuid-12345',
        title: 'Confidential Task',
        syncWithGoogleTasks: true,
        googleTaskId: 'gtask-abc',
        googleTaskListId: 'list-xyz',
        attachmentPaths: ['/data/user/0/file.pdf'],
      );

      final payload = service.generateOfflinePayload(task);
      final shareData = await service.resolveQrString(payload, []);

      expect(shareData.task.id, isNot(equals('original-uuid-12345')));
      expect(shareData.task.syncWithGoogleTasks, isFalse);
      expect(shareData.task.googleTaskId, isNull);
      expect(shareData.task.googleTaskListId, isNull);
      expect(shareData.task.attachmentPaths, isEmpty);
    });

    test('matches local category by name (case-insensitive)', () async {
      final List<Category> localCategories = [
        Category(
          id: 'cat-work-99',
          name: 'Work',
          colorValue: 0xFF4285F4,
          iconCode: 0xe123,
        ),
        Category(
          id: 'cat-home-00',
          name: 'Home',
          colorValue: 0xFF34A853,
          iconCode: 0xe124,
        ),
      ];

      final task = Task(title: 'Team meeting');
      final payload = service.generateOfflinePayload(
        task,
        categoryName: 'work',
      );

      final shareData = await service.resolveQrString(payload, localCategories);

      expect(shareData.task.categoryId, equals('cat-work-99'));
      expect(shareData.task.categoryIds, contains('cat-work-99'));
      expect(shareData.suggestedCategoryName, isNull);
    });

    test(
      'handles unknown category gracefully and provides suggestion',
      () async {
        final List<Category> localCategories = [
          Category(
            id: 'cat-home-00',
            name: 'Home',
            colorValue: 0xFF34A853,
            iconCode: 0xe124,
          ),
        ];

        final task = Task(title: 'New gym routine');
        final payload = service.generateOfflinePayload(
          task,
          categoryName: 'Fitness',
        );

        final shareData = await service.resolveQrString(
          payload,
          localCategories,
        );

        expect(shareData.task.categoryId, isNull);
        expect(shareData.suggestedCategoryName, equals('Fitness'));
      },
    );

    test('throws StateError on unrecognized or invalid QR strings', () {
      expect(
        () => service.resolveQrString('https://example.com/random', []),
        throwsA(isA<StateError>()),
      );
    });
  });
}
