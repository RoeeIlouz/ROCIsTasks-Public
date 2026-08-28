import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/app_initializer.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/core/services/widget_data_service.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/services/task_widget_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/l10n/l10n_helper.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/google_tasks_service.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
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
    } else if (host.startsWith('today_agenda_')) {
      await _handleTodayAgendaSync();
    } else if (host.startsWith('month_agenda_')) {
      await _handleMonthAgendaSync();
    } else if (host == 'full_calendar_prev' ||
        host == 'full_calendar_next' ||
        host == 'prev_month' ||
        host == 'next_month') {
      final isNext = host == 'full_calendar_next' || host == 'next_month';
      final isAndroidWidget = host.startsWith('full_calendar_');
      await _handleFullCalendarNavigation(
        isNext: isAndroidWidget ? null : isNext,
      );
    } else if (host == 'full_calendar_today') {
      await _handleFullCalendarNavigation();
    } else if (host == 'full_calendar_filter_tasks') {
      await _handleFullCalendarFilterToggle('tasks');
    } else if (host == 'full_calendar_filter_google') {
      await _handleFullCalendarFilterToggle('google');
    } else if (host == 'full_calendar_filter_rocis') {
      await _handleFullCalendarFilterToggle('rocis');
    } else if (host == 'kanban_sync') {
      await _handleKanbanSync();
    } else {
      AppLogger.warning('Unknown host: $host', tag: 'Background');
    }
  }

  static Future<void> _handleKanbanSync() async {
    try {
      await AppInitializer.initialize(isBackground: true);
      final calendarService = CalendarService();
      await calendarService.init();

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

      final widgetDataService = WidgetDataService(calendarService);
      await widgetDataService.updateKanbanWidget(
        taskSource.getTasks(),
        getCategoryById,
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    } catch (e, s) {
      AppLogger.error('Error handling kanban widget sync', error: e, stack: s, tag: 'Background');
    }
  }

  static Future<void> _handleTodayAgendaSync() async {
    try {
      await AppInitializer.initialize(isBackground: true);
      final calendarService = CalendarService();
      await calendarService.init();

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

      final widgetDataService = WidgetDataService(calendarService);
      await widgetDataService.updateTodayAgendaWidget(
        taskSource.getTasks(),
        getCategoryById,
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    } catch (e, s) {
      AppLogger.error('Error handling today agenda sync', error: e, stack: s, tag: 'Background');
    }
  }

  static Future<void> _handleMonthAgendaSync() async {
    try {
      await AppInitializer.initialize(isBackground: true);
      final calendarService = CalendarService();
      await calendarService.init();

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

      final widgetDataService = WidgetDataService(calendarService);
      await widgetDataService.updateMonthAgendaWidget(
        taskSource.getTasks(),
        getCategoryById,
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    } catch (e, s) {
      AppLogger.error('Error handling month agenda sync', error: e, stack: s, tag: 'Background');
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

      final taskSource = LocalTaskSource();
      await taskSource.init();

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

      if (task.googleTaskId != null) {
        try {
          final authService = AuthService(ErrorHandlingService());
          final googleTasksService = GoogleTasksService(authService);

          final categories = taskSource.getCategories();
          String? categoryName;
          final categoryIds = task.categoryIds.isNotEmpty
              ? task.categoryIds
              : (task.categoryId != null ? [task.categoryId!] : []);
          if (categoryIds.isNotEmpty) {
            try {
              final cat = categories.firstWhere(
                (c) => c.id == categoryIds.first,
              );
              categoryName = cat.name;
            } catch (_) {}
          }

          final success = await googleTasksService.updateTask(
            taskId: task.googleTaskId!,
            title: task.title,
            description: task.description,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            categoryName: categoryName,
          );
          if (success) {
            AppLogger.info(
              'Successfully updated Google Task in background',
              tag: 'Background',
            );
          } else {
            AppLogger.warning(
              'Failed to update Google Task in background',
              tag: 'Background',
            );
          }
        } catch (e, s) {
          AppLogger.warning(
            'Error updating Google Task in background: $e',
            stack: s,
            tag: 'Background',
          );
        }
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
        final brightness = PlatformDispatcher.instance.platformBrightness;
        isDarkText = brightness != Brightness.dark;
      }

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

      // Update all new Android widgets in background
      final calendarService = CalendarService();
      await calendarService.init();
      final widgetDataService = WidgetDataService(calendarService);
      await widgetDataService.updateAllWidgets(
        box.values.toList(),
        getCategoryById,
        userId: currentUser?.uid,
      );

      final languageCode = prefs.getString('language_code');
      final currentLocale = languageCode != null
          ? Locale(languageCode)
          : PlatformDispatcher.instance.locale;
      await ensureLocaleLoaded(currentLocale);
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
