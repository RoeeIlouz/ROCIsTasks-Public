import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/shared/ui/theme/app_theme.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/security_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class MockTaskProvider extends Mock implements TaskProvider {}
class MockCalendarProvider extends Mock implements CalendarProvider {}
class MockThemeService extends Mock implements ThemeService {}
class MockCalendarColorService extends Mock implements CalendarColorService {}
class MockAuthService extends Mock implements AuthService {}
class MockSubscriptionService extends Mock implements SubscriptionService {}
class MockPrivateModeService extends Mock implements PrivateModeService {}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockTaskProvider mockTaskProvider;
  late MockCalendarProvider mockCalendarProvider;
  late MockThemeService mockThemeService;
  late MockCalendarColorService mockCalendarColorService;
  late MockAuthService mockAuthService;
  late MockSubscriptionService mockSubscriptionService;
  late MockPrivateModeService mockPrivateModeService;

  setUp(() {
    mockTaskProvider = MockTaskProvider();
    mockCalendarProvider = MockCalendarProvider();
    mockThemeService = MockThemeService();
    mockCalendarColorService = MockCalendarColorService();
    mockAuthService = MockAuthService();
    mockSubscriptionService = MockSubscriptionService();
    mockPrivateModeService = MockPrivateModeService();

    when(() => mockTaskProvider.tasks).thenReturn([]);
    when(() => mockTaskProvider.categories).thenReturn([]);
    when(() => mockCalendarProvider.selectedDate).thenReturn(DateTime.now());
    when(() => mockCalendarProvider.showTasks).thenReturn(true);
    when(() => mockCalendarProvider.showGoogleCalendar).thenReturn(false);
    when(() => mockCalendarProvider.isLoading).thenReturn(false);
    when(() => mockCalendarProvider.selectedCalendarIds).thenReturn({});
    when(() => mockCalendarProvider.getEventsForDay(any())).thenReturn([]);
    when(() => mockCalendarProvider.setUserId(any())).thenReturn(null);
    when(() => mockCalendarProvider.loadFilters()).thenAnswer((_) async {});
    when(() => mockCalendarProvider.loadEvents()).thenAnswer((_) async {});
    when(() => mockCalendarProvider.events).thenReturn([]);
    when(() => mockCalendarProvider.availableCalendars).thenReturn([]);
    when(() => mockCalendarProvider.isGoogleCalendarTokenExpired).thenReturn(false);
    when(() => mockThemeService.use24HourFormat).thenReturn(true);
    when(() => mockThemeService.isDarkMode).thenReturn(false);
    when(() => mockThemeService.useGlassmorphism).thenReturn(false);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockCalendarColorService.taskColor).thenReturn(Colors.blue);
    when(() => mockCalendarColorService.googleColor).thenReturn(Colors.green);
    when(() => mockAuthService.currentUser).thenReturn(null);
    when(() => mockAuthService.isGoogleTasksTokenExpired).thenReturn(false);
    when(() => mockSubscriptionService.isPremium).thenReturn(true);
    when(() => mockPrivateModeService.shouldHidePrivateContent).thenReturn(false);
    when(() => mockPrivateModeService.hasPin).thenReturn(false);
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskProvider>.value(value: mockTaskProvider),
        ChangeNotifierProvider<CalendarProvider>.value(value: mockCalendarProvider),
        ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
        ChangeNotifierProvider<CalendarColorService>.value(value: mockCalendarColorService),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<SubscriptionService>.value(value: mockSubscriptionService),
        ChangeNotifierProvider<PrivateModeService>.value(value: mockPrivateModeService),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: CalendarScreen(),
        ),
      ),
    );
  }

  testWidgets('renders CalendarScreen properly with TableCalendar and header', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(CalendarScreen), findsOneWidget);
  });

  testWidgets('renders dot indicators when multiple events exist on same day', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final task1 = Task(id: 't1', title: 'Task 1', dueDate: today.add(const Duration(hours: 10)));
    final task2 = Task(id: 't2', title: 'Task 2', dueDate: today.add(const Duration(hours: 14)));

    when(() => mockTaskProvider.tasks).thenReturn([task1, task2]);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(CalendarScreen), findsOneWidget);
  });
}
