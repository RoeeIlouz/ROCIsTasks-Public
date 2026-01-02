import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rocis_tasks/core/theme/app_theme.dart';
import 'package:rocis_tasks/core/theme/theme_service.dart';
import 'package:rocis_tasks/features/home/presentation/screens/home_screen.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/firebase_options.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/features/auth/presentation/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/features/home/services/month_widget_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'dart:convert';
import 'core/services/notification_service.dart';
import 'package:rocis_tasks/core/services/background_service_helper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize HomeWidget callback
  HomeWidget.registerInteractivityCallback(interactiveCallback);

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'APPLICATION ERROR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      '${details.exception}\n\nSTACK:\n${details.stack}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  };

  // Create and init services with robust error handling
  try {
    final authService = AuthService();
    final calendarService = CalendarService();
    final themeService = ThemeService();
    final taskProvider = TaskProvider(authService, calendarService);

    debugPrint('Initializing services...');
    await Future.wait([
      taskProvider.init().catchError(
        (e) => debugPrint('TaskProvider init failed: $e'),
      ),
      calendarService.init().catchError(
        (e) => debugPrint('CalendarService init failed: $e'),
      ),
      themeService.init().catchError(
        (e) => debugPrint('ThemeService init failed: $e'),
      ),
    ]);
    debugPrint('Services initialized successfully.');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeService),
          ChangeNotifierProvider.value(value: authService),
          ChangeNotifierProvider.value(value: taskProvider),
          Provider.value(value: calendarService),
          ChangeNotifierProvider(
            create: (_) => CalendarProvider(calendarService)..loadEvents(),
          ),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint('CRITICAL STARTUP ERROR: $e\n$stack');
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('Failed to start: $e'))),
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  if (uri?.host == 'complete') {
    final taskId = uri?.queryParameters['id'];
    if (taskId != null) {
      await _completeTaskInBackground(taskId);
    }
  } else if (uri?.host == 'prev_month' || uri?.host == 'next_month') {
    await _handleMonthNavigation(uri?.host == 'next_month');
  } else if (uri?.host == 'full_calendar_prev' ||
      uri?.host == 'full_calendar_next') {
    await _handleFullCalendarNavigation(uri?.host == 'full_calendar_next');
  } else if (uri?.host == 'add_task') {
    // This will be handled by opening the app
    // The app will open to the task creation screen
  }
}

Future<void> _handleMonthNavigation(bool isNext) async {
  // Initialize shared services
  await BackgroundServiceHelper.initBackgroundServices();

  final prefs = await SharedPreferences.getInstance();
  int offset = prefs.getInt('month_widget_offset') ?? 0;
  offset = isNext ? offset + 1 : offset - 1;
  await prefs.setInt('month_widget_offset', offset);

  // Initialize Services needed for MonthWidget
  final calendarService = CalendarService();
  await calendarService.init();

  final taskSource = LocalTaskSource();
  await taskSource.init();

  final monthService = MonthWidgetService(calendarService, taskSource);
  await monthService.updateMonthWidget(monthOffset: offset);
}

Future<void> _handleFullCalendarNavigation(bool isNext) async {
  // Initialize shared services
  await BackgroundServiceHelper.initBackgroundServices();

  final prefs = await SharedPreferences.getInstance();
  int offset = prefs.getInt('full_calendar_offset') ?? 0;
  offset = isNext ? offset + 1 : offset - 1;
  await prefs.setInt('full_calendar_offset', offset);

  // Initialize Services needed for FullCalendarWidget
  final calendarService = CalendarService();
  await calendarService.init();

  final taskSource = LocalTaskSource();
  await taskSource.init();

  final fullCalendarService = FullCalendarWidgetService(
    calendarService,
    taskSource,
  );
  await fullCalendarService.updateFullCalendarWidget(monthOffset: offset);
}

Future<void> _completeTaskInBackground(String taskId) async {
  try {
    // Initialize shared services
    await BackgroundServiceHelper.initBackgroundServices();

    final box = await Hive.openBox<Task>('tasks');

    // Find task
    final task = box.values.firstWhere((t) => t.id == taskId);
    task.isCompleted = true; // Toggle or set complete
    await task.save();

    // Push to Firestore if user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final firestoreService = FirestoreService();
      firestoreService.setUserId(currentUser.uid);
      await firestoreService.updateTask(task);
    }

    // Update Widget Data from background
    final pendingTasks = box.values.where((t) => !t.isCompleted).toList();

    pendingTasks.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    final tasksJson = pendingTasks.map((t) {
      return {
        'id': t.id,
        'title': t.title,
        'priority': t.priority.name,
        'dueDate': t.dueDate != null ? t.dueDate.toString().split(' ')[0] : '',
      };
    }).toList();

    final jsonString = jsonEncode(tasksJson);

    await HomeWidget.saveWidgetData<String>('pending_tasks_list', jsonString);
    await HomeWidget.updateWidget(
      name: 'CalendarWidgetProvider',
      iOSName: 'CalendarWidget',
    );
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      iOSName: 'ScheduleWidget',
    );
    await HomeWidget.updateWidget(
      name: 'TaskWidgetProvider',
      iOSName: 'TaskWidget',
    );

    // Update Persistent Notification from Background
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.showTaskCountNotification(
      pendingTasks.length,
      pendingTasks.map((t) => t.title).toList(),
    );
  } catch (e) {
    debugPrint('Background task error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    // DynamicColorBuilder provides the system's dynamic colors if available (Android 12+)
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
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
