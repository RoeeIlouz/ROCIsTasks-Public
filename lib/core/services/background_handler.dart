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
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/services/task_widget_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/l10n/l10n_helper.dart';
import 'dart:ui';

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
    } else if (host == 'full_calendar_prev' ||
        host == 'full_calendar_next' ||
        host == 'prev_month' ||
        host == 'next_month') {
      final isNext = host == 'full_calendar_next' || host == 'next_month';
      await _handleFullCalendarNavigation(isNext: isNext);
    } else if (host == 'full_calendar_today') {
      await _handleFullCalendarNavigation(targetOffset: 0);
    } else if (host == 'full_calendar_filter_tasks') {
      await _handleFullCalendarFilterToggle('tasks');
    } else if (host == 'full_calendar_filter_google') {
      await _handleFullCalendarFilterToggle('google');
    } else if (host == 'full_calendar_filter_rocis') {
      await _handleFullCalendarFilterToggle('rocis');
    } else {
      AppLogger.warning('Unknown host: $host', tag: 'Background');
    }
  }

  static Future<void> _handleFullCalendarNavigation({
    bool? isNext,
    int? targetOffset,
  }) async {
    try {
      AppLogger.info(
        'Handling calendar navigation: isNext=$isNext, targetOffset=$targetOffset',
        tag: 'Background',
      );
      await AppInitializer.initialize(isBackground: true);

      int offset =
          await HomeWidget.getWidgetData<int>('full_calendar_offset') ?? 0;
      final oldOffset = offset;

      if (targetOffset != null) {
        offset = targetOffset;
      } else if (isNext != null) {
        offset = isNext ? offset + 1 : offset - 1;
      }

      await HomeWidget.saveWidgetData<int>('full_calendar_offset', offset);

      AppLogger.info(
        'Offset updated: $oldOffset -> $offset',
        tag: 'Background',
      );

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

      AppLogger.info(
        'Full calendar widget updated successfully with offset $offset',
        tag: 'Background',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error in full calendar navigation',
        error: e,
        stack: stackTrace,
        tag: 'Background',
      );
    }
  }

  static Future<void> _handleFullCalendarFilterToggle(String filterName) async {
    try {
      await AppInitializer.initialize(isBackground: true);

      final calendarService = CalendarService();
      await calendarService.init();

      final taskSource = LocalTaskSource();
      await taskSource.init();

      final fullCalendarService = FullCalendarWidgetService(
        calendarService,
        taskSource,
      );

      // Toggle the filter
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

      await fullCalendarService.updateFullCalendarWidget(
        monthOffset: offset,
        userId: currentUser?.uid,
      );
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

      final box = await Hive.openBox<Task>(LocalTaskSource.boxName);
      final task = box.values.firstWhere((t) => t.id == taskId);
      task.isCompleted = true;
      await task.save();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestoreService = FirestoreService();
        firestoreService.setUserId(currentUser.uid);
        await firestoreService.updateTask(task);
      }

      final pendingTasks = box.values
          .where((t) => !t.isCompleted && !(t.isDeleted ?? false))
          .toList();

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

      final categories = taskSource.getCategories();
      Category? getCategoryById(String? id) {
        if (id == null || id.isEmpty) return null;
        try {
          return categories.firstWhere((c) => c.id == id);
        } catch (_) {
          return null;
        }
      }

      final chartPath = await TaskWidgetService.updateTaskWidget(
        box.values.toList(),
        getCategoryById,
        isDarkText: isDarkText,
      );

      final languageCode = prefs.getString('language_code');
      final currentLocale = languageCode != null
          ? Locale(languageCode)
          : PlatformDispatcher.instance.locale;
      final l10n = getSafeAppLocalizations(currentLocale);
      String priorityLabel(TaskPriority p) {
        switch (p) {
          case TaskPriority.high:
            return l10n.high;
          case TaskPriority.medium:
            return l10n.medium;
          case TaskPriority.low:
            return l10n.low;
        }
      }

      String formatTitle(Task t) {
        final categoryName = getCategoryById(t.categoryId)?.name;
        final parts = <String>[
          if (categoryName != null && categoryName.isNotEmpty) categoryName,
          priorityLabel(t.priority),
          t.title,
        ];
        return parts.join(' • ');
      }

      await notificationService.showTaskCountNotification(
        pendingTasks.length,
        pendingTasks.map(formatTitle).toList(),
        largeIconPath: chartPath,
        isDarkText: isDarkText,
        uncompletedTasksLabel: l10n.notificationUncompletedTasks(
          pendingTasks.length,
        ),
        tasksRemainingLabel: l10n.notificationTasksRemaining,
        tasksSummaryLabel: l10n.notificationTasksSummary(pendingTasks.length),
      );
    } catch (e) {
      AppLogger.error('Background task error', error: e, tag: 'Background');
    }
  }
}
