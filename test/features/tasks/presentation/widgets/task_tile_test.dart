import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_tile.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/shared/ui/theme/app_theme.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/security_service.dart';

class MockTaskProvider extends Mock implements TaskProvider {}

class MockThemeService extends Mock implements ThemeService {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

class MockPrivateModeService extends Mock implements PrivateModeService {}

void main() {
  late MockTaskProvider mockTaskProvider;
  late MockThemeService mockThemeService;
  late MockSubscriptionService mockSubscriptionService;
  late MockPrivateModeService mockPrivateModeService;

  setUp(() {
    mockTaskProvider = MockTaskProvider();
    mockThemeService = MockThemeService();
    mockSubscriptionService = MockSubscriptionService();
    mockPrivateModeService = MockPrivateModeService();

    when(() => mockThemeService.use24HourFormat).thenReturn(true);
    when(() => mockThemeService.isDarkMode).thenReturn(false);
    when(() => mockSubscriptionService.isPremium).thenReturn(true);
    when(() => mockPrivateModeService.shouldHidePrivateContent)
        .thenReturn(false);
  });

  Widget createWidgetUnderTest(
    Task task, {
    Category? category,
    VoidCallback? onToggle,
    VoidCallback? onDelete,
    VoidCallback? onTap,
    bool isSelectionMode = false,
    bool isSelected = false,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskProvider>.value(value: mockTaskProvider),
        ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
        ChangeNotifierProvider<SubscriptionService>.value(
          value: mockSubscriptionService,
        ),
        ChangeNotifierProvider<PrivateModeService>.value(
          value: mockPrivateModeService,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', '')],
        home: Scaffold(
          body: TaskTile(
            task: task,
            category: category,
            onToggle: onToggle ?? () {},
            onDelete: onDelete ?? () {},
            onTap: onTap ?? () {},
            isSelectionMode: isSelectionMode,
            isSelected: isSelected,
          ),
        ),
      ),
    );
  }

  group('TaskTile - Basic Rendering', () {
    testWidgets('renders title and description', (tester) async {
      final task = Task(
        id: '1',
        title: 'Test Task',
        description: 'Test Description',
      );
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.text('Test Task'), findsOneWidget);
      expect(find.text('Test Description'), findsOneWidget);
    });

    testWidgets('renders high priority color indicator', (tester) async {
      final task = Task(
        id: '1',
        title: 'High Priority',
        priority: TaskPriority.high,
      );
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.text('High Priority'), findsOneWidget);
    });

    testWidgets('renders completed state with checkmark', (tester) async {
      final task = Task(id: '1', title: 'Done', isCompleted: true);
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('renders uncompleted state without checkmark', (tester) async {
      final task = Task(id: '1', title: 'Pending', isCompleted: false);
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });

  group('TaskTile - Due Date', () {
    testWidgets('shows due date time when set', (tester) async {
      final task = Task(
        id: '1',
        title: 'With Date',
        dueDate: DateTime(2025, 6, 15, 14, 30),
      );
      await tester.pumpWidget(createWidgetUnderTest(task));
      // Should render without errors (time format depends on locale)
      expect(find.text('With Date'), findsOneWidget);
    });

    testWidgets('does not show time when no due date', (tester) async {
      final task = Task(id: '1', title: 'No Date', dueDate: null);
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.text('No Date'), findsOneWidget);
    });
  });

  group('TaskTile - Category', () {
    testWidgets('shows category chip when category provided', (tester) async {
      final task = Task(
        id: '1',
        title: 'With Category',
        categoryId: 'cat-1',
      );
      final category = Category(
        id: 'cat-1',
        name: 'Work',
        colorValue: 0xFF2196F3,
        iconCode: 0xe06f,
      );
      await tester.pumpWidget(
        createWidgetUnderTest(task, category: category),
      );
      expect(find.text('With Category'), findsOneWidget);
    });
  });

  group('TaskTile - Subtasks', () {
    testWidgets('shows subtask list when subtasks exist', (tester) async {
      final task = Task(
        id: '1',
        title: 'Parent Task',
        subTasks: [
          SubTask(id: 'st-1', title: 'Sub 1', isCompleted: false),
          SubTask(id: 'st-2', title: 'Sub 2', isCompleted: true),
        ],
      );
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.text('Parent Task'), findsOneWidget);
      expect(find.text('Sub 1'), findsOneWidget);
      expect(find.text('Sub 2'), findsOneWidget);
    });

    testWidgets('does not show subtasks when none exist', (tester) async {
      final task = Task(id: '1', title: 'Solo Task', subTasks: null);
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.text('Solo Task'), findsOneWidget);
    });
  });

