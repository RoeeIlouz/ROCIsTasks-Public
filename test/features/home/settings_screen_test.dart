import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rocis_tasks/features/home/presentation/screens/settings_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/shared/ui/theme/app_theme.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';
import 'package:rocis_tasks/core/services/timezone_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

class MockTaskProvider extends Mock implements TaskProvider {}

class MockCalendarProvider extends Mock implements CalendarProvider {}

class MockThemeService extends Mock implements ThemeService {}

class MockAuthService extends Mock implements AuthService {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockTimezoneService extends Mock implements TimezoneService {}

class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockTaskProvider mockTaskProvider;
  late MockCalendarProvider mockCalendarProvider;
  late MockThemeService mockThemeService;
  late MockAuthService mockAuthService;
  late MockSubscriptionService mockSubscriptionService;
  late MockAnalyticsService mockAnalyticsService;
  late MockTimezoneService mockTimezoneService;
  late MockUser mockUser;

  setUp(() {
    mockTaskProvider = MockTaskProvider();
    mockCalendarProvider = MockCalendarProvider();
    mockThemeService = MockThemeService();
    mockAuthService = MockAuthService();
    mockSubscriptionService = MockSubscriptionService();
    mockAnalyticsService = MockAnalyticsService();
    mockTimezoneService = MockTimezoneService();
    mockUser = MockUser();

    when(() => mockUser.uid).thenReturn('test-firebase-uid-999');
    when(() => mockUser.email).thenReturn('developer@rocis.app');
    when(() => mockUser.displayName).thenReturn('Roee Ilouz');
    when(() => mockUser.photoURL).thenReturn(null);

    when(() => mockTaskProvider.showMyTasksGuideShortcut).thenReturn(false);
    when(() => mockTaskProvider.advancedRemindersEnabled).thenReturn(false);
    when(() => mockTaskProvider.nagRemindersEnabled).thenReturn(false);
    when(() => mockTaskProvider.nagIntervalMinutes).thenReturn(15);
    when(() => mockTaskProvider.nagCount).thenReturn(3);
    when(() => mockTaskProvider.quietHoursEnabled).thenReturn(false);
    when(() => mockTaskProvider.quietStartMinutes).thenReturn(1320);
    when(() => mockTaskProvider.quietEndMinutes).thenReturn(420);

    when(() => mockThemeService.isDarkMode).thenReturn(false);
    when(() => mockThemeService.themeMode).thenReturn(ThemeMode.system);
    when(() => mockThemeService.useMaterialTheme).thenReturn(true);
    when(() => mockThemeService.useGlassmorphism).thenReturn(true);
    when(() => mockThemeService.useAmoledTheme).thenReturn(false);
    when(() => mockThemeService.use24HourFormat).thenReturn(true);
    when(() => mockThemeService.autoRemoveNlpDates).thenReturn(true);
    when(() => mockThemeService.taskCompletionFeedback).thenReturn(true);
    when(() => mockThemeService.locale).thenReturn(const Locale('en'));
    when(() => mockThemeService.customSeedColorValue).thenReturn(null);
    when(() => mockThemeService.useCustomSeedColor).thenReturn(false);

    when(() => mockSubscriptionService.isPremium).thenReturn(true);

    when(() => mockTimezoneService.currentTimezone).thenReturn('UTC');
    when(() => mockTimezoneService.isAuto).thenReturn(true);
    when(
      () => mockTimezoneService.formatTimezoneOffset(any()),
    ).thenReturn('+00:00');
  });

  Widget createWidgetUnderTest({User? user}) {
    when(() => mockAuthService.currentUser).thenReturn(user);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(value: mockThemeService),
        ChangeNotifierProvider<TaskProvider>.value(value: mockTaskProvider),
        ChangeNotifierProvider<CalendarProvider>.value(
          value: mockCalendarProvider,
        ),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<SubscriptionService>.value(
          value: mockSubscriptionService,
        ),
        Provider<AnalyticsService>.value(value: mockAnalyticsService),
        ChangeNotifierProvider<TimezoneService>.value(
          value: mockTimezoneService,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SettingsScreen()),
      ),
    );
  }

  testWidgets('renders Firebase User ID under email and copies on tap', (
    tester,
  ) async {
    final List<MethodCall> methodCalls = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      },
    );

    await tester.pumpWidget(createWidgetUnderTest(user: mockUser));
    await tester.pumpAndSettle();

    // Verify user profile details are displayed
    expect(find.text('Roee Ilouz'), findsOneWidget);
    expect(find.text('developer@rocis.app'), findsOneWidget);
    expect(find.text('UID: test-firebase-uid-999'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

    // Tap the UID to copy
    await tester.tap(find.text('UID: test-firebase-uid-999'));
    await tester.pumpAndSettle();

    // Verify clipboard write call occurred
    final clipboardCalls = methodCalls
        .where((call) => call.method == 'Clipboard.setData')
        .toList();
    expect(clipboardCalls.isNotEmpty, isTrue);
    expect(
      clipboardCalls.first.arguments,
      equals({'text': 'test-firebase-uid-999'}),
    );

    // Verify feedback snackbar is displayed
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('renders guest account tile when user is null', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(user: null));
    await tester.pumpAndSettle();

    expect(find.text('Guest Account'), findsOneWidget);
    expect(find.textContaining('UID:'), findsNothing);
  });
}
