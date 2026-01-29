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

    await Future.wait([
      _taskSource.init().catchError((e) {
        debugPrint('LocalTaskSource init failed: $e');
      }),
      _taskProvider.init().catchError((e) {
        debugPrint('TaskProvider init failed: $e');
      }),
      _calendarService.init().catchError((e) {
        debugPrint('CalendarService init failed: $e');
      }),
      _themeService.init().catchError((e) {
        debugPrint('ThemeService init failed: $e');
      }),
      _calendarColorService.init().catchError((e) {
        debugPrint('CalendarColorService init failed: $e');
      }),
      _scheduleService.initialize().catchError((e) {
        debugPrint('ScheduleFirestoreService init failed: $e');
      }),
    ]);
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
              backgroundColor: Colors.black,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 80,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'CRITICAL ERROR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to initialize app: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                        ),
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
