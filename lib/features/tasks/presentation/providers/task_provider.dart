import 'package:flutter/foundation.dart' hide Category;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rocis_tasks/core/theme/theme_service.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';

import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/home/services/month_widget_service.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/features/tasks/services/task_widget_service.dart';
import 'package:rocis_tasks/core/services/widget_data_service.dart';

enum TaskSortOption { dueDate, priority, title, dateCreated }

class TaskProvider extends ChangeNotifier {
  final LocalTaskSource _source = LocalTaskSource();
  final NotificationService _notificationService = NotificationService();
  final FirestoreService _firestoreService = FirestoreService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final AuthService _authService;
  final CalendarService _calendarService;
  final ThemeService _themeService;
  late final MonthWidgetService _monthWidgetService;
  late final FullCalendarWidgetService _fullCalendarWidgetService;
  late final WidgetDataService _widgetDataService;
  bool _isLoading = true;
  StreamSubscription? _tasksSubscription;
  StreamSubscription? _categoriesSubscription;
  StreamSubscription? _authSubscription;
  StreamSubscription? _connectivitySubscription;

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
    _widgetDataService = WidgetDataService(_calendarService);

    await _source.init();
    await _notificationService.init();
    await _notificationService.requestPermissions();

    await _notificationService.cancelAllNotifications();

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
          debugPrint('Error rescheduling notification: $e');
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final sortIndex = prefs.getInt('sort_option');
    if (sortIndex != null && sortIndex < TaskSortOption.values.length) {
      _currentSortOption = TaskSortOption.values[sortIndex];
    }
    _selectedCategoryIds = prefs.getStringList('category_filters') ?? [];
    _showCompleted = prefs.getBool('show_completed') ?? true;

    // Initialize connectivity service
    await _connectivityService.init();

    // Listen to connectivity changes to sync when coming back online
    _connectivitySubscription =
        _connectivityService.addListener(() {
              if (_connectivityService.isOnline &&
                  _authService.currentUser != null) {
                debugPrint('Network restored - attempting sync');
                syncWithCloud();
              }
            })
            as StreamSubscription?;

    _authSubscription = _authService.authStateChanges.listen((
      User? user,
    ) async {
      if (user != null) {
        _firestoreService.setUserId(user.uid);
        // Only sync if online
        if (_connectivityService.isOnline) {
          await uploadLocalDataToCloud();
          await syncWithCloud();
        } else {
          debugPrint('User signed in but offline - will sync when online');
        }
      } else {
        _firestoreService.setUserId(null);
        await _cancelSubscriptions();
        await _source.clearAll();
        updateHomeWidget();
      }
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();

    await updateHomeWidget();

    if (_authService.currentUser != null) {
      _firestoreService.setUserId(_authService.currentUser!.uid);
      // Only sync if online
      if (_connectivityService.isOnline) {
        await uploadLocalDataToCloud();
        await syncWithCloud();
        updateHomeWidget();
      } else {
        debugPrint('App started offline - will sync when online');
      }
    }

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
    } catch (e) {
      debugPrint('Error navigating to task: $e');
    }
  }

