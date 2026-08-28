import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/home/presentation/screens/home_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/shared/ui/theme/app_theme.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/security_service.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';
import 'package:rocis_tasks/core/services/timezone_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class MockTaskProvider extends Mock implements TaskProvider {}
class MockCalendarProvider extends Mock implements CalendarProvider {}
class MockThemeService extends Mock implements ThemeService {}
class MockCalendarColorService extends Mock implements CalendarColorService {}
class MockAuthService extends Mock implements AuthService {}
class MockSubscriptionService extends Mock implements SubscriptionService {}
class MockPrivateModeService extends Mock implements PrivateModeService {}
class MockConnectivityService extends Mock implements ConnectivityService {}
class MockTimezoneService extends Mock implements TimezoneService {}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockTaskProvider mockTaskProvider;
  late MockCalendarProvider mockCalendarProvider;
  late MockThemeService mockThemeService;
  late MockCalendarColorService mockCalendarColorService;
  late MockAuthService mockAuthService;
  late MockSubscriptionService mockSubscriptionService;
  late MockPrivateModeService mockPrivateModeService;
  late MockConnectivityService mockConnectivityService;
  late MockTimezoneService mockTimezoneService;

  setUp(() {
    mockTaskProvider = MockTaskProvider();
    mockCalendarProvider = MockCalendarProvider();
    mockThemeService = MockThemeService();
    mockCalendarColorService = MockCalendarColorService();
    mockAuthService = MockAuthService();
    mockSubscriptionService = MockSubscriptionService();
    mockPrivateModeService = MockPrivateModeService();
    mockConnectivityService = MockConnectivityService();
    mockTimezoneService = MockTimezoneService();

    when(() => mockTaskProvider.tasks).thenReturn([]);
    when(() => mockTaskProvider.categories).thenReturn([]);
    when(() => mockTaskProvider.isLoading).thenReturn(false);
    when(() => mockTaskProvider.errorMessage).thenReturn(null);
    when(() => mockTaskProvider.selectedCount).thenReturn(0);
    when(() => mockTaskProvider.isSelectionMode).thenReturn(false);
    when(() => mockTaskProvider.selectedTaskIds).thenReturn([]);
    when(() => mockTaskProvider.taskToEdit).thenReturn(null);
    when(() => mockTaskProvider.showSecurityPrompt).thenReturn(false);
    when(() => mockTaskProvider.showMyTasksGuideShortcut).thenReturn(false);
    when(() => mockTaskProvider.syncGoogleTasksToLocal()).thenAnswer((_) async {});

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
    when(() => mockThemeService.useGlassmorphism).thenReturn(true);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockThemeService.customSeedColorValue).thenReturn(null);
    when(() => mockThemeService.locale).thenReturn(const Locale('en'));

    when(() => mockCalendarColorService.taskColor).thenReturn(Colors.blue);
    when(() => mockCalendarColorService.googleColor).thenReturn(Colors.green);

    when(() => mockAuthService.currentUser).thenReturn(null);
    when(() => mockAuthService.isGoogleTasksTokenExpired).thenReturn(false);

    when(() => mockSubscriptionService.isPremium).thenReturn(true);

    when(() => mockPrivateModeService.shouldHidePrivateContent).thenReturn(false);
    when(() => mockPrivateModeService.hasPin).thenReturn(false);

    when(() => mockConnectivityService.isOnline).thenReturn(true);
    when(() => mockTimezoneService.currentTimezone).thenReturn('UTC');
    when(() => mockTimezoneService.isAuto).thenReturn(true);
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
        ChangeNotifierProvider<ConnectivityService>.value(value: mockConnectivityService),
        ChangeNotifierProvider<TimezoneService>.value(value: mockTimezoneService),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SizedBox(
          width: 400,
          height: 800,
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.only(bottom: 48), // Simulate 3-button navigation bar inset
            ),
            child: HomeScreen(),
          ),
        ),
      ),
    );
  }

  testWidgets('renders HomeScreen with SafeArea wrapping bottomNavigationBar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(GlassContainer), findsWidgets);

    // Verify SafeArea exists and is protecting the bottom navigation bar
    final safeAreas = tester.widgetList<SafeArea>(find.byType(SafeArea));
    final hasBottomNavSafeArea = safeAreas.any((sa) => sa.top == false);
    expect(hasBottomNavSafeArea, isTrue);
  });
}
