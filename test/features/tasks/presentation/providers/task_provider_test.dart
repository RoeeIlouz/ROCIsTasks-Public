import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/google_tasks_service.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';

class MockLocalTaskSource extends Mock implements LocalTaskSource {}

class MockNotificationService extends Mock implements NotificationService {}

class MockFirestoreService extends Mock implements FirestoreService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockAuthService extends Mock implements AuthService {}

class MockCalendarService extends Mock implements CalendarService {}

class MockGoogleTasksService extends Mock implements GoogleTasksService {}

class MockThemeService extends Mock implements ThemeService {}

class MockErrorHandlingService extends Mock implements ErrorHandlingService {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class TaskFake extends Fake implements Task {}

class StackTraceFake extends Fake implements StackTrace {}

class MockUser extends Mock implements User {}

class CategoryFake extends Fake implements Category {}

void main() {
  late TaskProvider taskProvider;
  late MockLocalTaskSource mockSource;
  late MockNotificationService mockNotificationService;
  late MockFirestoreService mockFirestoreService;
  late MockConnectivityService mockConnectivityService;
  late MockAuthService mockAuthService;
  late MockCalendarService mockCalendarService;
  late MockGoogleTasksService mockGoogleTasksService;
  late MockThemeService mockThemeService;
  late MockErrorHandlingService mockErrorHandlingService;
  late MockSubscriptionService mockSubscriptionService;
  late MockAnalyticsService mockAnalyticsService;

  setUpAll(() {
    registerFallbackValue(TaskFake());
    registerFallbackValue(StackTraceFake());
    registerFallbackValue(CategoryFake());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    mockSource = MockLocalTaskSource();
    mockNotificationService = MockNotificationService();
    mockFirestoreService = MockFirestoreService();
    mockConnectivityService = MockConnectivityService();
    mockAuthService = MockAuthService();
    mockCalendarService = MockCalendarService();
    mockGoogleTasksService = MockGoogleTasksService();
    mockThemeService = MockThemeService();
    mockErrorHandlingService = MockErrorHandlingService();
    mockSubscriptionService = MockSubscriptionService();
    mockAnalyticsService = MockAnalyticsService();

    // Default stubs
    when(() => mockSource.init()).thenAnswer((_) async => {});
    when(() => mockSource.getTasks()).thenReturn([]);
    when(() => mockSource.getCategories()).thenReturn([]);
    // Id lookups follow whatever getTasks()/getCategories() currently return.
    when(() => mockSource.getTask(any())).thenAnswer(
      (inv) => mockSource
          .getTasks()
          .where((t) => t.id == inv.positionalArguments.first)
          .firstOrNull,
    );
    when(() => mockSource.getCategory(any())).thenAnswer(
      (inv) => mockSource
          .getCategories()
          .where((c) => c.id == inv.positionalArguments.first)
          .firstOrNull,
    );
    when(() => mockNotificationService.init()).thenAnswer((_) async => {});
    when(
      () => mockNotificationService.requestPermissions(),
    ).thenAnswer((_) async => true);
    when(
      () => mockNotificationService.cancelAllNotifications(),
    ).thenAnswer((_) async => {});
    when(
      () => mockNotificationService.cancelNotification(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockNotificationService.scheduleNotification(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        taskId: any(named: 'taskId'),
        androidActions: any(named: 'androidActions'),
      ),
    ).thenAnswer((_) async => {});
    when(
      () => mockNotificationService.showInfoNotification(
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => {});
    when(
      () => mockNotificationService.onNotificationResponse,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockSource.clearAll()).thenAnswer((_) async => {});
    when(() => mockSource.updateTask(any())).thenAnswer((_) async => {});
    when(
      () => mockFirestoreService.processOfflineQueue(),
    ).thenAnswer((_) async => {});
    when(() => mockConnectivityService.init()).thenAnswer((_) async => {});
    when(() => mockConnectivityService.isOnline).thenReturn(true);
    when(
      () => mockAuthService.authStateChanges,
    ).thenAnswer((_) => Stream.value(null));
    when(() => mockAuthService.currentUser).thenReturn(null);
    when(
      () => mockAuthService.getGoogleAccessToken(),
    ).thenAnswer((_) async => null);
    when(
      () => mockErrorHandlingService.logError(
        any(),
        any(),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async => {});
    when(() => mockThemeService.init()).thenAnswer((_) async => {});
    when(() => mockThemeService.isDarkMode).thenReturn(false);
    when(() => mockSubscriptionService.init()).thenAnswer((_) async => {});
    when(() => mockSubscriptionService.isPremium).thenReturn(true);
    when(
      () => mockAnalyticsService.logTaskCreated(
        categoryId: any(named: 'categoryId'),
        hasDueDate: any(named: 'hasDueDate'),
      ),
    ).thenAnswer((_) async => {});
    when(
      () => mockAnalyticsService.logTaskCompleted(),
    ).thenAnswer((_) async => {});

    taskProvider = TaskProvider(
      mockAuthService,
      mockCalendarService,
      mockGoogleTasksService,
      mockThemeService,
      mockErrorHandlingService,
      mockSubscriptionService,
      source: mockSource,
      notificationService: mockNotificationService,
      firestoreService: mockFirestoreService,
      connectivityService: mockConnectivityService,
      analyticsService: mockAnalyticsService,
    );
  });

  group('TaskProvider Sorting', () {
    test('tasks are sorted by due date by default', () async {
      final now = DateTime.now();
      final task1 = Task(
        id: '1',
        title: 'Later Task',
        dueDate: now.add(const Duration(days: 1)),
      );
      final task2 = Task(id: '2', title: 'Earlier Task', dueDate: now);

      when(() => mockSource.getTasks()).thenReturn([task1, task2]);

      // Initialize to trigger data loading
      await taskProvider.init();

      expect(taskProvider.tasks.length, 2);
      expect(taskProvider.tasks[0].id, '2'); // Earlier task first
      expect(taskProvider.tasks[1].id, '1');
    });

    test('pinned tasks appear first regardless of due date', () async {
      final now = DateTime.now();
      final task1 = Task(
        id: '1',
        title: 'Later Pinned',
        dueDate: now.add(const Duration(days: 1)),
        isPinned: true,
      );
      final task2 = Task(
        id: '2',
        title: 'Earlier Unpinned',
        dueDate: now,
        isPinned: false,
      );

      when(() => mockSource.getTasks()).thenReturn([task1, task2]);

      await taskProvider.init();

      expect(taskProvider.tasks[0].id, '1'); // Pinned first
      expect(taskProvider.tasks[1].id, '2');
    });
  });

  group('TaskProvider Completed Prefetch', () {
    test(
      'fetches completed tasks after login when showCompleted is enabled',
      () async {
        final user = MockUser();
        when(() => user.uid).thenReturn('u1');

        when(
          () => mockAuthService.authStateChanges,
        ).thenAnswer((_) => Stream.value(user));
        when(() => mockAuthService.currentUser).thenReturn(user);

        when(() => mockFirestoreService.setUserId(any())).thenReturn(null);
        when(
          () => mockFirestoreService.getActiveTasksStream(),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => mockFirestoreService.getCategoriesStream(),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => mockFirestoreService.addTask(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockFirestoreService.addCategory(any()),
        ).thenAnswer((_) async => {});

        final completedTask = Task(
          id: 'c1',
          title: 'Completed',
          isCompleted: true,
        );
        when(
          () => mockFirestoreService.getNextCompletedTasksBatch(),
        ).thenAnswer((_) async => [completedTask]);
        when(() => mockSource.addTask(any())).thenAnswer((_) async => {});

        await taskProvider.init();

        await untilCalled(
          () => mockFirestoreService.getNextCompletedTasksBatch(),
        );
        verify(() => mockSource.addTask(completedTask)).called(1);
      },
    );
  });

  group('TaskProvider Recurring Tasks', () {
    test('spawns next recurring task when completed by premium user', () async {
      when(() => mockSubscriptionService.isPremium).thenReturn(true);
      when(() => mockSource.addTask(any())).thenAnswer((_) async => {});
      when(
        () => mockFirestoreService.updateTask(any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockFirestoreService.addTask(any()),
      ).thenAnswer((_) async => {});

      await taskProvider.init();

      final recurringTask = Task(
        id: 'rec-1',
        title: 'Daily Standup',
        isCompleted: false,
        dueDate: DateTime(2026, 8, 15, 9, 0),
        recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
      );

      await taskProvider.toggleTaskCompletion(recurringTask);

      expect(recurringTask.isCompleted, isTrue);
      expect(recurringTask.nextRecurrenceDate, isNotNull);
      // Verify adding the completed task
      final capturedTasks = verify(
        () => mockSource.addTask(captureAny()),
      ).captured;
      expect(capturedTasks.length, 1);

      // Materialize the recurring iteration
      when(() => mockSource.getTasks()).thenReturn([recurringTask]);
      final now = DateTime.now();
      recurringTask.nextRecurrenceDate = DateTime(
        now.year,
        now.month,
        now.day,
        9,
        0,
      );
      await taskProvider.checkAndMaterializeDueRecurringTasks();

      final allCaptured = verify(
        () => mockSource.addTask(captureAny()),
      ).captured;
      final nextTask = allCaptured.last as Task;
      expect(nextTask.title, 'Daily Standup');
      expect(nextTask.isCompleted, isFalse);
      expect(nextTask.recurrenceRule, 'FREQ=DAILY;INTERVAL=1');
      expect(nextTask.recurringParentId, 'rec-1');
      expect(nextTask.dueDate!.hour, 9);
      expect(nextTask.dueDate!.minute, 0);
    });

    test(
      'defers next recurring task when completed early, and materializes when due date arrives',
      () async {
        when(() => mockSubscriptionService.isPremium).thenReturn(true);
        when(() => mockSource.addTask(any())).thenAnswer((_) async => {});
        when(
          () => mockFirestoreService.updateTask(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockFirestoreService.addTask(any()),
        ).thenAnswer((_) async => {});

        await taskProvider.init();

        final futureDue = DateTime.now().add(const Duration(days: 3));
        final recurringTask = Task(
          id: 'rec-future',
          title: 'Future Task',
          isCompleted: false,
          dueDate: DateTime(
            futureDue.year,
            futureDue.month,
            futureDue.day,
            10,
            0,
          ),
          recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
        );

        when(() => mockSource.getTasks()).thenReturn([recurringTask]);

        await taskProvider.toggleTaskCompletion(recurringTask);

        expect(recurringTask.isCompleted, isTrue);
        // Only the completed task should be updated/added directly, NOT a second pending task
        final capturedTasks = verify(
          () => mockSource.addTask(captureAny()),
        ).captured;
        expect(capturedTasks.length, 1);
        expect((capturedTasks.first as Task).id, 'rec-future');
        expect(recurringTask.nextRecurrenceDate, isNotNull);

        // Upcoming recurring tasks projection contains preview
        final upcoming = taskProvider.upcomingRecurringTasks;
        expect(upcoming.length, 1);
        expect(upcoming.first.id, 'preview_rec-future');

        // Now simulate the scheduled date arriving (or being in past):
        recurringTask.nextRecurrenceDate = DateTime.now();
        await taskProvider.checkAndMaterializeDueRecurringTasks();

        // The deferred task has now materialized and been added
        final afterMaterializeTasks = verify(
          () => mockSource.addTask(captureAny()),
        ).captured;
        expect(afterMaterializeTasks.length, 1);
        final spawnedTask = afterMaterializeTasks.first as Task;
        expect(spawnedTask.recurringParentId, 'rec-future');
        expect(spawnedTask.title, 'Future Task');
        expect(spawnedTask.isCompleted, isFalse);
      },
    );

    test(
      'completing overdue recurring task defers next iteration to future and does not spawn active task today',
      () async {
        when(() => mockSubscriptionService.isPremium).thenReturn(true);
        when(() => mockSource.addTask(any())).thenAnswer((_) async => {});
        when(
          () => mockFirestoreService.updateTask(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockFirestoreService.addTask(any()),
        ).thenAnswer((_) async => {});

        await taskProvider.init();

        // Due 3 days ago at 18:00
        final overdueDate = DateTime.now().subtract(const Duration(days: 3));
        final overdueTask = Task(
          id: 'rec-overdue',
          title: 'Overdue Daily Task',
          isCompleted: false,
          dueDate: DateTime(
            overdueDate.year,
            overdueDate.month,
            overdueDate.day,
            18,
            0,
          ),
          recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
        );

        when(() => mockSource.getTasks()).thenReturn([overdueTask]);

        await taskProvider.toggleTaskCompletion(overdueTask);

        expect(overdueTask.isCompleted, isTrue);
        // Only the completed task should be updated, NOT a duplicate uncompleted task for today
        final capturedTasks = verify(
          () => mockSource.addTask(captureAny()),
        ).captured;
        expect(capturedTasks.length, 1);
        expect((capturedTasks.first as Task).id, 'rec-overdue');
        expect(overdueTask.nextRecurrenceDate, isNotNull);

        // Next recurrence must strictly be tomorrow or later, never today
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final nextDay = DateTime(
          overdueTask.nextRecurrenceDate!.year,
          overdueTask.nextRecurrenceDate!.month,
          overdueTask.nextRecurrenceDate!.day,
        );
        expect(nextDay.isAfter(today), isTrue);
        expect(overdueTask.nextRecurrenceDate!.hour, 18);
        expect(overdueTask.nextRecurrenceDate!.minute, 0);

        // Upcoming recurring tasks projection contains preview for tomorrow
        final upcoming = taskProvider.upcomingRecurringTasks;
        expect(upcoming.length, 1);
        expect(upcoming.first.id, 'preview_rec-overdue');
      },
    );

    test(
      'un-completing deferred recurring task clears nextRecurrenceDate and cancels notification',
      () async {
        when(() => mockSubscriptionService.isPremium).thenReturn(true);
        when(() => mockSource.addTask(any())).thenAnswer((_) async => {});
        when(
          () => mockFirestoreService.updateTask(any()),
        ).thenAnswer((_) async => {});

        final deferredParent = Task(
          id: 'rec-deferred',
          title: 'Deferred Daily',
          isCompleted: true,
          recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
          nextRecurrenceDate: DateTime.now().add(const Duration(days: 1)),
        );

        when(() => mockSource.getTasks()).thenReturn([deferredParent]);

        await taskProvider.init();

        await taskProvider.toggleTaskCompletion(deferredParent);

        expect(deferredParent.isCompleted, isFalse);
        expect(deferredParent.nextRecurrenceDate, isNull);
        verify(
          () => mockNotificationService.cancelNotification(
            NotificationService.getNotificationId('preview_rec-deferred'),
          ),
        ).called(1);
      },
    );

    test(
      'un-completing recurring task automatically deletes the spawned recurring child task',
      () async {
        when(() => mockSubscriptionService.isPremium).thenReturn(true);
        when(() => mockSource.addTask(any())).thenAnswer((_) async => {});
        when(() => mockSource.deleteTask(any())).thenAnswer((_) async => {});
        when(
          () => mockFirestoreService.updateTask(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockFirestoreService.deleteTask(any()),
        ).thenAnswer((_) async => {});
        when(
          () => mockAnalyticsService.logTaskDeleted(),
        ).thenAnswer((_) async => {});

        final parentTask = Task(
          id: 'rec-parent',
          title: 'Weekly Sync',
          isCompleted: true,
          recurrenceRule: 'FREQ=WEEKLY;INTERVAL=1',
        );

        final spawnedChild = Task(
          id: 'rec-child',
          title: 'Weekly Sync',
          isCompleted: false,
          recurrenceRule: 'FREQ=WEEKLY;INTERVAL=1',
          recurringParentId: 'rec-parent',
        );

        when(
          () => mockSource.getTasks(),
        ).thenReturn([parentTask, spawnedChild]);

        await taskProvider.init();

        // Un-complete the parent task
        await taskProvider.toggleTaskCompletion(parentTask);

        expect(parentTask.isCompleted, isFalse);
        verify(() => mockSource.deleteTask('rec-child')).called(1);
        verify(() => mockFirestoreService.deleteTask('rec-child')).called(1);
      },
    );

    test(
      'bulk reschedule restores the reminder for a deferred iteration',
      () async {
        await taskProvider.init();
        final next = DateTime.now().add(const Duration(days: 2));
        final parent = Task(
          id: 'rec-3',
          title: 'Water plants',
          isCompleted: true,
          dueDate: next.subtract(const Duration(days: 1)),
          recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
        )..nextRecurrenceDate = next;
        when(() => mockSource.getTasks()).thenReturn([parent]);

        await taskProvider.rescheduleAllTaskNotifications(cancelExisting: true);

        verify(
          () => mockNotificationService.scheduleNotification(
            id: NotificationService.getNotificationId('preview_rec-3'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: next,
            taskId: 'preview_rec-3',
            androidActions: any(named: 'androidActions'),
          ),
        ).called(1);
      },
    );

    test(
      'does not spawn next recurring task when user is not premium',
      () async {
        when(() => mockSubscriptionService.isPremium).thenReturn(false);
        when(() => mockSource.addTask(any())).thenAnswer((_) async => {});
        when(
          () => mockFirestoreService.updateTask(any()),
        ).thenAnswer((_) async => {});

        await taskProvider.init();

        final recurringTask = Task(
          id: 'rec-2',
          title: 'Daily Standup Free',
          isCompleted: false,
          dueDate: DateTime(2026, 8, 15, 9, 0),
          recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
        );

        await taskProvider.toggleTaskCompletion(recurringTask);

        expect(recurringTask.isCompleted, isTrue);
        // Only the completed task should be saved
        final capturedTasks = verify(
          () => mockSource.addTask(captureAny()),
        ).captured;
        expect(capturedTasks.length, 1);
        expect((capturedTasks.first as Task).id, 'rec-2');
      },
    );
  });

  group('TaskProvider list & lookups', () {
    test('exposes every matching task (no silent 50-item cap)', () async {
      final many = List.generate(120, (i) => Task(id: 't$i', title: 'Task $i'));
      when(() => mockSource.getTasks()).thenReturn(many);

      await taskProvider.init();

      expect(taskProvider.tasks.length, 120);
      expect(taskProvider.totalTaskCount, 120);
    });

    test('unknown category id returns null without logging an error', () async {
      await taskProvider.init();
      clearInteractions(mockErrorHandlingService);

      expect(taskProvider.getCategoryById('missing'), isNull);
      verifyNever(
        () => mockErrorHandlingService.logError(
          any(),
          any(),
          reason: any(named: 'reason'),
        ),
      );
    });

    test('deleteTask removes the task from the list', () async {
      final task = Task(id: 'd1', title: 'Swipe me');
      when(() => mockSource.getTasks()).thenReturn([task]);
      when(() => mockSource.addTask(any())).thenAnswer((_) async {});
      when(
        () => mockFirestoreService.updateTask(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockAnalyticsService.logTaskDeleted(),
      ).thenAnswer((_) async {});

      await taskProvider.init();
      expect(taskProvider.tasks.map((t) => t.id), ['d1']);

      await taskProvider.deleteTask('d1');

      expect(taskProvider.tasks, isEmpty);
      expect(taskProvider.deletedTasks.map((t) => t.id), ['d1']);
    });
  });

  group('TaskProvider premium resolution', () {
    test(
      'materializes due recurring tasks once premium resolves after init',
      () async {
        var premium = false;
        when(
          () => mockSubscriptionService.isPremium,
        ).thenAnswer((_) => premium);
        when(() => mockSource.addTask(any())).thenAnswer((_) async {});
        when(
          () => mockFirestoreService.updateTask(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockFirestoreService.addTask(any()),
        ).thenAnswer((_) async {});

        final now = DateTime.now();
        final parent = Task(
          id: 'rec-cold',
          title: 'Cold start daily',
          isCompleted: true,
          recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
          nextRecurrenceDate: DateTime(now.year, now.month, now.day, 9),
        );
        when(() => mockSource.getTasks()).thenReturn([parent]);

        await taskProvider.init();
        verifyNever(() => mockSource.addTask(any()));

        final listener =
            verify(
                  () => mockSubscriptionService.addListener(captureAny()),
                ).captured.last
                as VoidCallback;
        premium = true;
        listener();
        await pumpEventQueue();

        final added = verify(
          () => mockSource.addTask(captureAny()),
        ).captured.cast<Task>();
        expect(added.where((t) => t.recurringParentId == 'rec-cold').length, 1);
        expect(parent.nextRecurrenceDate, isNull);
      },
    );
  });

  group('TaskProvider required subtasks', () {
    test('blocks completing a task while required subtasks are open', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      when(() => mockSource.addTask(any())).thenAnswer((_) async => {});
      await taskProvider.init();
      final task = Task(
        id: 'req-1',
        title: 'Pack',
        subTasks: [
          SubTask(title: 'Clothes', isCompleted: true),
          SubTask(title: 'Charger'),
        ],
        requireSubTasksBeforeReminders: true,
      );

      final completed = await taskProvider.toggleTaskCompletion(task);

      expect(completed, isFalse);
      expect(task.isCompleted, isFalse);
      verifyNever(() => mockSource.addTask(any()));
    });

    test('completes once every required subtask is done', () async {
      when(() => mockSource.addTask(any())).thenAnswer((_) async => {});
      when(
        () => mockFirestoreService.updateTask(any()),
      ).thenAnswer((_) async => {});
      await taskProvider.init();
      final task = Task(
        id: 'req-2',
        title: 'Pack',
        subTasks: [SubTask(title: 'Charger', isCompleted: true)],
        requireSubTasksBeforeReminders: true,
      );

      final completed = await taskProvider.toggleTaskCompletion(task);

      expect(completed, isTrue);
      expect(task.isCompleted, isTrue);
    });
  });
}