  Future<void> _snoozeTask(String taskId) async {
    try {
      final task = _source.getTasks().firstWhere((t) => t.id == taskId);
      if (task.dueDate != null) {
        final newDate = task.dueDate!.add(const Duration(minutes: 15));
        await updateTask(task, dueDate: newDate);
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
      }
    } catch (e) {
      debugPrint('Error completing task: $e');
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
    _connectivitySubscription?.cancel();
    _cancelSubscriptions();
    super.dispose();
  }

  Future<void> uploadLocalDataToCloud() async {
    if (_authService.currentUser == null) return;

    try {
      final tasks = _source.getTasks();
      final categories = _source.getCategories();
      for (var category in categories) {
        await _firestoreService.addCategory(category);
      }
      for (var task in tasks) {
        await _firestoreService.addTask(task);
      }
      debugPrint('Successfully uploaded local data to cloud');
    } catch (e) {
      debugPrint('Failed to upload local data (offline or error): $e');
    }
  }

  Future<void> syncWithCloud() async {
    if (_authService.currentUser == null) return;

    // Don't attempt to sync if offline
    if (!_connectivityService.isOnline) {
      debugPrint('Skipping cloud sync - offline');
      return;
    }

    await _cancelSubscriptions();
    try {
      _tasksSubscription = _firestoreService.getTasksStream().listen(
        (cloudTasks) async {
          for (var cloudTask in cloudTasks) {
            await _source.addTask(cloudTask);
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
        onError: (error) {
          debugPrint('Error in tasks stream (may be offline): $error');
        },
      );

      _categoriesSubscription = _firestoreService.getCategoriesStream().listen(
        (cloudCategories) async {
          for (var cloudCategory in cloudCategories) {
            await _source.addCategory(cloudCategory);
          }
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Error in categories stream (may be offline): $error');
        },
      );

      debugPrint('Cloud sync started successfully');
    } catch (e) {
      debugPrint('Error starting cloud sync: $e');
    }
  }

  TaskSortOption _currentSortOption = TaskSortOption.dueDate;
  List<String> _selectedCategoryIds = [];
  bool _showCompleted = true;

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

  List<Task> get tasks {
    if (_isLoading) return [];
    var tasks = _source
        .getTasks()
        .where((t) => !(t.isDeleted ?? false))
        .toList();

    if (_selectedCategoryIds.isNotEmpty) {
      tasks = tasks
          .where((t) => _selectedCategoryIds.contains(t.categoryId))
          .toList();
    }

    if (!_showCompleted) {
      tasks = tasks.where((t) => !t.isCompleted).toList();
    }

    tasks.sort((a, b) {
      if ((a.isPinned ?? false) != (b.isPinned ?? false)) {
        return (a.isPinned ?? false) ? -1 : 1;
      }
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
          return b.priority.index.compareTo(a.priority.index);
        case TaskSortOption.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case TaskSortOption.dateCreated:
          return a.title.compareTo(b.title);
      }
    });
    return tasks;
  }

  List<Task> get deletedTasks {
    if (_isLoading) return [];
    return _source.getTasks().where((t) => t.isDeleted ?? false).toList();
  }

  List<Category> get categories {
    if (_isLoading) return [];
    return _source.getCategories();
  }

  Future<void> updateHomeWidget() async {
    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (_widgetUpdateInProgress) return;
      _widgetUpdateInProgress = true;
      try {
        final chartPath = await TaskWidgetService.updateTaskWidget(
          _source.getTasks(),
          getCategoryById,
          isDarkText: !_themeService.isDarkMode,
        );

        final uncompletedTasks = _source
            .getTasks()
            .where((t) => !t.isCompleted && !(t.isDeleted ?? false))
            .toList();

        await _notificationService.showTaskCountNotification(
          uncompletedTasks.length,
          uncompletedTasks.map((t) => t.title).toList(),
          largeIconPath: chartPath,
          isDarkText: !_themeService.isDarkMode,
        );

        await _widgetDataService.updateMonthEventsMap(_source.getTasks());
        await _widgetDataService.updateScheduleWidget(
          _source.getTasks(),
          getCategoryById,
        );
        await _widgetDataService.updateCalendarListWidget(_source.getTasks());

        await _monthWidgetService.updateMonthWidget();
        await _fullCalendarWidgetService.updateFullCalendarWidget();
      } catch (e) {
        debugPrint('Error updating widgets: $e');
      } finally {
        _widgetUpdateInProgress = false;
      }
    });
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
    } catch (_) {}

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
      } catch (_) {}
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
    } catch (_) {}

    await _notificationService.cancelNotification(
      NotificationService.getNotificationId(task.id),
    );
    if (!task.isCompleted &&
        task.dueDate != null &&
        task.dueDate!.isAfter(DateTime.now())) {
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

  Future<void> toggleTaskPin(Task task) async {
    task.isPinned = !(task.isPinned ?? false);
    await _source.updateTask(task);
    await _firestoreService.updateTask(task);
    notifyListeners();
    updateHomeWidget();
  }

  Future<void> deleteTask(String id) async {
    try {
      final task = _source.getTasks().firstWhere((t) => t.id == id);
      task.isDeleted = true;
      await _source.updateTask(task);
      await _firestoreService.updateTask(task);
      await _notificationService.cancelNotification(
        NotificationService.getNotificationId(id),
      );
    } catch (_) {}
    notifyListeners();
    updateHomeWidget();
  }

  Future<void> restoreTask(Task task) async {
    task.isDeleted = false;
    await _source.updateTask(task);
    await _firestoreService.updateTask(task);
    if (!task.isCompleted &&
        task.dueDate != null &&
        task.dueDate!.isAfter(DateTime.now())) {
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
    } catch (_) {}
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
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await _source.deleteCategory(id);
    try {
      await _firestoreService.deleteCategory(id);
    } catch (_) {}
    notifyListeners();
  }

  Category? getCategoryById(String? id) {
    if (id == null) return null;
    try {
      return _source.getCategories().firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
