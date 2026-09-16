import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/core/services/offline_write_queue_service.dart';
import 'package:rocis_tasks/core/services/auth/google_oauth_manager.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth & Token Lifecycle Integration', () {
    late GoogleOAuthManager oauthManager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      oauthManager = GoogleOAuthManager(ErrorHandlingService());
    });

    testWidgets('caches token, verifies validity, and handles invalidation', (
      tester,
    ) async {
      // Baseline: no cached credentials
      expect(await oauthManager.hasCachedGoogleCredentials(), isFalse);
      expect(await oauthManager.isTokenValid(), isFalse);

      // Save user identity
      await oauthManager.saveGoogleUserIdentity(
        email: 'user@example.com',
        id: 'user_123',
      );
      expect(await oauthManager.hasCachedGoogleCredentials(), isTrue);
      expect(await oauthManager.getSavedGoogleUserEmail(), 'user@example.com');
      expect(await oauthManager.getSavedGoogleUserId(), 'user_123');

      // Cache access token
      await oauthManager.cacheGoogleAccessToken('mock_access_token_xyz');
      expect(await oauthManager.isTokenValid(), isTrue);
      expect(oauthManager.isGoogleTasksTokenExpired, isFalse);

      // Fetch cached token directly
      final resolvedToken = await oauthManager.getGoogleAccessToken();
      expect(resolvedToken, 'mock_access_token_xyz');

      // Invalidate token
      await oauthManager.invalidateToken();
      expect(await oauthManager.isTokenValid(), isFalse);
      expect(oauthManager.isGoogleTasksTokenExpired, isTrue);
    });
  });

  group('Offline Write Queue & Data Resilience Integration', () {
    late OfflineWriteQueueService queueService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      queueService = OfflineWriteQueueService();
      await queueService.init();
      queueService.clearForTesting();
    });

    testWidgets('enqueues, persists, and collapses offline write operations', (
      tester,
    ) async {
      // 1. Enqueue creation
      await queueService.enqueue(
        type: OfflineOperationType.createTask,
        entityId: 'task_001',
        payload: {'title': 'Integration Test Task', 'priority': 'high'},
      );

      expect(queueService.queue.length, 1);
      expect(queueService.hasPendingWrites, isTrue);

      // 2. Enqueue multiple updates (should collapse and merge with existing createTask)
      await queueService.enqueue(
        type: OfflineOperationType.updateTask,
        entityId: 'task_001',
        payload: {'title': 'Integration Test Task (V2)'},
      );
      await queueService.enqueue(
        type: OfflineOperationType.updateTask,
        entityId: 'task_001',
        payload: {'title': 'Integration Test Task (Final)'},
      );

      expect(queueService.queue.length, 1);
      expect(
        queueService.queue.first.payload?['title'],
        'Integration Test Task (Final)',
      );
      expect(
        queueService.queue.first.payload?['priority'],
        'high',
      );

      // 3. Enqueue second entity
      await queueService.enqueue(
        type: OfflineOperationType.createTask,
        entityId: 'task_002',
        payload: {'title': 'Second Task'},
      );
      expect(queueService.queue.length, 2);

      // 4. Verify persistence across re-initialization
      final reloadedService = OfflineWriteQueueService();
      await reloadedService.init();
      expect(reloadedService.queue.length, 2);
      expect(reloadedService.hasPendingWrites, isTrue);
    });

    testWidgets('conflict resolution merges local and remote task changes', (
      tester,
    ) async {
      final subA = SubTask(id: 's_a', title: 'Part A', isCompleted: true);
      final subB = SubTask(id: 's_b', title: 'Part B', isCompleted: false);
      final subC = SubTask(id: 's_c', title: 'Part C', isCompleted: true);

      final local = Task(
        id: 'task_merge',
        title: 'Local Modified Title',
        subTasks: [subA, subB],
      );

      final remote = Task(
        id: 'task_merge',
        title: 'Remote Original Title',
        subTasks: [subA.copyWith(isCompleted: false), subC],
      );

      final resolvedWithoutPendingWrite = TaskConflictResolver.resolveTaskConflict(
        localTask: local,
        remoteTask: remote,
        hasPendingLocalWrite: false,
      );

      // Subtasks should union to 3 items
      expect(resolvedWithoutPendingWrite.subTasks?.length, 3);
      final subTaskIds =
          resolvedWithoutPendingWrite.subTasks?.map((s) => s.id).toSet();
      expect(subTaskIds, containsAll(['s_a', 's_b', 's_c']));
    });
  });
}
