import 'package:flutter/foundation.dart' hide Category;
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/pagination_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rrule/rrule.dart';

import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/home/services/month_widget_service.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/features/tasks/services/task_widget_service.dart';
import 'package:rocis_tasks/core/services/widget_data_service.dart';

import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';
import 'package:rocis_tasks/core/services/validation_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

enum TaskSortOption { dueDate, priority, title, dateCreated }

/// Main provider for task management and synchronization.
///
/// This class handles local persistence via Hive, cloud synchronization via Firestore,
/// and coordination between various services (notifications, widgets, etc.).
class TaskProvider extends ChangeNotifier {
  final LocalTaskSource _source;
  final NotificationService _notificationService;
  final FirestoreService _firestoreService;
  final ConnectivityService _connectivityService;
  final AnalyticsService _analyticsService;
  final AuthService _authService;
  final CalendarService _calendarService;
  final ThemeService _themeService;
  final ErrorHandlingService _errorHandlingService;
  final SubscriptionService _subscriptionService;
  late final MonthWidgetService _monthWidgetService;
  late final FullCalendarWidgetService _fullCalendarWidgetService;
  late final WidgetDataService _widgetDataService;
  late final PaginationService<Task> _taskPagination;
  bool _isLoading = true;
  StreamSubscription? _tasksSubscription;
  StreamSubscription? _categoriesSubscription;
  StreamSubscription? _authSubscription;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _notificationSubscription;
  String? _lastUserId;

  TaskProvider(
    this._authService,
    this._calendarService,
    this._themeService,
    this._errorHandlingService,
    this._subscriptionService, {
    LocalTaskSource? source,
    NotificationService? notificationService,
    FirestoreService? firestoreService,
    ConnectivityService? connectivityService,
    AnalyticsService? analyticsService,
  }) : _source = source ?? LocalTaskSource(),
       _notificationService = notificationService ?? NotificationService(),
       _firestoreService = firestoreService ?? FirestoreService(),
       _connectivityService = connectivityService ?? ConnectivityService(),
       _analyticsService = analyticsService ?? AnalyticsService();
  Timer? _widgetDebounce;
  bool _widgetUpdateInProgress = false;
  bool get isLoading => _isLoading;

  Task? _taskToEdit;
  Task? get taskToEdit => _taskToEdit;

