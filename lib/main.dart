import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:rocis_tasks/shared/ui/app_messenger.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/google_tasks_service.dart';
import 'package:rocis_tasks/core/services/app_initializer.dart';
import 'package:rocis_tasks/core/services/background_handler.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/features/onboarding/data/services/onboarding_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/core/config/router.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';
import 'package:rocis_tasks/core/services/backup_service.dart';
import 'package:rocis_tasks/core/services/quick_actions_service.dart';
import 'package:rocis_tasks/core/services/timezone_service.dart';
import 'package:rocis_tasks/core/services/security_service.dart';

Future<void> main() async {
  // Initialize App (Core, Firebase, Hive)
  try {
    await AppInitializer.initialize();
  } catch (e, stack) {
    debugPrint(
      'main(): AppInitializer.initialize critical exception: $e\n$stack',
    );
  }

  // Register callback for home widget interactivity
  if (!kIsWeb) {
    try {
      HomeWidget.registerInteractivityCallback(
        BackgroundHandler.handleInteractivity,
      );
    } catch (e) {
      debugPrint('main(): HomeWidget.registerInteractivityCallback failed: $e');
    }
  }
  debugPrint('main(): calling runApp(AppRoot)');
  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late Future<void> _initFuture;
  final _errorHandlingService = ErrorHandlingService();
  late final _subscriptionService = SubscriptionService(_errorHandlingService);
  late final _authService = AuthService(_errorHandlingService);
  late final _calendarService = CalendarService(
    authService: _authService,
    oauthManager: _authService.oauthManager,
  );
  final _themeService = ThemeService();
  final _timezoneService = TimezoneService();
  final _calendarColorService = CalendarColorService();
  final _scheduleService = ScheduleFirestoreService();
  final _privateModeService = PrivateModeService();
  late final _taskSource = LocalTaskSource();
  late final _fullCalendarWidgetService = FullCalendarWidgetService(
    _calendarService,
    _taskSource,
    scheduleService: _scheduleService,
  );
  late final _googleTasksService = GoogleTasksService(_authService);
  late final _taskProvider = TaskProvider(
    _authService,
    _calendarService,
    _googleTasksService,
    _themeService,
    _errorHandlingService,
    _subscriptionService,
    privateModeService: _privateModeService,
    source: _taskSource,
  );
  final _connectivityService = ConnectivityService();
  late final OnboardingService _onboardingService;
  AppRouter? _appRouter;
  StreamSubscription<User?>? _authStateToSubscriptionSync;

  @override
  void initState() {
    super.initState();
    debugPrint('AppRoot: initState called');
    _initFuture = _initServices();
  }

  Future<void> _initServices() async {
    debugPrint('AppRoot: _initServices started');
    _onboardingService = OnboardingService();
    _appRouter = AppRouter(_authService, _onboardingService);
    _calendarService.setAuthService(_authService);

    try {
      // Tier 1: Critical services required for the immediate first frame UI
      await Future.wait([
        _themeService.init().catchError(
          (e, stack) => AppLogger.error(
            'Failed to init theme service',
            error: e,
            stack: stack,
          ),
        ),
        _privateModeService.init().catchError(
          (e, stack) => AppLogger.error(
            'Failed to init private mode service',
            error: e,
            stack: stack,
          ),
        ),
        _taskSource.init().catchError(
          (e, stack) => AppLogger.error(
            'Failed to init task source',
            error: e,
            stack: stack,
          ),
        ),
        _taskProvider.init().catchError(
          (e, stack) => AppLogger.error(
            'Failed to init task provider',
            error: e,
            stack: stack,
          ),
        ),
        _authService.initialized,
      ]);

      // Tier 2: Deferred background services initialized non-blockingly
      unawaited(
        Future.wait([
          _timezoneService.init().catchError(
            (e, stack) => AppLogger.error(
              'Failed to init timezone service in background',
              error: e,
              stack: stack,
            ),
          ),
          _calendarService.init().catchError(
            (e, stack) => AppLogger.error(
              'Failed to init calendar service in background',
              error: e,
              stack: stack,
            ),
          ),
          _calendarColorService.init().catchError(
            (e, stack) => AppLogger.error(
              'Failed to init calendar color service in background',
              error: e,
              stack: stack,
            ),
          ),
          _subscriptionService.init().catchError(
            (e, stack) => AppLogger.error(
              'Failed to init subscription service in background',
              error: e,
              stack: stack,
            ),
          ),
          _connectivityService.init().catchError(
            (e, stack) => AppLogger.error(
              'Failed to init connectivity service in background',
              error: e,
              stack: stack,
            ),
          ),
          _scheduleService.initialize().catchError(
            (e, stack) => AppLogger.error(
              'Failed to init schedule service in background',
              error: e,
              stack: stack,
            ),
          ),
        ]),
      );

      // Log session start
      AnalyticsService().logSessionStart();

      _authStateToSubscriptionSync?.cancel();
      _authStateToSubscriptionSync = _authService.authStateChanges.listen((
        user,
      ) {
        unawaited(_subscriptionService.syncWithAuthUserId(user?.uid));
      });

      // Synchronize subscription non-blockingly in the background
      unawaited(
        _subscriptionService.syncWithAuthUserId(_authService.currentUser?.uid),
      );
      debugPrint('AppRoot: _initServices finished successfully');
    } catch (e, stackTrace) {
      debugPrint('AppRoot: _initServices critical failure: $e');
      AppLogger.critical(
        'Critical app initialization failure',
        error: e,
        stack: stackTrace,
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _authStateToSubscriptionSync?.cancel();
    _taskProvider.dispose();
    _authService.dispose();
    _subscriptionService.dispose();
    _connectivityService.dispose();
    _themeService.dispose();
    _timezoneService.dispose();
    _calendarColorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('AppRoot: FutureBuilder waiting...');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 24),
                        Text(
                          'ROCIs Tasks',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (l10n != null)
                          Text(
                            l10n.appTagline,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('AppRoot: FutureBuilder error: ${snapshot.error}');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              backgroundColor: const Color(0xFF121212),
              body: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            l10n?.criticalErrorTitle ?? 'CRITICAL ERROR',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n?.appStartupErrorBody ??
                                'ROCIs Tasks encountered a problem during startup. Our team has been notified.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _initFuture = _initServices();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              l10n?.retryInitialization ??
                                  'Retry Initialization',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }

        debugPrint('AppRoot: FutureBuilder complete, building MultiProvider');
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _themeService),
            ChangeNotifierProvider.value(value: _timezoneService),
            ChangeNotifierProvider.value(value: _calendarColorService),
            ChangeNotifierProvider.value(value: _authService),
            ChangeNotifierProvider.value(value: _taskProvider),
            ChangeNotifierProvider.value(value: _privateModeService),
            Provider.value(value: _calendarService),
            Provider.value(value: _googleTasksService),
            Provider.value(value: _scheduleService),
            Provider.value(value: _fullCalendarWidgetService),
            ChangeNotifierProvider(
              create: (_) => CalendarProvider(
                _calendarService,
                _fullCalendarWidgetService,
                scheduleFirestoreService: _scheduleService,
                subscriptionService: _subscriptionService,
                authService: _authService,
              ),
            ),
            ChangeNotifierProvider.value(value: _onboardingService),
            Provider.value(value: _appRouter!),
            Provider.value(value: _errorHandlingService),
            ChangeNotifierProvider.value(value: _connectivityService),
            ChangeNotifierProvider.value(value: _subscriptionService),
            Provider.value(value: AnalyticsService()),
            Provider(create: (_) => BackupService()),
          ],
          child: const MyApp(),
        );
      },
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static String? _syncedWidgetTheme;

  /// Shares the app's calendar-card colors with the home widgets so they look
  /// like the in-app calendar (Material You / custom seed / AMOLED included):
  /// primary accent, surfaceContainerLow card and onSurface text.
  static const _widgetProviders = [
    'FullCalendarWidgetProvider',
    'TodayAgendaWidgetProvider',
    'MonthAgendaWidgetProvider',
    'TimelineAgendaWidgetProvider',
    'TaskWidgetProvider',
    'UpNextWidgetProvider',
    'QuickActionWidgetProvider',
    'KanbanWidgetProvider',
  ];

  void _syncWidgetTheme(ColorScheme light, ColorScheme dark) {
    if (kIsWeb) return;
    String hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';
    final colors = {
      'app_primary_color_light': hex(light.primary),
      'app_primary_color_dark': hex(dark.primary),
      'app_surface_color_light': hex(light.surfaceContainerLow),
      'app_surface_color_dark': hex(dark.surfaceContainerLow),
      'app_on_surface_color_light': hex(light.onSurface),
      'app_on_surface_color_dark': hex(dark.onSurface),
    };
    final signature = colors.values.join('|');
    if (signature == _syncedWidgetTheme) return;
    _syncedWidgetTheme = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        for (final entry in colors.entries) {
          await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
        }
        // Every widget colors itself from these, so redraw them all.
        await Future.wait(
          _widgetProviders.map((name) => HomeWidget.updateWidget(name: name)),
        );
      } catch (_) {}
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      QuickActionsService().initialize(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Widgets on the "system" theme pick light/dark when they draw; redraw them
  /// when the system switches while the app is running.
  @override
  void didChangePlatformBrightness() {
    if (kIsWeb) return;
    for (final name in _widgetProviders) {
      HomeWidget.updateWidget(name: name).catchError((_) => null);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MyApp: build called');
    final themeService = Provider.of<ThemeService>(context);
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final appRouter = Provider.of<AppRouter>(context);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        debugPrint('DynamicColorBuilder: builder called');
        final bool canUseCustomSeed =
            subscriptionService.isPremium &&
            themeService.useCustomSeedColor &&
            themeService.customSeedColorValue != null;
        final ColorScheme? lightScheme = canUseCustomSeed
            ? ColorScheme.fromSeed(
                seedColor: Color(themeService.customSeedColorValue!),
                brightness: Brightness.light,
              )
            : (themeService.useMaterialTheme ? lightDynamic : null);

        final ColorScheme? darkScheme = canUseCustomSeed
            ? ColorScheme.fromSeed(
                seedColor: Color(themeService.customSeedColorValue!),
                brightness: Brightness.dark,
              )
            : (themeService.useMaterialTheme ? darkDynamic : null);

        final lightTheme = AppTheme.createLightTheme(lightScheme);
        final darkTheme = AppTheme.createDarkTheme(
          darkScheme,
          isAmoled: themeService.useAmoledTheme,
        );
        _syncWidgetTheme(lightTheme.colorScheme, darkTheme.colorScheme);

        return MaterialApp.router(
          title: 'ROCIs Tasks',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: appMessengerKey,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeService.themeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: themeService.locale,
          routerConfig: appRouter.router,
        );
      },
    );
  }
}
