import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:rocis_tasks/core/services/google_tasks_service.dart';
import 'package:rocis_tasks/core/services/offline_write_queue_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/helpers/task_sync_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends Mock implements AuthService {}

class MockFirestoreService extends Mock implements FirestoreService {}

class MockGoogleTasksService extends Mock implements GoogleTasksService {}

class MockCalendarService extends Mock implements CalendarService {}

class MockLocalTaskSource extends Mock implements LocalTaskSource {}

class MockErrorHandlingService extends Mock implements ErrorHandlingService {}

class MockUser extends Mock implements User {}

void main() {
  final t0 = DateTime(2026, 9, 1, 12);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  group('Task edit time', () {
    test('lastModified falls back to completedAt, then createdAt', () {
      expect(Task(title: 'a', createdAt: at(0)).lastModified, at(0));
      expect(
        Task(title: 'a', createdAt: at(0), completedAt: at(5)).lastModified,
        at(5),
      );
      expect(
        Task(
          title: 'a',
          createdAt: at(0),
          completedAt: at(5),
          modifiedAt: at(9),
        ).lastModified,
        at(9),
      );
    });

    test('modifiedAt round-trips through Firestore maps', () {
      final task = Task(id: 'x', title: 'a', modifiedAt: at(3));
      final restored = Task.fromMap(task.toFirestoreMap());
      expect(restored.modifiedAt, at(3));
    });

    test('cloud edit time prefers modifiedAt, falls back to updatedAt', () {
      expect(
        Task.cloudModifiedAt({
          'modifiedAt': Timestamp.fromDate(at(1)),
          'updatedAt': Timestamp.fromDate(at(8)),
        }),
        at(1),
      );
      expect(
        Task.cloudModifiedAt({'updatedAt': Timestamp.fromDate(at(8))}),
        at(8),
      );
      expect(Task.cloudModifiedAt({}), isNull);
    });
  });

  group('TaskConflictResolver last-write-wins', () {
    test('newer remote edit replaces the local copy', () {
      final local = Task(id: '1', title: 'old', modifiedAt: at(1));
      final remote = Task(id: '1', title: 'new', modifiedAt: at(2));
      final result = TaskConflictResolver.resolveTaskConflict(
        localTask: local,
        remoteTask: remote,
        hasPendingLocalWrite: false,
      );
      expect(result.title, 'new');
    });

    test('newer local edit is kept over an older remote copy', () {
      final local = Task(id: '1', title: 'mine', modifiedAt: at(5));
      final remote = Task(id: '1', title: 'stale', modifiedAt: at(2));
      final result = TaskConflictResolver.resolveTaskConflict(
        localTask: local,
        remoteTask: remote,
        hasPendingLocalWrite: false,
      );
      expect(result.title, 'mine');
      expect(result.modifiedAt, at(5));
    });
  });

  group('TaskSyncManager.uploadLocalDataToCloud', () {
    late MockAuthService auth;
    late MockFirestoreService firestore;
    late MockLocalTaskSource source;
    late MockErrorHandlingService errors;
    late TaskSyncManager manager;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      auth = MockAuthService();
      firestore = MockFirestoreService();
      source = MockLocalTaskSource();
      errors = MockErrorHandlingService();

      final user = MockUser();
      when(() => user.uid).thenReturn('u1');
      when(() => auth.currentUser).thenReturn(user);
      when(() => source.getCategories()).thenReturn([]);
      when(
        () => firestore.uploadAll(
          categories: any(named: 'categories'),
          tasks: any(named: 'tasks'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => errors.logError(any(), any(), reason: any(named: 'reason')),
      ).thenAnswer((_) async {});

      manager = TaskSyncManager(
        authService: auth,
        firestoreService: firestore,
        googleTasksService: MockGoogleTasksService(),
        calendarService: MockCalendarService(),
        source: source,
        errorHandlingService: errors,
      );
    });

    List<Task> uploadedTasks() =>
        verify(
              () => firestore.uploadAll(
                categories: any(named: 'categories'),
                tasks: captureAny(named: 'tasks'),
              ),
            ).captured.single
            as List<Task>;

    test('uploads only tasks missing from or older in the cloud', () async {
      final missing = Task(id: 'missing', title: 'm', modifiedAt: at(1));
      final newerHere = Task(id: 'newer', title: 'n', modifiedAt: at(9));
      final newerInCloud = Task(id: 'stale', title: 's', modifiedAt: at(1));
      when(
        () => source.getTasks(),
      ).thenReturn([missing, newerHere, newerInCloud]);
      when(
        () => firestore.fetchTaskEditTimes(any()),
      ).thenAnswer((_) async => {'newer': at(5), 'stale': at(5)});

      await manager.uploadLocalDataToCloud();

      expect(uploadedTasks().map((t) => t.id), ['missing', 'newer']);
    });

    test('uploads nothing and keeps retrying when offline', () async {
      when(
        () => source.getTasks(),
      ).thenReturn([Task(id: 'a', title: 'a', modifiedAt: at(1))]);
      when(
        () => firestore.fetchTaskEditTimes(any()),
      ).thenThrow(Exception('unavailable'));

      await manager.uploadLocalDataToCloud();

      verifyNever(
        () => firestore.uploadAll(
          categories: any(named: 'categories'),
          tasks: any(named: 'tasks'),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(TaskSyncManager.uploadWatermarkKey('u1')), isNull);
    });

    test('later runs only check tasks edited since the last run', () async {
      final untouched = Task(id: 'old', title: 'o', modifiedAt: at(1));
      final edited = Task(id: 'edited', title: 'e', modifiedAt: at(1));
      when(() => source.getTasks()).thenReturn([untouched, edited]);
      when(
        () => firestore.fetchTaskEditTimes(any()),
      ).thenAnswer((_) async => {});

      await manager.uploadLocalDataToCloud();
      edited.touch();
      clearInteractions(firestore);

      await manager.uploadLocalDataToCloud();

      final checkedIds =
          verify(
                () => firestore.fetchTaskEditTimes(captureAny()),
              ).captured.single
              as List<String>;
      expect(checkedIds, ['edited']);
    });
  });
}
