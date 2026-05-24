import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
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
    mockThemeService = MockThemeService();
    mockErrorHandlingService = MockErrorHandlingService();
    mockSubscriptionService = MockSubscriptionService();
    mockAnalyticsService = MockAnalyticsService();

    // Default stubs
    when(() => mockSource.init()).thenAnswer((_) async => {});
    when(() => mockSource.getTasks()).thenReturn([]);
    when(() => mockSource.getCategories()).thenReturn([]);
    when(() => mockNotificationService.init()).thenAnswer((_) async => {});
    when(
      () => mockNotificationService.requestPermissions(),
    ).thenAnswer((_) async => true);
    when(
      () => mockNotificationService.cancelAllNotifications(),
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
    when(() => mockConnectivityService.init()).thenAnswer((_) async => {});
    when(() => mockConnectivityService.isOnline).thenReturn(true);
    when(
      () => mockAuthService.authStateChanges,
    ).thenAnswer((_) => Stream.value(null));
    when(() => mockAuthService.currentUser).thenReturn(null);
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

    taskProvider = TaskProvider(
      mockAuthService,
      mockCalendarService,
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
    test('fetches completed tasks after login when showCompleted is enabled', () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('u1');

      when(() => mockAuthService.authStateChanges).thenAnswer(
        (_) => Stream.value(user),
      );
      when(() => mockAuthService.currentUser).thenReturn(user);

      when(() => mockFirestoreService.setUserId(any())).thenReturn(null);
      when(() => mockFirestoreService.getActiveTasksStream()).thenAnswer(
        (_) => const Stream.empty(),
      );
      when(() => mockFirestoreService.getCategoriesStream()).thenAnswer(
        (_) => const Stream.empty(),
      );
      when(() => mockFirestoreService.addTask(any())).thenAnswer((_) async => {});
      when(() => mockFirestoreService.addCategory(any())).thenAnswer((_) async => {});

      final completedTask = Task(
        id: 'c1',
        title: 'Completed',
        isCompleted: true,
      );
      when(() => mockFirestoreService.getNextCompletedTasksBatch()).thenAnswer(
        (_) async => [completedTask],
      );
      when(() => mockSource.addTask(any())).thenAnswer((_) async => {});

      await taskProvider.init();

      await untilCalled(() => mockFirestoreService.getNextCompletedTasksBatch());
      verify(() => mockSource.addTask(completedTask)).called(1);
    });
  });
}
