import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rocis_tasks/features/tasks/presentation/screens/add_task_screen.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class MockTaskProvider extends Mock implements TaskProvider {}

class MockThemeService extends Mock implements ThemeService {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockTaskProvider mockTaskProvider;
  late MockThemeService mockThemeService;
  late MockSubscriptionService mockSubscriptionService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockTaskProvider = MockTaskProvider();
    mockThemeService = MockThemeService();
    mockSubscriptionService = MockSubscriptionService();
    mockAuthService = MockAuthService();

    when(() => mockThemeService.use24HourFormat).thenReturn(true);
    when(() => mockThemeService.isDarkMode).thenReturn(false);
    when(() => mockThemeService.useGlassmorphism).thenReturn(true);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockSubscriptionService.isPremium).thenReturn(true);
    when(() => mockTaskProvider.categories).thenReturn([
      Category(
        id: 'cat_1',
        name: 'General',
        colorValue: 0xFF2196F3,
        iconCode: 1,
      ),
    ]);
  });

  Widget createWidgetUnderTest({Task? task}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskProvider>.value(value: mockTaskProvider),
        ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
        ChangeNotifierProvider<SubscriptionService>.value(
          value: mockSubscriptionService,
        ),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', '')],
        home: AddTaskScreen(task: task),
      ),
    );
  }

  testWidgets(
    'New Task screen renders primary fields and More Options collapsed by default',
    (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('New Task'), findsOneWidget);
      expect(find.text('Due Date & Time'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('More Options'), findsOneWidget);

      // Advanced fields should NOT be visible when collapsed
      expect(find.text('Sync with Google Tasks'), findsNothing);
      expect(find.text('Do not remind'), findsNothing);
    },
  );

  testWidgets('Tapping More Options expands advanced options', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final moreOptionsBtn = find.text('More Options');
    await tester.ensureVisible(moreOptionsBtn);
    await tester.tap(moreOptionsBtn);
    await tester.pumpAndSettle();

    expect(find.text('Fewer Options'), findsOneWidget);
    expect(find.text('Sync with Google Tasks'), findsOneWidget);
    expect(find.text('Do not remind'), findsOneWidget);
  });

  testWidgets('Editing task with existing subtasks auto-expands More Options', (
    tester,
  ) async {
    final task = Task(
      id: 'task_1',
      title: 'Detailed Task',
      subTasks: [SubTask(id: 'st_1', title: 'Subtask 1')],
    );

    await tester.pumpWidget(createWidgetUnderTest(task: task));
    await tester.pumpAndSettle();

    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Fewer Options'), findsOneWidget);
    expect(find.text('Sync with Google Tasks'), findsOneWidget);
  });
}
