import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';

import 'package:rocis_tasks/core/theme/app_theme.dart';
import 'package:rocis_tasks/core/theme/theme_service.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/app_initializer.dart';
import 'package:rocis_tasks/core/services/background_handler.dart';
import 'package:rocis_tasks/features/home/presentation/screens/home_screen.dart';
import 'package:rocis_tasks/features/auth/presentation/screens/login_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

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
  final _authService = AuthService();
  final _calendarService = CalendarService();
  final _themeService = ThemeService();
  late final _taskProvider = TaskProvider(
    _authService,
    _calendarService,
    _themeService,
  );

  @override
  void initState() {
    super.initState();
    _initFuture = _initServices();
  }

  Future<void> _initServices() async {
    await Future.wait([
      _taskProvider.init().catchError((e) {
        debugPrint('TaskProvider init failed: $e');
      }),
      _calendarService.init().catchError((e) {
        debugPrint('CalendarService init failed: $e');
      }),
      _themeService.init().catchError((e) {
        debugPrint('ThemeService init failed: $e');
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
            ChangeNotifierProvider.value(value: _authService),
            ChangeNotifierProvider.value(value: _taskProvider),
            Provider.value(value: _calendarService),
            ChangeNotifierProvider(
              create: (_) => CalendarProvider(_calendarService)..loadEvents(),
            ),
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

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
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
          home: StreamBuilder<User?>(
            stream: Provider.of<AuthService>(
              context,
              listen: false,
            ).authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return snapshot.hasData
                  ? const HomeScreen()
                  : const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