  void clearTaskToEdit() {
    _taskToEdit = null;
    notifyListeners();
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Initialize the provider and its dependencies.
  ///
  /// Sets up listeners for authentication changes, connectivity, and Firestore streams.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final sortIndex = prefs.getInt('sort_option');
    if (sortIndex != null && sortIndex < TaskSortOption.values.length) {
      _currentSortOption = TaskSortOption.values[sortIndex];
    }
    _selectedCategoryIds = prefs.getStringList('category_filters') ?? [];
    _showCompleted = prefs.getBool('show_completed') ?? true;
    _searchQuery = '';

    _monthWidgetService = MonthWidgetService(_calendarService, _source);
    _fullCalendarWidgetService = FullCalendarWidgetService(
      _calendarService,
      _source,
    );
    _widgetDataService = WidgetDataService(_calendarService);

    // Initialize schedule service for ROCIs-Schedule integration
    await _widgetDataService.initScheduleService();
    await _fullCalendarWidgetService.initScheduleService();

    // Initialize pagination service
    _taskPagination = PaginationService<Task>(_getFilteredAndSortedTasks);
    // Don't initialize yet - wait for source init

    try {
      await _source.init();
      _taskPagination.initialize();
      await _notificationService.init();
      await _notificationService.requestPermissions();
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Initialization failed');
      _setError('Failed to initialize app data. Please restart.');
    }

    _refreshPagination();

    await _notificationService.cancelAllNotifications();

    // Initialize RevenueCat SDK
    await _subscriptionService.init();

    // Listen to subscription changes
    _subscriptionService.addListener(notifyListeners);

    // Defer notification rescheduling to not block startup
    Future.delayed(const Duration(seconds: 2), () async {
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
          } catch (e, s) {
            _errorHandlingService.logError(
              e,
              s,
              reason: 'Rescheduling notification',
            );
          }
        }
      }
    });

    // Initialize connectivity service
    await _connectivityService.init();

    // Listen to connectivity changes to sync when coming back online
    _connectivitySubscription =
        _connectivityService.addListener(() {
              if (_connectivityService.isOnline &&
                  _authService.currentUser != null) {
                // Network restored - attempting sync
                syncWithCloud();
              }
            })
            as StreamSubscription?;

    _lastUserId = _authService.currentUser?.uid;
    _authSubscription = _authService.authStateChanges.listen((
      User? user,
    ) async {
      if (user != null) {
        _lastUserId = user.uid;
        _firestoreService.setUserId(user.uid);
        
        // Refresh pagination to show Hive data for the user
        _refreshPagination();
        
        // Always attempt sync - Firestore handles offline state
        uploadLocalDataToCloud();
        syncWithCloud();
      } else {
        // Only clear if we were previously logged in (_lastUserId was set)
        if (_lastUserId != null) {
          AppLogger.info('User signed out, clearing local data...', tag: 'Tasks');
          _firestoreService.setUserId(null);
          await _cancelSubscriptions();
          await _source.clearAll();
          updateHomeWidget();
          _lastUserId = null;
        }
      }
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();

    // Defer home widget update - show notification on app first open
    Future.delayed(
      const Duration(seconds: 1),
      () async => await updateHomeWidgetWithNotification(),
    );

    if (_authService.currentUser != null) {
      _firestoreService.setUserId(_authService.currentUser!.uid);
      _refreshPagination();
      
      // Attempt sync in background - Firestore handles offline state
      uploadLocalDataToCloud()
          .then((_) => syncWithCloud())
          .then((_) => updateHomeWidget())
          .catchError((e, s) {
            _errorHandlingService.logError(e, s, reason: 'Initial sync');
          });
    }

    _notificationSubscription = _notificationService.onNotificationResponse
        .listen((response) {
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
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Navigating to task');
    }
  }

  Future<void> _snoozeTask(String taskId) async {
    try {
      final task = _source.getTasks().firstWhere((t) => t.id == taskId);
      if (task.dueDate != null) {
        final newDate = task.dueDate!.add(const Duration(minutes: 15));
        await updateTask(task, dueDate: newDate);
      }
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Snoozing task');
    }
  }

  Future<void> _completeTaskFromNotification(String taskId) async {
    try {
      final task = _source.getTasks().firstWhere((t) => t.id == taskId);
      if (!task.isCompleted) {
        await toggleTaskCompletion(task);
      }
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Completing task from notification',
      );
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
    _notificationSubscription?.cancel();
    _widgetDebounce?.cancel();
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
      // Successfully uploaded local data to cloud
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Uploading local data to cloud',
      );
    }
  }

  Future<void> syncWithCloud() async {
    if (_authService.currentUser == null) return;

    // Remove isOnline check to allow Firestore cache to provide data

    await _cancelSubscriptions();
    try {
      _tasksSubscription = _firestoreService.getActiveTasksStream().listen(
        (events) async {
          bool needsUpdate = false;
          for (var event in events) {
            final cloudTask = event.task;
            
            if (event.type == SyncEventType.removed) {
              // If it's removed from active, it might be completed or deleted.
              // We update local DB to reflect the new state (completed/deleted).
              await _source.addTask(cloudTask);
            } else {
              // Added or modified
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
            needsUpdate = true;
          }
          
          if (needsUpdate) {
            _refreshPagination();
            notifyListeners();
            updateHomeWidget();
          }
        },
        onError: (error, stackTrace) {
          _errorHandlingService.logError(
            error,
            stackTrace,
            reason: 'Tasks stream error',
          );
        },
      );

      _categoriesSubscription = _firestoreService.getCategoriesStream().listen(
        (cloudCategories) async {
          for (var cloudCategory in cloudCategories) {
            await _source.addCategory(cloudCategory);
          }
          _refreshPagination();
          notifyListeners();
        },
        onError: (error, stackTrace) {
          _errorHandlingService.logError(
            error,
            stackTrace,
            reason: 'Categories stream error',
          );
        },
      );

      // Cloud sync started successfully
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Starting cloud sync');
    }
  }

  /// Performs a comprehensive sync:
  /// 1. Forces cloud sync for tasks and categories
  /// 2. Updates all home widgets with current data
  /// 3. Updates the global task count notification
  /// 4. Reschedules all task reminders to ensure they are up-to-date
  Future<void> performFullSync() async {
    try {
      // 1. Refresh data from cloud
      await syncWithCloud();

      // 2. Force widget updates and global notification refresh
      await updateHomeWidgetWithNotification();

      // 3. Reschedule all task notifications
      final allTasks = _source.getTasks();
      // First cancel existing to avoid duplicates or orphans
      await _notificationService.cancelAllNotifications();

      for (var task in allTasks) {
        if (!task.isCompleted &&
            !(task.isDeleted ?? false) &&
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
      }
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Performing full sync');
      rethrow;
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
    _refreshPagination();
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setInt('sort_option', option.index);
        })
        .catchError((e, s) {
          _errorHandlingService.logError(e, s, reason: 'Saving sort option');
        });
  }

  void toggleCategoryFilter(String categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId);
    }
    _refreshPagination();
    notifyListeners();
    _saveCategoryFilters();
  }

  void clearCategoryFilters() {
    _selectedCategoryIds = [];
    _refreshPagination();
    notifyListeners();
    _saveCategoryFilters();
  }

  void _saveCategoryFilters() {
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setStringList('category_filters', _selectedCategoryIds);
        })
        .catchError((e, s) {
          _errorHandlingService.logError(
            e,
            s,
            reason: 'Saving category filters',
          );
        });
  }

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _refreshPagination();
    notifyListeners();
  }

  void toggleShowCompleted(bool value) {
    _showCompleted = value;
    _refreshPagination();
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setBool('show_completed', value);
        })
        .catchError((e, s) {
          _errorHandlingService.logError(
            e,
            s,
            reason: 'Saving show completed preference',
          );
        });
  }

  List<Task> get tasks {
    if (_isLoading) return [];
    return _taskPagination.items;
  }

  /// Get all tasks without pagination (for internal use)
  List<Task> _getFilteredAndSortedTasks() {
    var tasks = _source
        .getTasks()
        .where((t) => !(t.isDeleted ?? false))
        .toList();

    if (_searchQuery.isNotEmpty) {
      tasks = tasks
          .where(
            (t) =>
                t.title.toLowerCase().contains(_searchQuery) ||
                t.description.toLowerCase().contains(_searchQuery),
          )
          .toList();
    }

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

  // Pagination methods
  bool get hasMoreTasks => _taskPagination.hasMoreItems;
  bool get isLoadingMoreTasks => _taskPagination.isLoading;
  int get currentTaskPage => _taskPagination.currentPage;
  int get totalTaskPages => _taskPagination.totalPages;
  int get totalTaskCount => _taskPagination.totalItems;

  /// Load more tasks (for infinite scroll)
  Future<void> loadMoreTasks() async {
    await _taskPagination.loadNextPage();
    
    // If we've exhausted local tasks and are showing completed tasks, fetch more from Firestore
    if (!_taskPagination.hasMoreItems && 
        _showCompleted && 
        _authService.currentUser != null) {
      
      final moreTasks = await _firestoreService.getNextCompletedTasksBatch();
      if (moreTasks.isNotEmpty) {
        for (var task in moreTasks) {
          await _source.addTask(task);
        }
        _refreshPagination();
      }
    }
    
    notifyListeners();
  }

  /// Check if should load more tasks based on scroll position
  bool shouldLoadMoreTasks(int index) {
    return _taskPagination.shouldLoadMore(index);
  }

  /// Refresh pagination when data changes
  void _refreshPagination() {
    _taskPagination.refresh();
  }

  /// Update home widgets without showing the task count notification
  /// Use this for general widget updates (color changes, pin/unpin, etc.)
  Future<void> updateHomeWidget() async {
    await _updateWidgets(showNotification: false);
  }

  /// Update home widgets AND show the task count notification
  /// Use this only when tasks are added, completed, or deleted
  Future<void> updateHomeWidgetWithNotification() async {
    await _updateWidgets(showNotification: true);
  }

  /// Internal method to update widgets with optional notification
  Future<void> _updateWidgets({required bool showNotification}) async {
    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(
      Duration(milliseconds: AppConfig.notificationDebounceMs),
      () async {
        if (_widgetUpdateInProgress) return;
        _widgetUpdateInProgress = true;
        try {
          final chartPath = await TaskWidgetService.updateTaskWidget(
            _source.getTasks(),
            getCategoryById,
            isDarkText: !_themeService.isDarkMode,
          );

          // Only show notification when explicitly requested
          // (task added, completed, deleted, or app first opened)
          if (showNotification) {
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
          }

          // Get current user ID and email for ROCIs-Schedule integration
          final userId = _authService.currentUser?.uid;
          final userEmail = _authService.currentUser?.email;

          // Set user email for cross-app schedule data lookup
          _widgetDataService.setUserEmail(userEmail);
          _fullCalendarWidgetService.setUserEmail(userEmail);

          await _widgetDataService.updateMonthEventsMap(
            _source.getTasks(),
            userId: userId,
          );
          await _widgetDataService.updateScheduleWidget(
            _source.getTasks(),
            getCategoryById,
            userId: userId,
          );
          await _widgetDataService.updateCalendarListWidget(
            _source.getTasks(),
            userId: userId,
          );

          await _monthWidgetService.updateMonthWidget();
          await _fullCalendarWidgetService.updateFullCalendarWidget(
            userId: userId,
          );
        } catch (e, s) {
          _errorHandlingService.logError(e, s, reason: 'Updating home widgets');
        } finally {
          _widgetUpdateInProgress = false;
        }
      },
    );
  }

  /// Add a new task to local storage and sync with cloud.
  Future<void> addTask(
    String title,
    String description,
    DateTime? dueDate,
    TaskPriority priority,
    String? category, {
    List<SubTask>? subTasks,
    String? recurrenceRule,
  }) async {
    final task = Task(
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      categoryId: category,
      subTasks: subTasks,
      recurrenceRule: recurrenceRule,
    );
    await _source.addTask(task);
    // Sync to cloud - Firestore handles offline state and buffering
    _firestoreService.addTask(task).catchError((e, s) {
      _errorHandlingService.logError(e, s, reason: 'Background cloud addTask failed');
    });

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
      } catch (e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Scheduling notification for new task',
        );
        // Not critical enough to show error, but good to know
      }
    }
    _refreshPagination();
    notifyListeners();
    updateHomeWidgetWithNotification(); // Show notification when task is added

    // Log analytics
    await _analyticsService.logTaskCreated(
      categoryId: category ?? 'none',
      hasDueDate: dueDate != null,
    );
  }

  Future<void> toggleTaskCompletion(Task task) async {
    task.isCompleted = !task.isCompleted;

    // Handle Recurrence if marking as completed
    if (task.isCompleted &&
        task.recurrenceRule != null &&
        task.recurrenceRule!.isNotEmpty) {
      await _handleRecurringTask(task);
    }

    notifyListeners();
    await _source.addTask(task);
    _firestoreService.updateTask(task).catchError((e, s) {
      _errorHandlingService.logError(e, s, reason: 'Background cloud updateTask failed');
    });


    if (task.isCompleted) {
      await _notificationService.cancelNotification(
        NotificationService.getNotificationId(task.id),
      );
    } else if (task.dueDate != null && task.dueDate!.isAfter(DateTime.now())) {
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
      } catch (e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Rescheduling notification after un-completing task',
        );
      }
    }
    _refreshPagination();
    notifyListeners();
    updateHomeWidgetWithNotification(); // Show notification when task is completed/uncompleted

    if (task.isCompleted) {
      await _analyticsService.logTaskCompleted(taskId: task.id);
    }
  }

  Future<void> updateTask(
    Task task, {
    String? title,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    String? categoryId,
    List<SubTask>? subTasks,
    String? recurrenceRule,
  }) async {
    if (title != null) task.title = title;
    if (description != null) task.description = description;
    if (dueDate != null) task.dueDate = dueDate;
    if (priority != null) task.priority = priority;
    if (categoryId != null) task.categoryId = categoryId;
    if (subTasks != null) task.subTasks = subTasks;
    if (recurrenceRule != null) task.recurrenceRule = recurrenceRule;

    await _source.addTask(task);
    _firestoreService.updateTask(task).catchError((e, s) {
      _errorHandlingService.logError(e, s, reason: 'Background cloud updateTask failed');
    });

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
      } catch (e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Rescheduling notification after task update',
        );
      }
    }
    _refreshPagination();
    notifyListeners();
    updateHomeWidget();
  }

  Future<void> toggleSubTask(Task task, String subTaskId) async {
    if (task.subTasks == null) return;

    final index = task.subTasks!.indexWhere((st) => st.id == subTaskId);
    if (index != -1) {
      task.subTasks![index].isCompleted = !task.subTasks![index].isCompleted;
      await _source.addTask(task);
      _refreshPagination();
      notifyListeners();

      // Sync to cloud in background - no isOnline check needed as Firestore handles buffering
      _firestoreService.addTask(task).catchError((e, s) {
        _errorHandlingService.logError(e, s, reason: 'Cloud addTask failed');
      });
      
      updateHomeWidget();
    }
  }

  Future<void> toggleTaskPin(Task task) async {
    task.isPinned = !(task.isPinned ?? false);
    notifyListeners();
    await _source.addTask(task);
    _firestoreService.updateTask(task).catchError((e, s) {
      _errorHandlingService.logError(e, s, reason: 'Background cloud updateTask failed');
    });
    _refreshPagination();
    notifyListeners();
    updateHomeWidget();
  }

  Future<void> deleteTask(String id) async {
    try {
      final task = _source.getTasks().firstWhere((t) => t.id == id);
      task.isDeleted = true;
      await _source.addTask(task);
      _firestoreService.updateTask(task).catchError((e, s) {
        _errorHandlingService.logError(e, s, reason: 'Background cloud updateTask failed');
      });
      await _notificationService.cancelNotification(
        NotificationService.getNotificationId(id),
      );
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Deleting task');
    }
    _refreshPagination();
    notifyListeners();
    updateHomeWidgetWithNotification(); // Show notification when task is deleted

    await _analyticsService.logTaskDeleted(taskId: id);
  }

  Future<void> restoreTask(Task task) async {
    task.isDeleted = false;
    await _source.addTask(task);
    _firestoreService.updateTask(task).catchError((e, s) {
      _errorHandlingService.logError(e, s, reason: 'Background cloud updateTask failed');
    });
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
      } catch (e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Rescheduling notification after task restoration',
        );
      }
    }
    _refreshPagination();
    notifyListeners();
    updateHomeWidgetWithNotification(); // Show notification when task is restored
  }

  Future<void> deleteTaskPermanently(String id) async {
    await _source.deleteTask(id);
    _firestoreService.deleteTask(id).catchError((e, s) {
      _errorHandlingService.logError(e, s, reason: 'Background cloud deleteTask failed');
    });
    await _notificationService.cancelNotification(
      NotificationService.getNotificationId(id),
    );
    _refreshPagination();
    notifyListeners();
    updateHomeWidgetWithNotification(); // Show notification when task is permanently deleted

    await _analyticsService.logTaskDeleted(taskId: id);
  }

  Future<void> clearTrash() async {
    final tasksToDelete = deletedTasks;
    for (var task in tasksToDelete) {
      await _source.deleteTask(task.id);
      _firestoreService.deleteTask(task.id).catchError((e, s) {
        _errorHandlingService.logError(e, s, reason: 'Background cloud bulk deleteTask failed');
      });
      await _notificationService.cancelNotification(
        NotificationService.getNotificationId(task.id),
      );
    }
    _refreshPagination();
    notifyListeners();
    updateHomeWidgetWithNotification();
  }

  bool get canAddCategory {
    if (_subscriptionService.isPremium) return true;
    return categories.length < AppConfig.freeCategoryLimit;
  }

  Future<void> addCategory(String name, int colorValue, int iconCode) async {
    if (!canAddCategory) {
      throw Exception('Category limit reached');
    }

    final sanitizedName = ValidationService.sanitizeText(name);
    final category = Category(
      name: sanitizedName,
      colorValue: colorValue,
      iconCode: iconCode,
    );
    await _source.addCategory(category);
    try {
      await _firestoreService.addCategory(category);
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Adding category to firestore',
      );
    }
    notifyListeners();

    await _analyticsService.logCategoryCreated(name: name);
  }

  Future<void> updateCategory(
    Category category, {
    String? name,
    int? colorValue,
    int? iconCode,
  }) async {
    if (name != null) category.name = ValidationService.sanitizeText(name);
    if (colorValue != null) category.colorValue = colorValue;
    if (iconCode != null) category.iconCode = iconCode;
    await _source.updateCategory(category);
    try {
      await _firestoreService.updateCategory(category);
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Updating category in firestore',
      );
    }
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await _source.deleteCategory(id);
    try {
      await _firestoreService.deleteCategory(id);
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Deleting category from firestore',
      );
    }
    notifyListeners();
  }

  Category? getCategoryById(String? id) {
    if (id == null) return null;

    try {
      final category = _source.getCategories().firstWhere((c) => c.id == id);
      return category;
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Getting category by id: $id',
      );
      return null;
    }
  }

  Future<void> _handleRecurringTask(Task task) async {
    if (task.dueDate == null) return;

    // Only premium users get recurrence
    if (!_subscriptionService.isPremium) return;

    DateTime? nextDate;
    try {
      final rrule = RecurrenceRule.fromString(task.recurrenceRule!);
      // Find the next instance after the current due date
      final instances = rrule.getInstances(start: task.dueDate!.toUtc());

      // getInstances includes the start date if it matches the rule.
      // We want the VERY NEXT one.
      nextDate = instances
          .firstWhere(
            (date) => date.isAfter(task.dueDate!.toUtc()),
            orElse: () => task.dueDate!.add(const Duration(days: 1)).toUtc(),
          )
          .toLocal();
    } catch (e) {
      // Fallback to daily if parsing fails
      nextDate = task.dueDate!.add(const Duration(days: 1));
    }

    await addTask(
      task.title,
      task.description,
      nextDate,
      task.priority,
      task.categoryId,
      subTasks: task.subTasks
          ?.map((st) => st.copyWith(isCompleted: false))
          .toList(),
      recurrenceRule: task.recurrenceRule,
    );

    // Show feedback notification
    await _notificationService.showInfoNotification(
      title: 'Recurring Task Scheduled',
      body:
          'Next occurrence of "${task.title}" set for ${DateFormat.yMd().format(nextDate)}',
    );
  }
}
