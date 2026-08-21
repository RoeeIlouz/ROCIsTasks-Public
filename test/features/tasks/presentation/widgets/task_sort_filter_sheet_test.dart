import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/widgets/task_sort_filter_sheet.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class MockTaskProvider extends Mock implements TaskProvider {}
class MockThemeService extends Mock implements ThemeService {}
class MockSubscriptionService extends Mock implements SubscriptionService {}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockTaskProvider mockTaskProvider;
  late MockThemeService mockThemeService;
  late MockSubscriptionService mockSubscriptionService;

  setUp(() {
    mockTaskProvider = MockTaskProvider();
    mockThemeService = MockThemeService();
    mockSubscriptionService = MockSubscriptionService();

    when(() => mockTaskProvider.categories).thenReturn([
      Category(id: 'cat-1', name: 'Work', colorValue: 0xFF2196F3, iconCode: 58835),
    ]);
    when(() => mockTaskProvider.currentSortOption).thenReturn(TaskSortOption.dueDate);
    when(() => mockTaskProvider.currentDateFilter).thenReturn(DateTimeFilterOption.all);
    when(() => mockTaskProvider.selectedCategoryIds).thenReturn([]);
    when(() => mockTaskProvider.showCompleted).thenReturn(true);
    when(() => mockThemeService.useGlassmorphism).thenReturn(false);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockThemeService.isDarkMode).thenReturn(false);
    when(() => mockSubscriptionService.isPremium).thenReturn(true);
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskProvider>.value(value: mockTaskProvider),
        ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
        ChangeNotifierProvider<SubscriptionService>.value(value: mockSubscriptionService),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Stack(
            children: [
              TaskSortFilterSheet(),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('renders sort pills (Date, Priority, Title, Created Date)', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsWidgets);
    expect(find.text('Priority'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Created Date'), findsOneWidget);
  });

  testWidgets('tapping priority sort pill calls setSortOption', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final priorityPill = find.text('Priority');
    await tester.tap(priorityPill);
    await tester.pumpAndSettle();

    verify(() => mockTaskProvider.setSortOption(TaskSortOption.priority)).called(1);
  });

  testWidgets('shows Reset All button when active filters exist and calls resetAllFilters', (tester) async {
    when(() => mockTaskProvider.selectedCategoryIds).thenReturn(['cat-1']);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final resetButton = find.text('Reset All');
    expect(resetButton, findsOneWidget);

    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    verify(() => mockTaskProvider.resetAllFilters()).called(1);
  });
}
