import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/offline_write_queue_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QueuedWriteOperation serialization', () {
    test('serializes and deserializes correctly', () {
      final op = QueuedWriteOperation(
        id: 'op_1',
        type: OfflineOperationType.createTask,
        entityId: 'task_123',
        payload: {'title': 'Essay draft', 'priority': 'high'},
        timestamp: DateTime(2026, 9, 7, 12, 0, 0),
        retryCount: 1,
      );

      final json = op.toJson();
      final restored = QueuedWriteOperation.fromJson(json);

      expect(restored.id, op.id);
      expect(restored.type, OfflineOperationType.createTask);
      expect(restored.entityId, 'task_123');
      expect(restored.payload?['title'], 'Essay draft');
      expect(restored.retryCount, 1);
    });
  });

  group('OfflineWriteQueueService queue collapsing', () {
    late OfflineWriteQueueService queueService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      queueService = OfflineWriteQueueService();
      await queueService.init();
      queueService.clearForTesting();
    });

    test(
      'collapses consecutive update operations on the same entity',
      () async {
        await queueService.enqueue(
          type: OfflineOperationType.updateTask,
          entityId: 'doc_1',
          payload: {'title': 'Version 1'},
        );

        await queueService.enqueue(
          type: OfflineOperationType.updateTask,
          entityId: 'doc_1',
          payload: {'title': 'Version 2'},
        );

        final ops = queueService.queue;
        expect(ops.length, 1);
        expect(ops.first.payload?['title'], 'Version 2');
      },
    );

    test('delete operation supersedes prior update operations', () async {
      await queueService.enqueue(
        type: OfflineOperationType.updateTask,
        entityId: 'doc_2',
        payload: {'title': 'To be deleted'},
      );

      await queueService.enqueue(
        type: OfflineOperationType.deleteTask,
        entityId: 'doc_2',
        payload: {},
      );

      final ops = queueService.queue;
      expect(ops.length, 1);
      expect(ops.first.type, OfflineOperationType.deleteTask);
    });
  });

  group('TaskConflictResolver field and subtask merging', () {
    test('merges subtasks by ID preserving both sets', () {
      final sub1 = SubTask(
        id: 'st_1',
        title: 'Outline essay',
        isCompleted: true,
      );
      final sub2 = SubTask(
        id: 'st_2',
        title: 'Write intro',
        isCompleted: false,
      );
      final sub3 = SubTask(id: 'st_3', title: 'Proofread', isCompleted: false);

      final localTask = Task(
        id: 't1',
        title: 'Local Research Essay',
        description: 'Local desc',
        subTasks: [sub1, sub2],
      );

      final remoteTask = Task(
        id: 't1',
        title: 'Cloud Research Essay',
        description: 'Cloud desc',
        subTasks: [sub1.copyWith(isCompleted: false), sub3],
      );

      final resolved = TaskConflictResolver.resolveTaskConflict(
        localTask: localTask,
        remoteTask: remoteTask,
        hasPendingLocalWrite: false,
      );

      // Should union subtasks to 3 unique subtasks
      expect(resolved.subTasks?.length, 3);
      final resolvedIds = resolved.subTasks?.map((s) => s.id).toSet();
      expect(resolvedIds, containsAll(['st_1', 'st_2', 'st_3']));
    });

    test('prioritizes local task when local write is pending', () {
      final localTask = Task(id: 't2', title: 'Draft in flight');
      final remoteTask = Task(id: 't2', title: 'Old Cloud copy');

      final resolved = TaskConflictResolver.resolveTaskConflict(
        localTask: localTask,
        remoteTask: remoteTask,
        hasPendingLocalWrite: true,
      );

      expect(resolved.title, 'Draft in flight');
    });
  });
}
