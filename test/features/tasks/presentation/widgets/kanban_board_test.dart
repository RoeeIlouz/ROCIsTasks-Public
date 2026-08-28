import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/kanban/kanban_board_view.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/kanban/kanban_column.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/shared/ui/theme/app_theme.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/security_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class MockTaskProvider extends Mock implements TaskProvider {}
class MockThemeService extends Mock implements ThemeService {}
class MockSubscriptionService extends Mock implements SubscriptionService {}
class MockPrivateModeService extends Mock implements PrivateModeService {}
class FakeTask extends Fake implements Task {}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() {
    registerFallbackValue(FakeTask());
  });

  late MockTaskProvider mockTaskProvider;
  late MockThemeService mockThemeService;
  late MockSubscriptionService mockSubscriptionService;
  late MockPrivateModeService mockPrivateModeService;

  final sampleCategory = Category(
    id: 'cat-1',
    name: 'Work',
    colorValue: 0xFF2196F3,
    iconCode: 0,
  );

  final sampleTodoTask = Task(
    id: 'task-1',
    title: 'Future Backlog Task',
    description: 'Some details',
    priority: TaskPriority.low,
    categoryId: 'cat-1',
    categoryIds: ['cat-1'],
    dueDate: DateTime.now().add(const Duration(days: 5)),
  );

  final sampleInFocusTask = Task(
    id: 'task-2',
    title: 'Today Task',
    priority: TaskPriority.high,
    categoryId: 'cat-1',
    categoryIds: ['cat-1'],
    dueDate: DateTime.now(),
  );

  final sampleDoneTask = Task(
    id: 'task-3',
    title: 'Done Task',
    priority: TaskPriority.medium,
    isCompleted: true,
  );

  setUp(() {
    mockTaskProvider = MockTaskProvider();
    mockThemeService = MockThemeService();
    mockSubscriptionService = MockSubscriptionService();
    mockPrivateModeService = MockPrivateModeService();

    when(() => mockTaskProvider.tasks).thenReturn([
      sampleTodoTask,
      sampleInFocusTask,
      sampleDoneTask,
    ]);
    when(() => mockTaskProvider.categories).thenReturn([sampleCategory]);
    when(() => mockTaskProvider.getCategoryById('cat-1')).thenReturn(sampleCategory);
    when(() => mockTaskProvider.getCategoryById(any(that: isNot('cat-1')))).thenReturn(null);
    when(() => mockTaskProvider.isLoading).thenReturn(false);
    when(() => mockTaskProvider.errorMessage).thenReturn(null);
    when(() => mockTaskProvider.toggleTaskCompletion(any())).thenAnswer((_) async {});
    when(() => mockTaskProvider.updateTask(any())).thenAnswer((_) async {});

    when(() => mockThemeService.useGlassmorphism).thenReturn(true);
    when(() => mockThemeService.useMaterialTheme).thenReturn(false);
    when(() => mockThemeService.useCustomSeedColor).thenReturn(false);
    when(() => mockThemeService.customSeedColorValue).thenReturn(null);

    when(() => mockSubscriptionService.isPremium).thenReturn(true);
    when(() => mockPrivateModeService.hasPin).thenReturn(false);
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskProvider>.value(value: mockTaskProvider),
        ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
        ChangeNotifierProvider<SubscriptionService>.value(value: mockSubscriptionService),
        ChangeNotifierProvider<PrivateModeService>.value(value: mockPrivateModeService),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: KanbanBoardView(),
        ),
      ),
    );
  }

  testWidgets('renders KanbanBoardView with Status columns (To Do, In Focus, Done)', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(KanbanBoardView), findsOneWidget);
    expect(find.byType(KanbanColumn), findsNWidgets(3));
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('In Focus'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    expect(find.text('Future Backlog Task'), findsOneWidget);
    expect(find.text('Today Task'), findsOneWidget);
    expect(find.text('Done Task'), findsOneWidget);
  });

  testWidgets('switches grouping mode to Priority and shows High, Medium, Low columns', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap Priority grouping chip
    final priorityChip = find.text('Priority');
    expect(priorityChip, findsOneWidget);
    await tester.tap(priorityChip);
    await tester.pumpAndSettle();

    expect(find.text('High Priority'), findsOneWidget);
    expect(find.text('Medium Priority'), findsOneWidget);
    expect(find.text('Low Priority'), findsOneWidget);
  });

  testWidgets('switches grouping mode to Category and shows Category columns', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap Category grouping chip
    final categoryChip = find.text('Category');
    expect(categoryChip, findsOneWidget);
    await tester.tap(categoryChip);
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsAtLeastNWidgets(1));
    expect(find.text('Uncategorized'), findsOneWidget);
  });

  testWidgets('toggling checkmark on KanbanCard toggles task completion', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Find the check icon in Done Task and tap it
    final doneCheck = find.byIcon(Icons.check);
    expect(doneCheck, findsOneWidget);

    await tester.tap(doneCheck);
    await tester.pumpAndSettle();

    verify(() => mockTaskProvider.toggleTaskCompletion(sampleDoneTask)).called(1);
  });
}