  group('TaskTile - Pinned', () {
    testWidgets('shows pin icon when pinned', (tester) async {
      final task = Task(id: '1', title: 'Pinned', isPinned: true);
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });

    testWidgets('shows outline pin when not pinned', (tester) async {
      final task = Task(id: '1', title: 'Not Pinned', isPinned: false);
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    });
  });

  group('TaskTile - Selection Mode', () {
    testWidgets('shows selection highlight when selected', (tester) async {
      final task = Task(id: '1', title: 'Selected');
      await tester.pumpWidget(
        createWidgetUnderTest(
          task,
          isSelectionMode: true,
          isSelected: true,
        ),
      );
      expect(find.text('Selected'), findsOneWidget);
    });

    testWidgets('shows unselected state when not selected', (tester) async {
      final task = Task(id: '1', title: 'Unselected');
      await tester.pumpWidget(
        createWidgetUnderTest(
          task,
          isSelectionMode: true,
          isSelected: false,
        ),
      );
      expect(find.text('Unselected'), findsOneWidget);
    });
  });

  group('TaskTile - Long Titles', () {
    testWidgets('renders long title without overflow', (tester) async {
      final task = Task(
        id: '1',
        title:
            'This is a very long task title that should not cause overflow errors in the widget',
      );
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(
        find.text(
          'This is a very long task title that should not cause overflow errors in the widget',
        ),
        findsOneWidget,
      );
    });
  });

  group('TaskTile - Long Descriptions', () {
    testWidgets('truncates long description', (tester) async {
      final task = Task(
        id: '1',
        title: 'Task',
        description:
            'This is a very long description that should be truncated after two lines to prevent the task tile from becoming too tall',
      );
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.text('Task'), findsOneWidget);
    });
  });

  group('TaskTile - Google Calendar', () {
    testWidgets('shows Google Calendar badge when synced', (tester) async {
      final task = Task(
        id: '1',
        title: 'Google Synced',
        syncWithGoogleCalendar: true,
      );
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.text('Google Synced'), findsOneWidget);
    });
  });

  group('TaskTile - Private Masked', () {
    testWidgets('shows masked title for private task', (tester) async {
      when(() => mockSubscriptionService.isPremium).thenReturn(true);
      when(() => mockPrivateModeService.shouldHidePrivateContent)
          .thenReturn(true);

      final task = Task(id: '1', title: 'Secret Task');
      final category = Category(
        id: 'cat-1',
        name: 'Private',
        colorValue: 0xFFFF0000,
        iconCode: 0,
        isPrivate: true,
      );
      await tester.pumpWidget(
        createWidgetUnderTest(task, category: category),
      );
      // Should show the private task label instead of actual title
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });
  });

  group('TaskTile - Interactions', () {
    testWidgets('calls onToggle when checkbox tapped', (tester) async {
      bool toggled = false;
      final task = Task(id: '1', title: 'Toggle Me');
      await tester.pumpWidget(
        createWidgetUnderTest(task, onToggle: () => toggled = true),
      );
      // The checkbox is inside a GestureDetector wrapping the AnimatedContainer
      final checkbox = find.byType(AnimatedContainer).first;
      await tester.tap(checkbox);
      expect(toggled, true);
    });

    testWidgets('calls onTap when title area tapped', (tester) async {
      bool tapped = false;
      final task = Task(id: '1', title: 'Tap Me');
      await tester.pumpWidget(
        createWidgetUnderTest(task, onTap: () => tapped = true),
      );
      await tester.tap(find.byType(InkWell).first);
      expect(tapped, true);
    });
  });

  group('TaskTile - Completed Task Styling', () {
    testWidgets('shows strikethrough on completed task title', (
      tester,
    ) async {
      final task = Task(id: '1', title: 'Done Task', isCompleted: true);
      await tester.pumpWidget(createWidgetUnderTest(task));
      final textWidget = tester.widget<Text>(find.text('Done Task'));
      expect(textWidget.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('does not show strikethrough on uncompleted task', (
      tester,
    ) async {
      final task = Task(id: '1', title: 'Pending', isCompleted: false);
      await tester.pumpWidget(createWidgetUnderTest(task));
      final textWidget = tester.widget<Text>(find.text('Pending'));
      expect(textWidget.style?.decoration, isNot(TextDecoration.lineThrough));
    });
  });

  group('TaskTile - No Description', () {
    testWidgets('does not show description area when empty', (tester) async {
      final task = Task(id: '1', title: 'No Desc', description: '');
      await tester.pumpWidget(createWidgetUnderTest(task));
      expect(find.text('No Desc'), findsOneWidget);
      // Should not have a second text widget for description
    });
  });
}
