import 'package:flutter/foundation.dart' hide Category;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rocis_tasks/core/theme/theme_service.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';

import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/home/services/month_widget_service.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/features/tasks/services/task_widget_service.dart';

enum TaskSortOption { dueDate, priority, title, dateCreated }

class TaskProvider extends ChangeNotifier {
  final LocalTaskSource _source = LocalTaskSource();
  final NotificationService _notificationService = NotificationService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService;
  final CalendarService _calendarService;
  final ThemeService _themeService;
  late final MonthWidgetService _monthWidgetService;
  late final FullCalendarWidgetService _fullCalendarWidgetService;
  bool _isLoading = true;
  StreamSubscription? _tasksSubscription;
  StreamSubscription? _categoriesSubscription;
  StreamSubscription? _authSubscription;

  TaskProvider(this._authService, this._calendarService, this._themeService);
  Timer? _widgetDebounce;
  bool _widgetUpdateInProgress = false;
  bool get isLoading => _isLoading;

  Task? _taskToEdit;
  Task? get taskToEdit => _taskToEdit;

  void clearTaskToEdit() {
    _taskToEdit = null;
    notifyListeners();
  }

  Future<void> init() async {
    _monthWidgetService = MonthWidgetService(_calendarService, _source);
    _fullCalendarWidgetService = FullCalendarWidgetService(
      _calendarService,
      _source,
    );
    await _source.init();
    await _notificationService.init();
    await _notificationService.requestPermissions();

    // Clear ghost notifications from previous sessions (fix for duplicate notifications)
    await _notificationService.cancelAllNotifications();

    // Reschedule valid notifications with stable IDs
    final allTasks = _source.getTasks();
    for (var task in allTasks) {
      if (!task.isCompleted &&
          !(task.isDeleted ?? false) &&
          task.dueDate != null &&
          task.dueDate!.isAfter(DateTime.now())) {
        try {
          await _notificationService.scheduleNotification(
            id: NotificationService.getNotificationId(task.id),
            title: 'Task Reminder: ${task.title}',
            body: task.description.isNotEmpty
                ? task.description
                : 'You have a task due now!',
            scheduledDate: task.dueDate!,
            taskId: task.id,
          );
        } catch (e) {
          debugPrint('Error rescheduling notification during init: $e');
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    // Load Sort Option
    final sortIndex = prefs.getInt('sort_option');
    if (sortIndex != null && sortIndex < TaskSortOption.values.length) {
      _currentSortOption = TaskSortOption.values[sortIndex];
    }
    // Load Category Filters
    _selectedCategoryIds = prefs.getStringList('category_filters') ?? [];
    // Load Show Completed
    _showCompleted = prefs.getBool('show_completed') ?? true;

    _authSubscription = _authService.authStateChanges.listen((
      User? user,
    ) async {
      if (user != null) {
        _firestoreService.setUserId(user.uid);
        // PUSH local data to cloud first if it's a new login or just to ensure sync
        await uploadLocalDataToCloud();
        await syncWithCloud();
      } else {
        _firestoreService.setUserId(null);
        await _cancelSubscriptions();
        await _source.clearAll(); // Clear local data on logout
        updateHomeWidget(); // Update widgets to reflect empty state
      }
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();

    // Explicitly update widgets and persistent notification on launch
    await updateHomeWidget();

    if (_authService.currentUser != null) {
      _firestoreService.setUserId(_authService.currentUser!.uid);
      await uploadLocalDataToCloud(); // Ensure local data is pushed on startup
      await syncWithCloud();
      updateHomeWidget();
    }

    // Listen for notification actions
    _notificationService.onNotificationResponse.listen((response) {
      final payload = response.payload;
      if (payload != null) {
        final taskId = payload;
        final actionId = response.actionId;
        if (actionId == 'snooze') {
          _snoozeTask(taskId);
        } else if (actionId == 'complete') {
          _completeTaskFromNotification(taskId);
        } else {
          // 'reschedule' or tapping the notification body
          _navigateToTask(taskId);
        }
      }
    });
  }

  void _navigateToTask(String taskId) {
    try {
      final task = _source.getTasks().firstWhere((t) => t.id == taskId);
      _taskToEdit = task;
      notifyListeners();
      debugPrint('Task $taskId set for editing/navigation');
    } catch (e) {
      debugPrint('Error navigating to task: $e');
    }
  }

  Future<void> _snoozeTask(String taskId) async {
    try {
      final task = _source.getTasks().firstWhere((t) => t.id == taskId);
      if (task.dueDate != null) {
        // Add 15 minutes
        final newDate = task.dueDate!.add(const Duration(minutes: 15));
        await updateTask(task, dueDate: newDate);
        debugPrint('Task $taskId snoozed to $newDate');
      }
    } catch (e) {
      debugPrint('Error snoozing task: $e');
    }
  }

  Future<void> _completeTaskFromNotification(String taskId) async {
    try {
      final task = _source.getTasks().firstWhere((t) => t.id == taskId);
      if (!task.isCompleted) {
        await toggleTaskCompletion(task);
        debugPrint('Task $taskId marked completed from notification');
      }
    } catch (e) {
      debugPrint('Error completing task from notification: $e');
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _tasksSubscription?.cancel();
    await _categoriesSubscription?.cancel();
    _tasksSubscription = null;
    _categoriesSubscription = null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cancelSubscriptions();
    super.dispose();
  }

  Future<void> uploadLocalDataToCloud() async {
    if (_authService.currentUser == null) return;

    final tasks = _source.getTasks();
    final categories = _source.getCategories();

    for (var category in categories) {
      await _firestoreService.addCategory(category);
    }

    for (var task in tasks) {
      await _firestoreService.addTask(task);
    }
  }

  Future<void> syncWithCloud() async {
    if (_authService.currentUser == null) return;

    await _cancelSubscriptions();

    try {
      _tasksSubscription = _firestoreService.getTasksStream().listen(
        (cloudTasks) async {
          for (var cloudTask in cloudTasks) {
            await _source.addTask(cloudTask);
            // Schedule notification for synced task if needed
            if (!cloudTask.isCompleted &&
                !(cloudTask.isDeleted ?? false) &&
                cloudTask.dueDate != null &&
                cloudTask.dueDate!.isAfter(DateTime.now())) {
              await _notificationService.scheduleNotification(
                id: NotificationService.getNotificationId(cloudTask.id),
                title: 'Task Reminder: ${cloudTask.title}',
                body: cloudTask.description.isNotEmpty
                    ? cloudTask.description
                    : 'You have a task due now!',
                scheduledDate: cloudTask.dueDate!,
                taskId: cloudTask.id,
              );
            }
          }
          notifyListeners();
          updateHomeWidget();
        },
        onError: (e) {
          debugPrint('Cloud sync error: $e');
        },
      );

      _categoriesSubscription = _firestoreService.getCategoriesStream().listen(
        (cloudCategories) async {
          for (var cloudCategory in cloudCategories) {
            await _source.addCategory(cloudCategory);
          }
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Cloud category sync error: $e');
        },
      );
    } catch (e) {
      debugPrint('Error starting cloud sync: $e');
    }
  }

  TaskSortOption _currentSortOption = TaskSortOption.dueDate;
  List<String> _selectedCategoryIds = [];
  bool _showCompleted =
      true; // Default to true or false as per preference. Let's say true but sorted last.

  TaskSortOption get currentSortOption => _currentSortOption;
  List<String> get selectedCategoryIds => _selectedCategoryIds;
  bool get showCompleted => _showCompleted;

  void setSortOption(TaskSortOption option) {
    _currentSortOption = option;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('sort_option', option.index);
    });
  }

  void toggleCategoryFilter(String categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId);
    }
    notifyListeners();
    _saveCategoryFilters();
  }

  void clearCategoryFilters() {
    _selectedCategoryIds = [];
    notifyListeners();
    _saveCategoryFilters();
  }

  void _saveCategoryFilters() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList('category_filters', _selectedCategoryIds);
    });
  }

  void toggleShowCompleted(bool value) {
    _showCompleted = value;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('show_completed', value);
    });
  }

  // Main Tasks (Active)
  List<Task> get tasks {
    if (_isLoading) return [];
    var tasks = _source
        .getTasks()
        .where((t) => !(t.isDeleted ?? false))
        .toList();

    // Filter by Category
    if (_selectedCategoryIds.isNotEmpty) {
      tasks = tasks
          .where((t) => _selectedCategoryIds.contains(t.categoryId))
          .toList();
    }

    // Filter Completed
    if (!_showCompleted) {
      tasks = tasks.where((t) => !t.isCompleted).toList();
    }

    // Sort
    tasks.sort((a, b) {
      // Pinned tasks ALWAYS come first
      if ((a.isPinned ?? false) != (b.isPinned ?? false)) {
        return (a.isPinned ?? false) ? -1 : 1;
      }

      // Always put completed tasks at the bottom if they are shown
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }

      switch (_currentSortOption) {
        case TaskSortOption.dueDate:
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);

        case TaskSortOption.priority:
          // High (2) -> Medium (1) -> Low (0)
          // We want descending order of priority index
          return b.priority.index.compareTo(a.priority.index);

        case TaskSortOption.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());

        case TaskSortOption.dateCreated:
          // Assuming tasks act like they have a creation date roughly by ID or valid due date...
          // actually we don't store creation date.
          // Maybe just fallback to title or keep original order?
          // For now let's just use title as fallback or if we had created_at
          return a.title.compareTo(b.title);
      }
    });
    return tasks;
  }

  // Trash (Deleted)
  List<Task> get deletedTasks {
    if (_isLoading) return [];
    // Return most recently deleted first? Or just list them.
    return _source.getTasks().where((t) => t.isDeleted ?? false).toList();
  }

  List<Category> get categories {
    if (_isLoading) return [];
    return _source.getCategories();
  }

  Future<void> updateHomeWidget() async {
    // Debounced update to avoid spamming during rapid changes
    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (_widgetUpdateInProgress) return;
      _widgetUpdateInProgress = true;

      try {
        debugPrint('WIDGET DEBUG: updateHomeWidget started (debounced)');

        final bool isDarkText = !_themeService.isDarkMode;

        // 1. Update Task Widget & Generate Chart
        // This service now returns the path to the generated chart image
        final chartPath = await TaskWidgetService.updateTaskWidget(
          _source.getTasks(),
          getCategoryById,
          isDarkText: isDarkText,
        );

        // 2. Update Notification with Chart
        final uncompletedTasks = _source
            .getTasks()
            .where((t) => !t.isCompleted && !(t.isDeleted ?? false))
            .toList();

        // Sort for notification listing (Priority -> Due Date)
        uncompletedTasks.sort((a, b) {
          if (a.priority != b.priority) {
            return b.priority.index.compareTo(a.priority.index);
          }
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });

        await _notificationService.showTaskCountNotification(
          uncompletedTasks.length,
          uncompletedTasks.map((t) => t.title).toList(),
          largeIconPath: chartPath,
          isDarkText: !_themeService.isDarkMode, // Black text on Light mode
        );

        // 3. Continue with other widget updates (Calendar, Schedule, Month)
        // We do this here to ensure sequential execution and avoid race conditions

        // Get Events for Month View
        final now = DateTime.now();
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month + 2, 0);
        final eventsByDay = <String, bool>{};

        final allTasks = _source.getTasks().where(
          (t) => !(t.isDeleted ?? false),
        );
        for (var task in allTasks) {
          if (task.dueDate != null) {
            final dateKey = DateFormat('yyyy-MM-dd').format(task.dueDate!);
            eventsByDay[dateKey] = true;
          }
        }

        try {
          final calendarEvents = await _calendarService.getEvents(
            startDate: start,
            endDate: end,
          );
          for (var event in calendarEvents) {
            if (event.start != null) {
              final dateKey = DateFormat('yyyy-MM-dd').format(event.start!);
              eventsByDay[dateKey] = true;
            }
          }
        } catch (e) {
          debugPrint('Error fetching calendar events for widget: $e');
        }

        try {
          await HomeWidget.saveWidgetData<String>(
            'month_events_map',
            jsonEncode(eventsByDay),
          );
        } catch (e) {
          await HomeWidget.saveWidgetData<String>('month_events_map', '{}');
        }

        await HomeWidget.updateWidget(
          name: 'CalendarWidgetProvider',
          iOSName: 'CalendarWidget',
        );

        // Update Schedule Widget
        await _updateScheduleWidget();

        // Update Calendar List Widget
        await _updateCalendarListWidget();

        // Update Month & Full Calendar Widgets
        await _monthWidgetService.updateMonthWidget();
        await _fullCalendarWidgetService.updateFullCalendarWidget();
      } catch (e) {
        debugPrint('Error in updateHomeWidget: $e');
      } finally {
        _widgetUpdateInProgress = false;
      }
    });
  }

  // Helper for Schedule Widget Logic (extracted for clarity)
  Future<void> _updateScheduleWidget() async {
    final scheduleStart = DateTime.now().subtract(const Duration(days: 1));
    final scheduleEnd = DateTime.now().add(const Duration(days: 30));
    final scheduleItems = <Map<String, dynamic>>[];

    final scheduleTasks = _source.getTasks().where((t) {
      if (t.isCompleted || (t.isDeleted ?? false) || t.dueDate == null) {
        return false;
      }
      return t.dueDate!.isAfter(scheduleStart) &&
          t.dueDate!.isBefore(scheduleEnd);
    });

    for (var t in scheduleTasks) {
      final cat = getCategoryById(t.categoryId);
      scheduleItems.add({
        'type': 'task',
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'category_color': cat != null
            ? '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}'
            : '',
        'date': t.dueDate!.toIso8601String(),
        'dateDisplay': TaskWidgetService.formatDateForDisplay(
          t.dueDate!,
        ), // Need to expose public helper or duplicate
        'timeDisplay': DateFormat('HH:mm').format(t.dueDate!),
        'isAllDay': false,
        'location': '',
        'priority': t.priority.name,
      });
    }

    try {
      final calendarEvents = await _calendarService.getEvents(
        startDate: scheduleStart,
        endDate: scheduleEnd,
      );
      for (var event in calendarEvents) {
        if (event.start != null) {
          scheduleItems.add({
            'type': 'event',
            'id': event.eventId ?? '',
            'title': event.title ?? 'No Title',
            'description': event.description ?? '',
            'date': event.start!.toIso8601String(),
            'dateDisplay': TaskWidgetService.formatDateForDisplay(event.start!),
            'timeDisplay': event.allDay == true
                ? 'All Day'
                : DateFormat('HH:mm').format(event.start!),
            'isAllDay': event.allDay ?? false,
            'location': event.location ?? '',
            'category_color': '#4285F4',
            'priority': '',
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching calendar events for schedule: $e');
    }

    scheduleItems.sort(
      (a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])),
    );

    try {
      await HomeWidget.saveWidgetData<String>(
        'schedule_list',
        jsonEncode(scheduleItems),
      );
    } catch (e) {
      await HomeWidget.saveWidgetData<String>('schedule_list', '[]');
    }

    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      iOSName: 'ScheduleWidget',
    );
  }

  // Helper for Calendar List Widget Logic (extracted for clarity)
  Future<void> _updateCalendarListWidget() async {
    final listStart = DateTime.now();
    final listEnd = listStart.add(const Duration(days: 7));
    final calendarListEvents = <Map<String, dynamic>>[];

    try {
      final events = await _calendarService.getEvents(
        startDate: listStart,
        endDate: listEnd,
      );
      for (var event in events) {
        if (event.start != null) {
          calendarListEvents.add({
            'type': 'event',
            'id': event.eventId ?? '',
            'title': event.title ?? 'No Title',
            'start': event.start!.toIso8601String(),
            'startDisplay': event.allDay == true
                ? 'All Day'
                : DateFormat('HH:mm').format(event.start!),
            'dateDisplay': TaskWidgetService.formatDateForDisplay(event.start!),
            'category_color': '#4285F4',
          });
        }
      }

      final listTasks = _source.getTasks().where((t) {
        if (t.isCompleted || (t.isDeleted ?? false) || t.dueDate == null) {
          return false;
        }
        return t.dueDate!.isAfter(listStart) && t.dueDate!.isBefore(listEnd);
      });

      for (var t in listTasks) {
        final cat = getCategoryById(t.categoryId);
        calendarListEvents.add({
          'type': 'task',
          'id': t.id,
          'title': t.title,
          'start': t.dueDate!.toIso8601String(),
          'startDisplay': DateFormat('HH:mm').format(t.dueDate!),
          'dateDisplay': TaskWidgetService.formatDateForDisplay(t.dueDate!),
          'category_color': cat != null
              ? '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}'
              : '#9E9E9E',
        });
      }
    } catch (e) {
      calendarListEvents.clear();
    }

    calendarListEvents.sort((a, b) {
      final aStart = a['start'] as String;
      final bStart = b['start'] as String;
      return DateTime.parse(aStart).compareTo(DateTime.parse(bStart));
    });

    final headerData = {
      'currentWeek': _getWeekNumber(DateTime.now()),
      'dateRange':
          '${TaskWidgetService.formatDateForDisplay(listStart)} - ${TaskWidgetService.formatDateForDisplay(listEnd)}',
      'itemCount': calendarListEvents.length,
    };

    try {
      await HomeWidget.saveWidgetData<String>(
        'calendar_events_list',
        jsonEncode(calendarListEvents),
      );
      await HomeWidget.saveWidgetData<String>(
        'calendar_header_data',
        jsonEncode(headerData),
      );
    } catch (e) {
      await HomeWidget.saveWidgetData<String>('calendar_events_list', '[]');
      await HomeWidget.saveWidgetData<String>(
        'calendar_header_data',
        jsonEncode({'currentWeek': 1, 'dateRange': '', 'itemCount': 0}),
      );
    }

    await HomeWidget.updateWidget(
      name: 'CalendarWidgetProvider',
      iOSName: 'CalendarWidget',
    );
  }

  Future<void> addTask(
    String title,
    String description,
    DateTime? dueDate,
    TaskPriority priority,
    String? category,
  ) async {
    final task = Task(
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      categoryId: category,
    );
    await _source.addTask(task);
    try {
      await _firestoreService.addTask(task);
    } catch (e) {
      debugPrint('Firestore addTask error: $e');
    }

    if (dueDate != null && dueDate.isAfter(DateTime.now())) {
      try {
        await _notificationService.scheduleNotification(
          id: NotificationService.getNotificationId(task.id),
          title: 'Task Reminder: $title',
          body: description.isNotEmpty
              ? description
              : 'You have a task due now!',
          scheduledDate: dueDate,
          taskId: task.id,
        );
      } catch (e) {
        debugPrint('Notification schedule error: $e');
      }
    }

    notifyListeners();
    updateHomeWidget();
  }

  Future<void> toggleTaskCompletion(Task task) async {
    task.isCompleted = !task.isCompleted;
    await _source.updateTask(task);
    await _firestoreService.updateTask(task);

    if (task.isCompleted) {
      await _notificationService.cancelNotification(
        NotificationService.getNotificationId(task.id),
      );
    } else if (task.dueDate != null && task.dueDate!.isAfter(DateTime.now())) {
      await _notificationService.scheduleNotification(
        id: NotificationService.getNotificationId(task.id),
        title: 'Task Reminder: ${task.title}',
        body: task.description.isNotEmpty
            ? task.description
            : 'You have a task due now!',
        scheduledDate: task.dueDate!,
        taskId: task.id,
      );
    }

    notifyListeners();
    updateHomeWidget();
  }

  Future<void> updateTask(
    Task task, {
    String? title,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    String? categoryId,
  }) async {
    if (title != null) task.title = title;
    if (description != null) task.description = description;
    if (dueDate != null) task.dueDate = dueDate;
    if (priority != null) task.priority = priority;
    if (categoryId != null) task.categoryId = categoryId;

    await _source.updateTask(task);
    try {
      await _firestoreService.updateTask(task);
    } catch (e) {
      debugPrint('Firestore updateTask error: $e');
    }

    // Handle notifications
    await _notificationService.cancelNotification(
      NotificationService.getNotificationId(task.id),
    );
    if (!task.isCompleted &&
        task.dueDate != null &&
        task.dueDate!.isAfter(DateTime.now())) {
      try {
        await _notificationService.scheduleNotification(
          id: NotificationService.getNotificationId(task.id),
          title: 'Task Reminder: ${task.title}',
          body: task.description.isNotEmpty
              ? task.description
              : 'You have a task due now!',
          scheduledDate: task.dueDate!,
          taskId: task.id,
        );
      } catch (e) {
        debugPrint('Notification reschedule error: $e');
      }
    }

    notifyListeners();
    updateHomeWidget();
  }

  Future<void> toggleTaskPin(Task task) async {
    task.isPinned = !(task.isPinned ?? false);
    await _source.updateTask(task);
    await _firestoreService.updateTask(task);
    notifyListeners();
    updateHomeWidget();
  }

  Future<void> deleteTask(String id) async {
    // Soft Delete
    try {
      final task = _source.getTasks().firstWhere((t) => t.id == id);
      task.isDeleted = true;
      await _source.updateTask(task);
      await _firestoreService.updateTask(task); // Update, not delete in cloud
      await _notificationService.cancelNotification(
        NotificationService.getNotificationId(id),
      );
    } catch (e) {
      debugPrint('Error soft deleting task: $e');
    }
    notifyListeners();
    updateHomeWidget();
  }

  Future<void> restoreTask(Task task) async {
    task.isDeleted = false;
    await _source.updateTask(task);
    await _firestoreService.updateTask(task);

    // Reschedule notification if needed
    if (!task.isCompleted &&
        task.dueDate != null &&
        task.dueDate!.isAfter(DateTime.now())) {
      try {
        await _notificationService.scheduleNotification(
          id: NotificationService.getNotificationId(task.id),
          title: 'Task Reminder: ${task.title}',
          body: task.description.isNotEmpty
              ? task.description
              : 'You have a task due now!',
          scheduledDate: task.dueDate!,
          taskId: task.id,
        );
      } catch (e) {
        debugPrint('Notification restore error: $e');
      }
    }

    notifyListeners();
    updateHomeWidget();
  }

  Future<void> deleteTaskPermanently(String id) async {
    await _source.deleteTask(id);
    await _firestoreService.deleteTask(id);
    await _notificationService.cancelNotification(
      NotificationService.getNotificationId(id),
    );
    notifyListeners();
    updateHomeWidget();
  }

  Future<void> addCategory(String name, int colorValue, int iconCode) async {
    final category = Category(
      name: name,
      colorValue: colorValue,
      iconCode: iconCode,
    );
    await _source.addCategory(category);
    try {
      await _firestoreService.addCategory(category);
    } catch (e) {
      debugPrint('Firestore addCategory error: $e');
    }
    notifyListeners();
  }

  Future<void> updateCategory(
    Category category, {
    String? name,
    int? colorValue,
    int? iconCode,
  }) async {
    if (name != null) category.name = name;
    if (colorValue != null) category.colorValue = colorValue;
    if (iconCode != null) category.iconCode = iconCode;

    await _source.updateCategory(category);
    try {
      await _firestoreService.updateCategory(category);
    } catch (e) {
      debugPrint('Firestore updateCategory error: $e');
    }
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await _source.deleteCategory(id);
    try {
      await _firestoreService.deleteCategory(id);
    } catch (e) {
      debugPrint('Firestore deleteCategory error: $e');
    }
    notifyListeners();
  }

  Category? getCategoryById(String? id) {
    if (id == null) return null;
    try {
      return _source.getCategories().firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Calculate ISO week number for a given date
  int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    int woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (woy < 1) {
      woy = _getWeekNumber(DateTime(date.year - 1, 12, 31));
    } else if (woy > 52) {
      if (DateTime(date.year, 12, 31).weekday < 4) {
        woy = 1;
      }
    }
    return woy;
  }
}
