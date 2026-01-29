import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/app_initializer.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/home/services/month_widget_service.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/services/task_widget_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

@pragma('vm:entry-point')
class BackgroundHandler {
  @pragma('vm:entry-point')
  static Future<void> handleInteractivity(Uri? uri) async {
    AppLogger.info(
      'handleInteractivity called with uri: $uri',
      tag: 'Background',
    );
    if (uri == null) {
      return;
    }

    final host = uri.host;
    final queryParams = uri.queryParameters;
    AppLogger.info('host=$host, queryParams=$queryParams', tag: 'Background');

    if (host == 'complete') {
      final taskId = queryParams['id'];
      if (taskId != null) {
        await _completeTaskInBackground(taskId);
      }
    } else if (host == 'prev_month' || host == 'next_month') {
      await _handleMonthNavigation(host == 'next_month');
    } else if (host == 'full_calendar_prev' || host == 'full_calendar_next') {
      final timestamp = DateTime.now().toIso8601String();
      AppLogger.info(
        '[$timestamp] FULL_CALENDAR NAV CLICKED: $host',
        tag: 'Background',
      );
      print('DEBUG: Full calendar navigation triggered: $host at $timestamp');
      await _handleFullCalendarNavigation(host == 'full_calendar_next');
      AppLogger.info('[$timestamp] Navigation completed', tag: 'Background');
    } else if (host == 'full_calendar_filter_tasks') {
      AppLogger.info('Handling filter_tasks toggle', tag: 'Background');
      await _handleFullCalendarFilterToggle('tasks');
    } else if (host == 'full_calendar_filter_google') {
      AppLogger.info('Handling filter_google toggle', tag: 'Background');
      await _handleFullCalendarFilterToggle('google');
    } else if (host == 'full_calendar_filter_rocis') {
      AppLogger.info('Handling filter_rocis toggle', tag: 'Background');
      await _handleFullCalendarFilterToggle('rocis');
    } else {
      AppLogger.warning('Unknown host: $host', tag: 'Background');
    }
  }

  static Future<void> _handleMonthNavigation(bool isNext) async {
    await AppInitializer.initialize(isBackground: true);

    final prefs = await SharedPreferences.getInstance();
    int offset = prefs.getInt('month_widget_offset') ?? 0;
    offset = isNext ? offset + 1 : offset - 1;
    await prefs.setInt('month_widget_offset', offset);

    final calendarService = CalendarService();
    await calendarService.init();

    final taskSource = LocalTaskSource();
    await taskSource.init();

    final monthService = MonthWidgetService(calendarService, taskSource);
    await monthService.updateMonthWidget(monthOffset: offset);
  }

  static Future<void> _handleFullCalendarNavigation(bool isNext) async {
    await AppInitializer.initialize(isBackground: true);

    final prefs = await SharedPreferences.getInstance();
    int offset = prefs.getInt('full_calendar_offset') ?? 0;
    offset = isNext ? offset + 1 : offset - 1;
    await prefs.setInt('full_calendar_offset', offset);

    final calendarService = CalendarService();
    await calendarService.init();

    final taskSource = LocalTaskSource();
    await taskSource.init();

    final fullCalendarService = FullCalendarWidgetService(
      calendarService,
      taskSource,
    );

    // Initialize schedule service and set user email for ROCIs-Schedule integration
    await fullCalendarService.initScheduleService();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      fullCalendarService.setUserEmail(currentUser.email);
    }

    await fullCalendarService.updateFullCalendarWidget(
      monthOffset: offset,
      userId: currentUser?.uid,
    );
  }

  static Future<void> _handleFullCalendarFilterToggle(String filterName) async {
    AppLogger.info(
      '_handleFullCalendarFilterToggle started for $filterName',
      tag: 'Background',
    );
    try {
      await AppInitializer.initialize(isBackground: true);
      AppLogger.info('AppInitializer completed', tag: 'Background');

      final calendarService = CalendarService();
      await calendarService.init();

      final taskSource = LocalTaskSource();
      await taskSource.init();

      final fullCalendarService = FullCalendarWidgetService(
        calendarService,
        taskSource,
      );

      // Toggle the filter
      AppLogger.info('Toggling filter $filterName', tag: 'Background');
      await fullCalendarService.toggleFilter(filterName);

      // Initialize schedule service and set user email for ROCIs-Schedule integration
      await fullCalendarService.initScheduleService();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        fullCalendarService.setUserEmail(currentUser.email);
      }

      // Refresh the widget with current offset
      final prefs = await SharedPreferences.getInstance();
      final offset = prefs.getInt('full_calendar_offset') ?? 0;

      AppLogger.info('Updating widget with offset $offset', tag: 'Background');
      await fullCalendarService.updateFullCalendarWidget(
        monthOffset: offset,
        userId: currentUser?.uid,
      );
      AppLogger.info('Filter toggle completed successfully', tag: 'Background');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error in filter toggle',
        error: e,
        stack: stackTrace,
        tag: 'Background',
      );
    }
  }

  static Future<void> _completeTaskInBackground(String taskId) async {
    try {
      await AppInitializer.initialize(isBackground: true);

      final box = await Hive.openBox<Task>('tasks');
      final task = box.values.firstWhere((t) => t.id == taskId);
      task.isCompleted = true;
      await task.save();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestoreService = FirestoreService();
        firestoreService.setUserId(currentUser.uid);
        await firestoreService.updateTask(task);
      }

      final pendingTasks = box.values.where((t) => !t.isCompleted).toList();
      pendingTasks.sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

      final tasksJson = pendingTasks
          .map(
            (t) => {
              'id': t.id,
              'title': t.title,
              'priority': t.priority.name,
              'dueDate': t.dueDate?.toString().split(' ')[0] ?? '',
            },
          )
          .toList();

      await HomeWidget.saveWidgetData<String>(
        'pending_tasks_list',
        jsonEncode(tasksJson),
      );

      final widgetNames = [
        'CalendarWidgetProvider',
        'ScheduleWidgetProvider',
        'TaskWidgetProvider',
      ];

      for (final name in widgetNames) {
        await HomeWidget.updateWidget(name: name);
      }

      final notificationService = NotificationService();
      await notificationService.init();

      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
      bool isDarkText = true;

      if (themeModeIndex == 2) {
        isDarkText = false;
      } else if (themeModeIndex == 0) {
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        isDarkText = brightness != Brightness.dark;
      }

      final taskSource = LocalTaskSource();
      await taskSource.init();

      final chartPath = await TaskWidgetService.updateTaskWidget(
        box.values.toList(),
        (id) => Hive.box<Category>('categories').get(id),
        isDarkText: isDarkText,
      );

      await notificationService.showTaskCountNotification(
        pendingTasks.length,
        pendingTasks.map((t) => t.title).toList(),
        largeIconPath: chartPath,
        isDarkText: isDarkText,
      );
    } catch (e) {
      AppLogger.error('Background task error', error: e, tag: 'Background');
    }
  }
}
