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
  late final MonthWidgetService _monthWidgetService;
  late final FullCalendarWidgetService _fullCalendarWidgetService;
  bool _isLoading = true;
  StreamSubscription? _tasksSubscription;
  StreamSubscription? _categoriesSubscription;
  StreamSubscription? _authSubscription;

  TaskProvider(this._authService, this._calendarService);
  Timer? _widgetDebounce;
  bool _widgetUpdateInProgress = false;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _monthWidgetService = MonthWidgetService(_calendarService, _source);
    _fullCalendarWidgetService = FullCalendarWidgetService(
      _calendarService,
      _source,
    );
    await _source.init();
    await _notificationService.init();
    await _notificationService.requestPermissions();

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
    // 1. Update Persistent Notification FIRST to ensure visibility
    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (_widgetUpdateInProgress) return;
      _widgetUpdateInProgress = true;
      try {
        final uncompletedTasks = _source
            .getTasks()
            .where((t) => !t.isCompleted && !(t.isDeleted ?? false))
            .toList();

        uncompletedTasks.sort((a, b) {
          // Priority descending (High -> Medium -> Low)
          if (a.priority != b.priority) {
            return b.priority.index.compareTo(a.priority.index);
          }
          // Fallback to due date
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });

        await _notificationService.showTaskCountNotification(
          uncompletedTasks.length,
          uncompletedTasks.map((t) => t.title).toList(),
        );
      } catch (e) {
        debugPrint('Error updating notification early: $e');
      } finally {
        _widgetUpdateInProgress = false;
      }
    });

    // Continue with other widget updates
    debugPrint('WIDGET DEBUG: updateHomeWidget started');
    try {
      // 1. Update Task Widget using dedicated service
      await TaskWidgetService.updateTaskWidget(
        _source.getTasks(),
        getCategoryById,
      );

      // 2. Get Events for Month View (Tasks + Calendar Events)
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month + 2, 0);

      final eventsByDay = <String, bool>{};

      // Add Tasks with Due Dates
      final allTasks = _source.getTasks().where((t) => !(t.isDeleted ?? false));
      for (var task in allTasks) {
        if (task.dueDate != null) {
          final dateKey = DateFormat('yyyy-MM-dd').format(task.dueDate!);
          eventsByDay[dateKey] = true;
        }
      }

      // Add Calendar Events
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
        final monthMapJson = jsonEncode(eventsByDay);
        debugPrint(
          'WIDGET DEBUG: Saving month_events_map. Payload length: ${monthMapJson.length}',
        );
        await HomeWidget.saveWidgetData<String>(
          'month_events_map',
          monthMapJson,
        );
      } catch (e) {
        debugPrint('Error serializing month events for widget: $e');
        // Provide fallback empty data
        await HomeWidget.saveWidgetData<String>('month_events_map', '{}');
      }

      // Update Widgets
      await HomeWidget.updateWidget(
        name: 'CalendarWidgetProvider',
        iOSName: 'CalendarWidget',
      );

      // 3. Get Schedule List (Combined Tasks + Events for Agenda)
      final scheduleStart = DateTime.now().subtract(
        const Duration(days: 1),
      ); // Include today
      final scheduleEnd = DateTime.now().add(const Duration(days: 30));

      final scheduleItems = <Map<String, dynamic>>[];

      // Add Tasks
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
          'dateDisplay': _formatDateForDisplay(t.dueDate!),
          'timeDisplay': DateFormat('HH:mm').format(t.dueDate!),
          'isAllDay': false,
          'location': '', // Tasks don't have location
          'priority': t.priority.name,
        });
      }

      // Add Events (Fetch for schedule range)
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
              'dateDisplay': _formatDateForDisplay(event.start!),
              'timeDisplay': event.allDay == true
                  ? 'All Day'
                  : DateFormat('HH:mm').format(event.start!),
              'isAllDay': event.allDay ?? false,
              'location': event.location ?? '',
              'category_color': '#4285F4', // Default event color
              'priority': '', // Events don't have priority
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching calendar events for schedule: $e');
      }

      // Sort by date
      scheduleItems.sort((a, b) {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        return dateA.compareTo(dateB);
      });

      try {
        final scheduleJson = jsonEncode(scheduleItems);
        debugPrint(
          'WIDGET DEBUG: Saving schedule list with ${scheduleItems.length} items. Payload size: ${scheduleJson.length}',
        );

        await HomeWidget.saveWidgetData<String>('schedule_list', scheduleJson);
      } catch (e) {
        debugPrint('Error serializing schedule items for widget: $e');
        // Provide fallback empty data
        await HomeWidget.saveWidgetData<String>('schedule_list', '[]');
      }

      await HomeWidget.updateWidget(
        name: 'ScheduleWidgetProvider',
        iOSName: 'ScheduleWidget',
      );
      // (Persistent Notification now updated at the beginning of this method)

      // 4. Get Calendar Events for CalendarWidget (List View)
      // Showing Next 7 Days of events
      final listStart = DateTime.now();
      final listEnd = listStart.add(const Duration(days: 7));
      final calendarListEvents = <Map<String, dynamic>>[];

      try {
        final events = await _calendarService.getEvents(
          startDate: listStart,
          endDate: listEnd,
        );

        // Process events with proper field completeness
        for (var event in events) {
          if (event.start != null) {
            final timeStr = event.allDay == true
                ? 'All Day'
                : DateFormat('HH:mm').format(event.start!);

            calendarListEvents.add({
              'type': 'event',
              'id': event.eventId ?? '',
              'title': event.title ?? 'No Title',
              'start': event.start!.toIso8601String(),
              'startDisplay': timeStr,
              'dateDisplay': _formatDateForDisplay(event.start!),
              'category_color': '#4285F4', // Default event color
            });
          }
        }

        // Add Tasks with proper filtering and field completeness
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
            'dateDisplay': _formatDateForDisplay(t.dueDate!),
            'category_color': cat != null
                ? '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}'
                : '#9E9E9E', // Default gray color for tasks without category
          });
        }
      } catch (e) {
        debugPrint('Error fetching events/tasks for CalendarWidget list: $e');
        // Provide fallback empty data on error
        calendarListEvents.clear();
      }

      // Sort combined list chronologically (proper data merging)
      calendarListEvents.sort((a, b) {
        final aStart = a['start'] as String;
        final bStart = b['start'] as String;
        if (aStart.isEmpty && bStart.isEmpty) return 0;
        if (aStart.isEmpty) return 1;
        if (bStart.isEmpty) return -1;
        return DateTime.parse(aStart).compareTo(DateTime.parse(bStart));
      });

      // Add header with week number calculation
      final currentWeekNumber = _getWeekNumber(DateTime.now());
      final headerData = {
        'currentWeek': currentWeekNumber,
        'dateRange':
            '${_formatDateForDisplay(listStart)} - ${_formatDateForDisplay(listEnd)}',
        'itemCount': calendarListEvents.length,
      };

      try {
        await HomeWidget.saveWidgetData<String>(
          'calendar_events_list',
          jsonEncode(calendarListEvents),
        );

        // Save header data separately
        await HomeWidget.saveWidgetData<String>(
          'calendar_header_data',
          jsonEncode(headerData),
        );
      } catch (e) {
        debugPrint('Error serializing calendar events list for widget: $e');
        // Provide fallback empty data
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

      // 5. Update Month Widget
      try {
        await _monthWidgetService.updateMonthWidget();
      } catch (e) {
        debugPrint('Error updating Month Widget in TaskProvider: $e');
      }

      // 6. Update Full Calendar Widget
      try {
        await _fullCalendarWidgetService.updateFullCalendarWidget();
      } catch (e) {
        debugPrint('Error updating Full Calendar Widget in TaskProvider: $e');
      }
    } catch (e) {
      debugPrint('Error updating home widget: $e');
    }
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
          id: task.id.hashCode,
          title: 'Task Reminder: $title',
          body: description.isNotEmpty
              ? description
              : 'You have a task due now!',
          scheduledDate: dueDate,
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
      await _notificationService.cancelNotification(task.id.hashCode);
    } else if (task.dueDate != null && task.dueDate!.isAfter(DateTime.now())) {
      await _notificationService.scheduleNotification(
        id: task.id.hashCode,
        title: 'Task Reminder: ${task.title}',
        body: task.description.isNotEmpty
            ? task.description
            : 'You have a task due now!',
        scheduledDate: task.dueDate!,
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
    await _notificationService.cancelNotification(task.id.hashCode);
    if (!task.isCompleted &&
        task.dueDate != null &&
        task.dueDate!.isAfter(DateTime.now())) {
      try {
        await _notificationService.scheduleNotification(
          id: task.id.hashCode,
          title: 'Task Reminder: ${task.title}',
          body: task.description.isNotEmpty
              ? task.description
              : 'You have a task due now!',
          scheduledDate: task.dueDate!,
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
      await _notificationService.cancelNotification(id.hashCode);
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
          id: task.id.hashCode,
          title: 'Task Reminder: ${task.title}',
          body: task.description.isNotEmpty
              ? task.description
              : 'You have a task due now!',
          scheduledDate: task.dueDate!,
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
    await _notificationService.cancelNotification(id.hashCode);
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

  /// Format date for consistent display across widgets (YYYY-MM-DD format)
  String _formatDateForDisplay(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
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
