import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/import_task_preview_sheet.dart';
import 'package:rocis_tasks/features/tasks/services/task_share_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';

class MockTaskProvider extends Mock implements TaskProvider {}

class MockThemeService extends Mock implements ThemeService {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() {
    registerFallbackValue(TaskPriority.medium);
  });

  late MockTaskProvider mockTaskProvider;
  late MockThemeService mockThemeService;
  late MockSubscriptionService mockSubscriptionService;

  setUp(() {
    mockTaskProvider = MockTaskProvider();
    mockThemeService = MockThemeService();
    mockSubscriptionService = MockSubscriptionService();

    when(() => mockThemeService.useGlassmorphism).thenReturn(false);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockSubscriptionService.isPremium).thenReturn(true);

    when(() => mockTaskProvider.categories).thenReturn([
      Category(
        id: 'cat-1',
        name: 'Work',
        colorValue: 0xFF2196F3,
        iconCode: 58835,
      ),
    ]);

    when(
      () => mockTaskProvider.addTask(
        any(),
        any(),
        any(),
        any(),
        any(),
        categoryIds: any(named: 'categoryIds'),
        subTasks: any(named: 'subTasks'),
        recurrenceRule: any(named: 'recurrenceRule'),
        customFields: any(named: 'customFields'),
        isGroceryList: any(named: 'isGroceryList'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildTestWidget(TaskShareData shareData) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskProvider>.value(value: mockTaskProvider),
        ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
        ChangeNotifierProvider<SubscriptionService>.value(
          value: mockSubscriptionService,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(body: ImportTaskPreviewSheet(shareData: shareData)),
      ),
    );
  }

  testWidgets('renders ImportTaskPreviewSheet with task data and subtasks', (
    tester,
  ) async {
    final task = Task(
      title: 'Imported Marketing Plan',
      description: 'Prepare campaign materials',
      priority: TaskPriority.high,
      subTasks: [
        SubTask(title: 'Review copy', isCompleted: false),
        SubTask(title: 'Export banners', isCompleted: false),
      ],
    );

    final shareData = TaskShareData(
      task: task,
      suggestedCategoryName: 'Marketing',
      isCloud: false,
    );

    await tester.pumpWidget(buildTestWidget(shareData));
    await tester.pumpAndSettle();

    expect(find.text('Import Task Preview'), findsOneWidget);
    expect(find.text('Imported Marketing Plan'), findsOneWidget);
    expect(find.text('Prepare campaign materials'), findsOneWidget);
    expect(find.text('Subtasks (2)'), findsOneWidget);
    expect(find.text('Review copy'), findsOneWidget);
    expect(find.text('Export banners'), findsOneWidget);
    expect(find.text('Suggested category: Marketing'), findsOneWidget);

    // Tap Import Task button
    final importButton = find.widgetWithText(FilledButton, 'Import Task');
    expect(importButton, findsOneWidget);
    await tester.tap(importButton);
    await tester.pumpAndSettle();

    verify(
      () => mockTaskProvider.addTask(
        'Imported Marketing Plan',
        'Prepare campaign materials',
        any(),
        TaskPriority.high,
        any(),
        categoryIds: any(named: 'categoryIds'),
        subTasks: any(named: 'subTasks'),
        recurrenceRule: any(named: 'recurrenceRule'),
        customFields: any(named: 'customFields'),
        isGroceryList: any(named: 'isGroceryList'),
      ),
    ).called(1);
  });
}
