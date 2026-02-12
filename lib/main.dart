import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';

import 'package:rocis_tasks/shared/ui/ui_kit.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/app_initializer.dart';
import 'package:rocis_tasks/core/services/background_handler.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/features/onboarding/data/services/onboarding_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/config/router.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

Future<void> main() async {
  // Initialize App (Core, Firebase, Hive)
  await AppInitializer.initialize();

  // Register callback for home widget interactivity
  HomeWidget.registerInteractivityCallback(
    BackgroundHandler.handleInteractivity,
  );
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
  late final _authService = AuthService(_errorHandlingService);
  final _calendarService = CalendarService();
  final _themeService = ThemeService();
  final _calendarColorService = CalendarColorService();
  final _scheduleService = ScheduleFirestoreService();
  late final _taskSource = LocalTaskSource();
  late final _fullCalendarWidgetService = FullCalendarWidgetService(
    _calendarService,
    _taskSource,
  );
  late final _taskProvider = TaskProvider(
    _authService,
    _calendarService,
    _themeService,
    _errorHandlingService,
  );
  late final OnboardingService _onboardingService;
  AppRouter? _appRouter;

  @override
  void initState() {
    super.initState();
    _initFuture = _initServices();
  }

  Future<void> _initServices() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingService = OnboardingService(prefs);
    _appRouter = AppRouter(_authService, _onboardingService);

    try {
      await Future.wait([
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
        _calendarService.init().catchError(
          (e, stack) => AppLogger.error(
            'Failed to init calendar service',
            error: e,
            stack: stack,
          ),
        ),
        _themeService.init().catchError(
          (e, stack) => AppLogger.error(
            'Failed to init theme service',
            error: e,
            stack: stack,
          ),
        ),
        _calendarColorService.init().catchError(
          (e, stack) => AppLogger.error(
            'Failed to init calendar color service',
            error: e,
            stack: stack,
          ),
        ),
        _scheduleService.initialize().catchError(
          (e, stack) => AppLogger.error(
            'Failed to init schedule service',
            error: e,
            stack: stack,
          ),
        ),
        _authService.initialized,
      ]);
    } catch (e, stackTrace) {
      AppLogger.critical(
        'Critical app initialization failure',
        error: e,
        stack: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 24),
                    Text(
                      "ROCI's Tasks",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      "Dotting the i's and crossing the t's",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF121212),
              body: Center(
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
                      const Text(
                        'CRITICAL ERROR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ROCI\'s Tasks encountered a problem during startup. Our team has been notified.',
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
                        child: const Text('Retry Initialization'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _themeService),
            ChangeNotifierProvider.value(value: _calendarColorService),
            ChangeNotifierProvider.value(value: _authService),
            ChangeNotifierProvider.value(value: _taskProvider),
            Provider.value(value: _calendarService),
            Provider.value(value: _scheduleService),
            Provider.value(value: _fullCalendarWidgetService),
            ChangeNotifierProvider(
              create: (_) => CalendarProvider(
                _calendarService,
                _scheduleService,
                _fullCalendarWidgetService,
              )..loadEvents(),
            ),
            ChangeNotifierProvider.value(value: _onboardingService),
            Provider.value(value: _appRouter!),
            Provider.value(value: _errorHandlingService),
          ],
          child: const MyApp(),
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final appRouter = Provider.of<AppRouter>(context);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: "ROCI's Tasks",
          debugShowCheckedModeBanner: false,
          theme: AppTheme.createLightTheme(
            themeService.useMaterialTheme ? lightDynamic : null,
          ),
          darkTheme: AppTheme.createDarkTheme(
            themeService.useMaterialTheme ? darkDynamic : null,
            isAmoled: themeService.useAmoledTheme,
          ),
          themeMode: themeService.themeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('he')],
          locale: themeService.locale,
          routerConfig: appRouter.router,
        );
      },
    );
  }
}
