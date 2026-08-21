import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_tile.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/shared/ui/theme/app_theme.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/security_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class MockTaskProvider extends Mock implements TaskProvider {}
class MockThemeService extends Mock implements ThemeService {}
class MockSubscriptionService extends Mock implements SubscriptionService {}
class MockPrivateModeService extends Mock implements PrivateModeService {}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

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
    when(() => mockThemeService.useGlassmorphism).thenReturn(false);
    when(() => mockThemeService.taskCompletionFeedback).thenReturn(false);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockSubscriptionService.isPremium).thenReturn(true);
    when(() => mockPrivateModeService.shouldHidePrivateContent).thenReturn(false);
    when(() => mockPrivateModeService.hasPin).thenReturn(false);
    when(() => mockTaskProvider.isSelectionMode).thenReturn(false);
    when(() => mockTaskProvider.selectedTaskIds).thenReturn([]);
    when(() => mockTaskProvider.getCategoryById(any())).thenReturn(null);
  });

  Widget buildTestWidget(Task task) {
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
        home: Scaffold(
          body: TaskTile(
            task: task,
            categories: const [],
            isSelected: false,
            isSelectionMode: false,
            onToggle: () {},
            onDelete: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('tapping due date chip opens quick reschedule bottom sheet', (tester) async {
    final task = Task(
      id: 'task-1',
      title: 'Review PR',
      dueDate: DateTime.now().add(const Duration(hours: 2)),
    );

    await tester.pumpWidget(buildTestWidget(task));
    await tester.pumpAndSettle();

    final timeChip = find.byIcon(Icons.access_time_rounded);
    expect(timeChip, findsOneWidget);

    await tester.tap(timeChip);
    await tester.pumpAndSettle();

    expect(find.text('Reschedule'), findsOneWidget);
    expect(find.text('+1 Day'), findsOneWidget);
    expect(find.text('+1 Week'), findsOneWidget);
  });

  testWidgets('overdue task shows Move to Today option in reschedule sheet', (tester) async {
    final task = Task(
      id: 'task-2',
      title: 'Overdue task',
      dueDate: DateTime.now().subtract(const Duration(days: 2)),
    );

    await tester.pumpWidget(buildTestWidget(task));
    await tester.pumpAndSettle();

    final timeChip = find.byIcon(Icons.access_time_rounded);
    expect(timeChip, findsOneWidget);

    await tester.tap(timeChip);
    await tester.pumpAndSettle();

    expect(find.text('Move to Today'), findsOneWidget);
  });
}
