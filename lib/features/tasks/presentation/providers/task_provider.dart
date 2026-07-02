import 'package:flutter/foundation.dart' hide Category;
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/l10n/l10n_helper.dart';
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
import 'package:rocis_tasks/core/services/google_tasks_service.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/pagination_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';

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
import 'package:rocis_tasks/core/services/security_service.dart';

enum TaskSortOption { dueDate, priority, title, dateCreated }

enum DateTimeFilterOption { all, today, thisWeek, overdue, noDate }

/// Main provider for task management and synchronization.
///
/// This class handles local persistence via Hive, cloud synchronization via Firestore,
/// and coordination between various services (notifications, widgets, etc.).
class TaskProvider extends ChangeNotifier {
  static const int _maxNagNotifications = 5;
  AppLocalizations get _l10n {
    final currentLocale = _themeService.locale ?? PlatformDispatcher.instance.locale;
    return getSafeAppLocalizations(currentLocale);
  }

  final LocalTaskSource _source;
  final NotificationService _notificationService;
  final FirestoreService _firestoreService;
  final ConnectivityService _connectivityService;
  final AnalyticsService _analyticsService;
  final AuthService _authService;
  final CalendarService _calendarService;
  final GoogleTasksService _googleTasksService;
  final ThemeService _themeService;
  final ErrorHandlingService _errorHandlingService;
  final SubscriptionService _subscriptionService;
  final PrivateModeService _privateModeService;
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
  String? _completedPrefetchUserId;
  bool _completedPrefetchInFlight = false;

  // Guard against Firestore stream reverting local toggles.
  // Maps task ID → the isCompleted state we just wrote locally.
  final Map<String, bool> _pendingLocalWrites = {};

  // Bulk Selection State
  bool _isSelectionMode = false;
  final List<String> _selectedTaskIds = [];

  bool get isSelectionMode => _isSelectionMode;
  List<String> get selectedTaskIds => _selectedTaskIds;
  int get selectedCount => _selectedTaskIds.length;

  TaskProvider(
    this._authService,
    this._calendarService,
    this._googleTasksService,
    this._themeService,
    this._errorHandlingService,
    this._subscriptionService, {
    PrivateModeService? privateModeService,
    LocalTaskSource? source,
    NotificationService? notificationService,
    FirestoreService? firestoreService,
    ConnectivityService? connectivityService,
    AnalyticsService? analyticsService,
  }) : _privateModeService = privateModeService ?? PrivateModeService(),
       _source = source ?? LocalTaskSource(),
       _notificationService = notificationService ?? NotificationService(),
       _firestoreService = firestoreService ?? FirestoreService(),
       _connectivityService = connectivityService ?? ConnectivityService(),
       _analyticsService = analyticsService ?? AnalyticsService();
  Timer? _widgetDebounce;
  bool _widgetUpdateInProgress = false;
  bool _pendingWidgetUpdate = false;
  bool get isLoading => _isLoading;

  // Security prompt for private task/category creation
  bool _showSecurityPrompt = false;
  bool get showSecurityPrompt => _showSecurityPrompt;
  void clearSecurityPrompt() {
    _showSecurityPrompt = false;
  }

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
    final dateFilterIndex = prefs.getInt('date_filter');
    if (dateFilterIndex != null &&
        dateFilterIndex < DateTimeFilterOption.values.length) {
      _currentDateFilter = DateTimeFilterOption.values[dateFilterIndex];
    }
    _selectedCategoryIds = prefs.getStringList('category_filters') ?? [];
    _showCompleted = prefs.getBool('show_completed') ?? true;
    _advancedRemindersEnabled =
        prefs.getBool('advanced_reminders_enabled') ?? false;
    _nagRemindersEnabled = prefs.getBool('nag_reminders_enabled') ?? false;
    _nagIntervalMinutes = prefs.getInt('nag_interval_minutes') ?? 15;
    _nagCount = prefs.getInt('nag_count') ?? 3;
    _quietHoursEnabled = prefs.getBool('quiet_hours_enabled') ?? false;
    _quietStartMinutes = prefs.getInt('quiet_start_minutes') ?? (22 * 60);
    _quietEndMinutes = prefs.getInt('quiet_end_minutes') ?? (7 * 60);
    _showMyTasksGuideShortcut =
        prefs.getBool('show_my_tasks_guide_shortcut') ?? true;
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
      await _clearDeprecatedRecurringTaskData();
      await _notificationService.init();
      await _notificationService.requestPermissions();
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Initialization failed');
      _setError(_l10n.initializationFailedError);
    }

    _refreshPagination();

    await _notificationService.cancelAllNotifications();

    // Initialize RevenueCat SDK
    await _subscriptionService.init();

    // Listen to subscription changes
    _subscriptionService.addListener(notifyListeners);
    _privateModeService.addListener(_onPrivateModeChanged);

    // Defer notification rescheduling to not block startup
    Future.delayed(const Duration(seconds: 2), () async {
      final allTasks = _source.getTasks();
      for (final task in allTasks) {
        try {
          await _scheduleTaskNotifications(task);
        } catch (e, s) {
          _errorHandlingService.logError(
            e,
            s,
            reason: 'Rescheduling notification',
          );
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
        unawaited(_prefetchCompletedTasksIfNeeded());
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
      unawaited(_prefetchCompletedTasksIfNeeded());
    }

    _notificationSubscription = _notificationService.onNotificationResponse
        .listen((response) {
          final payload = response.payload;
          if (payload != null) {
            final taskId = payload;
            final actionId = response.actionId;
            if (actionId != null && actionId.startsWith('snooze')) {
              _snoozeTask(taskId, actionId);
            } else if (actionId == 'complete') {
              _completeTaskFromNotification(taskId);
            } else if (actionId == 'open_task') {
              _navigateToTask(taskId);
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

  Future<void> _snoozeTask(String taskId, String? actionId) async {
    try {
      final task = _source.getTasks().firstWhere((t) => t.id == taskId);
      if (task.dueDate != null) {
        final newDate = _getSnoozedDate(task.dueDate!, actionId);
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

  DateTime _getSnoozedDate(DateTime base, String? actionId) {
    if (actionId == 'snooze_10') {
      return base.add(const Duration(minutes: 10));
    }
    if (actionId == 'snooze_60') {
      return base.add(const Duration(hours: 1));
    }
    if (actionId == 'snooze_tomorrow_morning') {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day).add(
        const Duration(days: 1),
      );
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
    }
    return base.add(const Duration(minutes: 15));
  }

  DateTime _applyQuietHours(DateTime date) {
    if (!quietHoursEnabled) return date;
    final start = _quietStartMinutes;
    final end = _quietEndMinutes;
    if (start == end) return date;

    final minutes = date.hour * 60 + date.minute;
    final spansMidnight = start > end;
    final inQuiet = spansMidnight
        ? (minutes >= start || minutes < end)
        : (minutes >= start && minutes < end);

    if (!inQuiet) return date;

    final endHour = end ~/ 60;
    final endMinute = end % 60;
    final endDate = (spansMidnight && minutes >= start)
        ? date.add(const Duration(days: 1))
        : date;
    return DateTime(endDate.year, endDate.month, endDate.day, endHour, endMinute);
  }

  List<int> _getNotificationIdsForTask(Task task) {
    final baseId = NotificationService.getNotificationId(task.id);
    final ids = <int>[baseId];
    for (var i = 1; i <= _maxNagNotifications; i++) {
      ids.add(NotificationService.getNotificationId('${task.id}_nag_$i'));
    }
    return ids;
  }

  Future<void> _cancelTaskNotifications(Task task) async {
    final ids = _getNotificationIdsForTask(task);
    for (final id in ids) {
      await _notificationService.cancelNotification(id);
    }
  }

  Future<void> _cancelTaskNotificationsById(String taskId) async {
    final ids = <int>[NotificationService.getNotificationId(taskId)];
    for (var i = 1; i <= _maxNagNotifications; i++) {
      ids.add(NotificationService.getNotificationId('${taskId}_nag_$i'));
    }
    for (final id in ids) {
      await _notificationService.cancelNotification(id);
    }
  }

  Future<void> _scheduleTaskNotifications(Task task) async {
    if (task.isCompleted || (task.isDeleted ?? false)) return;
    if (task.skipReminders) return;
    if (task.dueDate == null) return;
    if (!task.dueDate!.isAfter(DateTime.now())) return;

    await _cancelTaskNotifications(task);

    if (_subscriptionService.isPremium &&
        task.requireSubTasksBeforeReminders &&
        (task.subTasks?.isNotEmpty ?? false) &&
        (task.subTasks?.any((st) => !st.isCompleted) ?? false)) {
      return;
    }

    final isPrivate = _isPrivateTask(task);
    final shouldHide =
        _shouldMaskPrivateContent() && isPrivate;

    final title = shouldHide
        ? _l10n.taskReminderTitle(_l10n.privateLabel)
        : _l10n.taskReminderTitle(task.title);
    final body = shouldHide
        ? _l10n.taskDueNowBody
        : (task.description.isNotEmpty ? task.description : _l10n.taskDueNowBody);

    final actions = <AndroidNotificationAction>[
      if (advancedRemindersEnabled) ...[
        AndroidNotificationAction(
          'snooze_10',
          _l10n.snooze10m,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze',
          _l10n.notificationSnooze,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze_60',
          _l10n.snooze1h,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze_tomorrow_morning',
          _l10n.tomorrowAtNine,
          showsUserInterface: true,
        ),
      ] else ...[
        AndroidNotificationAction(
          'snooze',
          _l10n.notificationSnooze,
          showsUserInterface: true,
        ),
      ],
      AndroidNotificationAction(
        'complete',
        _l10n.notificationMarkCompleted,
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        'open_task',
        _l10n.notificationOpenTask,
        showsUserInterface: true,
      ),
    ];

    final baseScheduledDate = _applyQuietHours(task.dueDate!);
    if (!baseScheduledDate.isAfter(DateTime.now())) return;

    await _notificationService.scheduleNotification(
      id: NotificationService.getNotificationId(task.id),
      title: title,
      body: body,
      scheduledDate: baseScheduledDate,
      taskId: task.id,
      androidActions: actions,
    );

    if (nagRemindersEnabled) {
      final effectiveCount = _nagCount.clamp(0, _maxNagNotifications);
      final effectiveInterval = _nagIntervalMinutes.clamp(1, 24 * 60);
      final scheduledTimes = <int>{baseScheduledDate.millisecondsSinceEpoch};

      for (var i = 1; i <= effectiveCount; i++) {
        final rawDate = baseScheduledDate.add(
          Duration(minutes: effectiveInterval * i),
        );
        final scheduledDate = _applyQuietHours(rawDate);
        if (!scheduledDate.isAfter(DateTime.now())) continue;
        if (!scheduledTimes.add(scheduledDate.millisecondsSinceEpoch)) continue;
        await _notificationService.scheduleNotification(
          id: NotificationService.getNotificationId('${task.id}_nag_$i'),
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          taskId: task.id,
          androidActions: actions,
        );
      }
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _tasksSubscription?.cancel();
    await _categoriesSubscription?.cancel();
    _tasksSubscription = null;
    _categoriesSubscription = null;
  }

  void _onPrivateModeChanged() {
    _refreshPagination();
    notifyListeners();
    updateHomeWidget();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _notificationSubscription?.cancel();
    _widgetDebounce?.cancel();
    _privateModeService.removeListener(_onPrivateModeChanged);
    _cancelSubscriptions();
    super.dispose();
  }

  Future<void> uploadLocalDataToCloud() async {
    if (_authService.currentUser == null) return;

    try {
      final tasks = _source.getTasks();
      final categories = _source.getCategories();
      for (final category in categories) {
        await _firestoreService.addCategory(category);
      }
      for (final task in tasks) {
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

  Future<void> _prefetchCompletedTasksIfNeeded() async {
    if (!_showCompleted) return;
    final user = _authService.currentUser;
    if (user == null) return;
    if (_completedPrefetchInFlight) return;

    final hasAnyCompletedLocally = _source
        .getTasks()
        .any((t) => t.isCompleted && !(t.isDeleted ?? false));
    if (_completedPrefetchUserId == user.uid && hasAnyCompletedLocally) {
      return;
    }

    _completedPrefetchInFlight = true;
    try {
      final completed = await _firestoreService.getNextCompletedTasksBatch();
      if (completed.isEmpty) {
        _completedPrefetchUserId = user.uid;
        return;
      }

      for (final task in completed) {
        await _source.addTask(task);
      }
      _completedPrefetchUserId = user.uid;
      _refreshPagination();
      notifyListeners();
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Prefetch completed tasks');
    } finally {
      _completedPrefetchInFlight = false;
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
          for (final event in events) {
            final cloudTask = event.task;
            
            // If we just toggled this task locally, don't let a stale
            // Firestore snapshot revert our write.
            final pendingState = _pendingLocalWrites[cloudTask.id];
            if (pendingState != null) {
              // For removed events the snapshot may still show the old state;
              // for added/modified events the snapshot may lag behind.
              if (event.type == SyncEventType.removed && pendingState) {
                // We just completed this task — the removed event is expected.
                // Update Hive to reflect completion.
                final (latestTask, isMissing) =
                    await _firestoreService.fetchTaskById(cloudTask.id);
                if (latestTask != null && latestTask.isCompleted) {
                  await _source.addTask(latestTask);
                  await _cancelTaskNotificationsById(latestTask.id);
                  needsUpdate = true;
                }
                continue;
              }
              if (event.type != SyncEventType.removed && !pendingState) {
                // We just uncompleted this task — ignore the stale cloud event.
                continue;
              }
            }
            
            if (event.type == SyncEventType.removed) {
              // If it's removed from active, it might be completed or deleted.
              // DocumentChange.removed gives the *previous* state (still active),
              // so we must fetch the latest document to avoid reverting completion/deletion.
              final (latestTask, isMissing) =
                  await _firestoreService.fetchTaskById(cloudTask.id);
              if (latestTask != null) {
                await _source.addTask(latestTask);
                if (latestTask.isCompleted || (latestTask.isDeleted ?? false)) {
                  await _cancelTaskNotificationsById(latestTask.id);
                }
              } else if (isMissing) {
                await _source.deleteTask(cloudTask.id);
                await _cancelTaskNotificationsById(cloudTask.id);
              } else {
                continue;
              }
            } else {
              // Added or modified
              await _source.addTask(cloudTask);

              if (cloudTask.isCompleted || (cloudTask.isDeleted ?? false)) {
                await _cancelTaskNotificationsById(cloudTask.id);
              } else {
                await _scheduleTaskNotifications(cloudTask);
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
          for (final cloudCategory in cloudCategories) {
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

      await _processGoogleCalendarUpstreamRocisTasksHook();

      // 2. Force widget updates and global notification refresh
      await updateHomeWidgetWithNotification();

      // 3. Reschedule all task notifications
      final allTasks = _source.getTasks();
      // First cancel existing to avoid duplicates or orphans
      await _notificationService.cancelAllNotifications();

      for (final task in allTasks) {
        await _scheduleTaskNotifications(task);
      }
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Performing full sync');
      rethrow;
    }
  }

  bool _looksLikeGoogleCalendar(dynamic calendar) {
    try {
      final accountType = (calendar.accountType as String?)?.toLowerCase();
      final accountName = (calendar.accountName as String?)?.toLowerCase();
      final name = (calendar.name as String?)?.toLowerCase();

      return (accountType?.contains('google') ?? false) ||
          (accountType?.contains('com.google') ?? false) ||
          (accountName?.contains('gmail') ?? false) ||
          (name?.contains('google') ?? false);
    } catch (_) {
      return false;
    }
  }

  Future<void> _processGoogleCalendarUpstreamRocisTasksHook() async {
    if (!_subscriptionService.isPremium) return;

    try {
      final calendars = await _calendarService.getAvailableCalendars();
      final googleWritableCalendarIds = calendars
          .where((c) => c.id != null && c.isReadOnly != true)
          .where(_looksLikeGoogleCalendar)
          .map((c) => c.id!)
          .toList();
      if (googleWritableCalendarIds.isEmpty) return;

      final now = DateTime.now();
      final events = await _calendarService.getEvents(
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.add(const Duration(days: 365)),
        calendarIds: googleWritableCalendarIds,
      );
      if (events.isEmpty) return;

      var createdAny = false;
      for (final event in events) {
        final title = event.title;
        if (title == null || title.isEmpty) continue;

        final hasMarker =
            title.contains('[ROCIsTasks]') || title.contains('[RT]');
        if (!hasMarker) continue;

        final calendarId = event.calendarId;
        final eventId = event.eventId;
        final start = event.start;
        if (calendarId == null || eventId == null || start == null) continue;

        final end = event.end ?? start.add(const Duration(hours: 1));
        final taskTitle = _stripRocisTasksMarkers(title);
        final taskDescription = _buildImportedTaskDescription(
          eventDescription: event.description,
          start: start,
          end: end,
          isAllDay: event.allDay == true,
        );

        final deleted = await _calendarService.deleteEvent(
          calendarId: calendarId,
          eventId: eventId,
        );
        if (!deleted) continue;

        final task = Task(
          title: taskTitle,
          description: taskDescription,
          dueDate: start,
          priority: TaskPriority.medium,
          syncWithGoogleTasks: false,
        );
        await _source.addTask(task);
        _firestoreService.addTask(task).catchError((e, s) {
          _errorHandlingService.logError(
            e,
            s,
            reason: 'Background cloud addTask failed (calendar import)',
          );
        });
        if (task.dueDate != null && task.dueDate!.isAfter(DateTime.now())) {
          try {
            await _scheduleTaskNotifications(task);
          } catch (e, s) {
            _errorHandlingService.logError(
              e,
              s,
              reason: 'Scheduling notification for imported task',
            );
          }
        }

        createdAny = true;
      }

      if (createdAny) {
        _refreshPagination();
        notifyListeners();
        updateHomeWidget();
      }
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Processing upstream Google Calendar import hook',
      );
    }
  }

  String _stripRocisTasksMarkers(String title) {
    final stripped = title
        .replaceAll('[ROCIsTasks]', '')
        .replaceAll('[RT]', '')
        .trim();
    return stripped.isEmpty ? 'Task' : stripped;
  }

  String _buildImportedTaskDescription({
    required String? eventDescription,
    required DateTime start,
    required DateTime end,
    required bool isAllDay,
  }) {
    final base = (eventDescription ?? '').trim();
    final range = isAllDay
        ? '${DateFormat.yMMMd().format(start)} → ${DateFormat.yMMMd().format(end)}'
        : '${DateFormat.yMMMd().add_Hm().format(start)} → ${DateFormat.yMMMd().add_Hm().format(end)}';
    if (base.isEmpty) return range;
    return '$base\n\n$range';
  }

  TaskSortOption _currentSortOption = TaskSortOption.dueDate;
  DateTimeFilterOption _currentDateFilter = DateTimeFilterOption.all;
  List<String> _selectedCategoryIds = [];
  bool _showCompleted = true;
  bool _advancedRemindersEnabled = false;
  bool _nagRemindersEnabled = false;
  int _nagIntervalMinutes = 15;
  int _nagCount = 3;
  bool _quietHoursEnabled = false;
  int _quietStartMinutes = 22 * 60;
  int _quietEndMinutes = 7 * 60;
  bool _showMyTasksGuideShortcut = true;

  TaskSortOption get currentSortOption => _currentSortOption;
  DateTimeFilterOption get currentDateFilter => _currentDateFilter;
  List<String> get selectedCategoryIds => _selectedCategoryIds;
  bool get showCompleted => _showCompleted;
  bool get advancedRemindersEnabled =>
      _subscriptionService.isPremium && _advancedRemindersEnabled;
  bool get nagRemindersEnabled => _subscriptionService.isPremium && _nagRemindersEnabled;
  int get nagIntervalMinutes => _subscriptionService.isPremium ? _nagIntervalMinutes : 15;
  int get nagCount => _subscriptionService.isPremium ? _nagCount : 0;
  bool get quietHoursEnabled => _subscriptionService.isPremium && _quietHoursEnabled;
  int get quietStartMinutes => _quietStartMinutes;
  int get quietEndMinutes => _quietEndMinutes;
  bool get showMyTasksGuideShortcut => _showMyTasksGuideShortcut;

  Future<void> setShowMyTasksGuideShortcut(bool enabled) async {
    _showMyTasksGuideShortcut = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_my_tasks_guide_shortcut', enabled);
    notifyListeners();
  }

  Future<void> setAdvancedRemindersEnabled(bool enabled) async {
    _advancedRemindersEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('advanced_reminders_enabled', enabled);
    await performFullSync();
    notifyListeners();
  }

  Future<void> setNagRemindersEnabled(bool enabled) async {
    _nagRemindersEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nag_reminders_enabled', enabled);
    await performFullSync();
    notifyListeners();
  }

  Future<void> setNagIntervalMinutes(int minutes) async {
    _nagIntervalMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nag_interval_minutes', minutes);
    await performFullSync();
    notifyListeners();
  }

  Future<void> setNagCount(int count) async {
    _nagCount = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nag_count', count);
    await performFullSync();
    notifyListeners();
  }

  Future<void> setQuietHoursEnabled(bool enabled) async {
    _quietHoursEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quiet_hours_enabled', enabled);
    await performFullSync();
    notifyListeners();
  }

  Future<void> setQuietHoursStartMinutes(int minutes) async {
    _quietStartMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quiet_start_minutes', minutes);
    await performFullSync();
    notifyListeners();
  }

  Future<void> setQuietHoursEndMinutes(int minutes) async {
    _quietEndMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quiet_end_minutes', minutes);
    await performFullSync();
    notifyListeners();
  }

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

  void setDateFilter(DateTimeFilterOption option) {
    _currentDateFilter = option;
    _refreshPagination();
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setInt('date_filter', option.index);
        })
        .catchError((e, s) {
          _errorHandlingService.logError(e, s, reason: 'Saving date filter');
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
    if (value) {
      unawaited(_prefetchCompletedTasksIfNeeded());
    }
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

  /// Get all tasks for analytics (unfiltered, unpaginated)
  List<Task> get allTasks {
    if (_isLoading) return [];
    var tasks = _source.getTasks().where((t) => !(t.isDeleted ?? false)).toList();
    if (_shouldMaskPrivateContent()) {
      tasks = tasks.where((t) => !_isPrivateTask(t)).toList();
    }
    return tasks;
  }

  /// Get all tasks without pagination (for internal use)
  List<Task> _getFilteredAndSortedTasks() {
    var tasks = _source
        .getTasks()
        .where((t) => !(t.isDeleted ?? false))
        .toList();

    final maskPrivate = _shouldMaskPrivateContent();

    if (_searchQuery.isNotEmpty) {
      // Parse search symbols: @category #title !priority %date &subtask *status ?today
      final lowerQuery = _searchQuery.toLowerCase();

      // Extract symbol filters
      String? categoryFilter;
      String? titleFilter;
      String? priorityFilter;
      String? dateFilter;
      String? subtaskFilter;
      String? statusFilter;
      bool todayFilter = false;
      String freeText = lowerQuery;

      // Parse @category
      final categoryMatch = RegExp(r'@(\S+)').firstMatch(freeText);
      if (categoryMatch != null) {
        categoryFilter = categoryMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'@\S+'), '').trim();
      }

      // Parse #title
      final titleMatch = RegExp(r'#(\S+)').firstMatch(freeText);
      if (titleMatch != null) {
        titleFilter = titleMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'#\S+'), '').trim();
      }

      // Parse !priority
      final priorityMatch = RegExp(r'!(\S+)').firstMatch(freeText);
      if (priorityMatch != null) {
        priorityFilter = priorityMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'!\S+'), '').trim();
      }

      // Parse %date
      final dateMatch = RegExp(r'%(\S+)').firstMatch(freeText);
      if (dateMatch != null) {
        dateFilter = dateMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'%\S+'), '').trim();
      }

      // Parse &subtask
      final subtaskMatch = RegExp(r'&(\S+)').firstMatch(freeText);
      if (subtaskMatch != null) {
        subtaskFilter = subtaskMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'&\S+'), '').trim();
      }

      // Parse *status
      final statusMatch = RegExp(r'\*(\S+)').firstMatch(freeText);
      if (statusMatch != null) {
        statusFilter = statusMatch.group(1);
        freeText = freeText.replaceFirst(RegExp(r'\*\S+'), '').trim();
      }

      // Parse ?
      if (freeText.contains('?')) {
        todayFilter = true;
        freeText = freeText.replaceFirst('?', '').trim();
      }

      tasks = tasks.where((t) {
        // Free text search on title/description
        if (freeText.isNotEmpty) {
          final titleMatch = t.title.toLowerCase().contains(freeText);
          if (!titleMatch) {
            if (maskPrivate && _isPrivateTask(t)) return false;
            if (!t.description.toLowerCase().contains(freeText)) return false;
          }
        }

        // @category filter
        if (categoryFilter != null) {
          bool matched = false;
          if (t.categoryId != null) {
            final cat = getCategoryById(t.categoryId);
            if (cat != null && cat.name.toLowerCase().contains(categoryFilter)) {
              matched = true;
            }
          }
          if (!matched && t.categoryIds.isNotEmpty) {
            for (final id in t.categoryIds) {
              final cat = getCategoryById(id);
              if (cat != null && cat.name.toLowerCase().contains(categoryFilter)) {
                matched = true;
                break;
              }
            }
          }
          if (!matched) return false;
        }

        // #title filter
        if (titleFilter != null) {
          if (!t.title.toLowerCase().contains(titleFilter)) return false;
        }

        // !priority filter
        if (priorityFilter != null) {
          final priorityName = t.priority.name.toLowerCase();
          if (!priorityName.contains(priorityFilter)) return false;
        }

        // %date filter (matches date string like 2025-06-15 or partial)
        if (dateFilter != null && t.dueDate != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(t.dueDate!);
          if (!dateStr.contains(dateFilter)) return false;
        } else if (dateFilter != null && t.dueDate == null) {
          return false;
        }

        // &subtask filter
        if (subtaskFilter != null && subtaskFilter.isNotEmpty) {
          final filter = subtaskFilter;
          final hasMatchingSubtask = t.subTasks?.any(
            (st) => st.title.toLowerCase().contains(filter),
          ) ?? false;
          if (!hasMatchingSubtask) return false;
        }

        // *status filter
        if (statusFilter != null) {
          if (statusFilter == 'done' || statusFilter == 'completed') {
            if (!t.isCompleted) return false;
          } else if (statusFilter == 'pending' || statusFilter == 'active') {
            if (t.isCompleted) return false;
          }
        }

        // ? filter — tasks due today
        if (todayFilter) {
          if (t.dueDate == null) return false;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          if (t.dueDate!.year != today.year ||
              t.dueDate!.month != today.month ||
              t.dueDate!.day != today.day) {
            return false;
          }
        }

        return true;
      }).toList();
    }

    if (_selectedCategoryIds.isNotEmpty) {
      tasks = tasks
          .where((t) => _selectedCategoryIds.contains(t.categoryId) || t.categoryIds.any((id) => _selectedCategoryIds.contains(id)))
          .toList();
    }

    if (!_showCompleted) {
      tasks = tasks.where((t) {
        if (maskPrivate && _isPrivateTask(t)) return true;
        return !t.isCompleted;
      }).toList();
    }

    // Apply Date Filter
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));

    switch (_currentDateFilter) {
      case DateTimeFilterOption.today:
        tasks = tasks.where((t) {
          if (maskPrivate && _isPrivateTask(t)) return true;
          if (t.dueDate == null) return false;
          final d = t.dueDate!;
          return d.year == today.year && d.month == today.month && d.day == today.day;
        }).toList();
        break;
      case DateTimeFilterOption.thisWeek:
        tasks = tasks.where((t) {
          if (maskPrivate && _isPrivateTask(t)) return true;
          if (t.dueDate == null) return false;
          return t.dueDate!.isAfter(today.subtract(const Duration(seconds: 1))) && 
                 t.dueDate!.isBefore(weekEnd);
        }).toList();
        break;
      case DateTimeFilterOption.overdue:
        tasks = tasks.where((t) {
          if (maskPrivate && _isPrivateTask(t)) return true;
          if (t.dueDate == null || t.isCompleted) return false;
          return t.dueDate!.isBefore(now);
        }).toList();
        break;
      case DateTimeFilterOption.noDate:
        tasks = tasks.where((t) {
          if (maskPrivate && _isPrivateTask(t)) return true;
          return t.dueDate == null;
        }).toList();
        break;
      case DateTimeFilterOption.all:
        break;
    }

    tasks.sort((a, b) {
      final aPrivate = maskPrivate && _isPrivateTask(a);
      final bPrivate = maskPrivate && _isPrivateTask(b);
      if (aPrivate != bPrivate) return aPrivate ? 1 : -1;
      if (aPrivate && bPrivate) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
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
          return a.createdAt.compareTo(b.createdAt);
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
        for (final task in moreTasks) {
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

  List<Task> _getTasksForPublicSurfaces() {
    final all = _source.getTasks();
    if (!_shouldMaskPrivateContent()) return all;
    final privateCategoryIds =
        _source.getCategories().where((c) => c.isPrivate).map((c) => c.id).toSet();
    return all.where((t) => !privateCategoryIds.contains(t.categoryId) && !t.categoryIds.any(privateCategoryIds.contains)).toList();
  }

  bool _shouldMaskPrivateContent() {
    return _subscriptionService.isPremium && _privateModeService.shouldHidePrivateContent;
  }

  List<Task> _getTasksForTaskWidgetAndCounter() {
    return _source.getTasks();
  }

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return _l10n.high;
      case TaskPriority.medium:
        return _l10n.medium;
      case TaskPriority.low:
        return _l10n.low;
    }
  }

  String _formatTaskTitleForCounter(Task task) {
    final priority = _priorityLabel(task.priority);
    final categoryName = task.categoryIds.isNotEmpty 
        ? task.categoryIds.map((id) => getCategoryById(id)?.name).where((n) => n != null).join(', ')
        : getCategoryById(task.categoryId)?.name;
    final parts = <String>[
      if (categoryName != null && categoryName.isNotEmpty) categoryName,
      priority,
      task.title,
    ];
    return parts.join(' • ');
  }

  /// Update home widgets without showing the task count notification
  /// Use this for general widget updates (color changes, pin/unpin, etc.)
  /// Immediately update task counter notification, bypassing widget debounce.
  /// Called after task creation to ensure the notification is shown right away.
  Future<void> _updateTaskCounterNotification() async {
    try {
      final allTasks = _source.getTasks();
      final uncompletedTasks = allTasks
          .where((t) => !t.isCompleted && !(t.isDeleted ?? false))
          .toList();

      final titles = uncompletedTasks.map((t) => t.title).toList();

      await _notificationService.showTaskCountNotification(
        uncompletedTasks.length,
        titles,
        isDarkText: !_themeService.isDarkMode,
        uncompletedTasksLabel: _l10n.notificationUncompletedTasks(
          uncompletedTasks.length,
        ),
        tasksRemainingLabel: _l10n.notificationTasksRemaining,
        tasksSummaryLabel: _l10n.notificationTasksSummary(uncompletedTasks.length),
      );
    } catch (e) {
      // Not critical — widget update will handle it as fallback
    }
  }

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
    if (kIsWeb) return;
    if (_widgetUpdateInProgress) {
      _pendingWidgetUpdate = true;
      return;
    }

    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(
      Duration(milliseconds: AppConfig.notificationDebounceMs),
      () async {
        if (_widgetUpdateInProgress) {
          _pendingWidgetUpdate = true;
          return;
        }
        
        _widgetUpdateInProgress = true;
        try {
          final tasksForPublicSurfaces = _getTasksForPublicSurfaces();
          final tasksForTaskWidgetAndCounter = _getTasksForTaskWidgetAndCounter();
          final chartPath = await TaskWidgetService.updateTaskWidget(
            tasksForTaskWidgetAndCounter,
            getCategoryById,
            isDarkText: !_themeService.isDarkMode,
          );

          // Only show notification when explicitly requested
          // (task added, completed, deleted, or app first opened)
          if (showNotification) {
            final uncompletedTasks = tasksForTaskWidgetAndCounter
                .where((t) => !t.isCompleted && !(t.isDeleted ?? false))
                .toList();

            await _notificationService.showTaskCountNotification(
              uncompletedTasks.length,
              uncompletedTasks.map(_formatTaskTitleForCounter).toList(),
              largeIconPath: chartPath,
              isDarkText: !_themeService.isDarkMode,
              uncompletedTasksLabel: _l10n.notificationUncompletedTasks(
                uncompletedTasks.length,
              ),
              tasksRemainingLabel: _l10n.notificationTasksRemaining,
              tasksSummaryLabel: _l10n.notificationTasksSummary(
                uncompletedTasks.length,
              ),
            );
          }

          // Get current user ID and email for ROCIs-Schedule integration
          final userId = _authService.currentUser?.uid;
          final userEmail = _authService.currentUser?.email;

          // Set user email for cross-app schedule data lookup
          _widgetDataService.setUserEmail(userEmail);
          _fullCalendarWidgetService.setUserEmail(userEmail);

          await _widgetDataService.updateMonthEventsMap(
            tasksForPublicSurfaces,
            userId: userId,
          );
          await _widgetDataService.updateScheduleWidget(
            tasksForPublicSurfaces,
            getCategoryById,
            userId: userId,
          );
          await _widgetDataService.updateCalendarListWidget(
            tasksForPublicSurfaces,
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
          if (_pendingWidgetUpdate) {
            _pendingWidgetUpdate = false;
            _updateWidgets(showNotification: false);
          }
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
    List<String>? categoryIds,
    List<SubTask>? subTasks,
    bool requireSubTasksBeforeReminders = false,
    bool syncWithGoogleTasks = false,
    List<String>? attachmentPaths,
    bool skipReminders = false,
  }) async {
    final task = Task(
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      categoryId: category,
      categoryIds: categoryIds,
      subTasks: subTasks,
      requireSubTasksBeforeReminders: requireSubTasksBeforeReminders,
      syncWithGoogleTasks: syncWithGoogleTasks,
      attachmentPaths: attachmentPaths,
      skipReminders: skipReminders,
    );
    await _source.addTask(task);
    // Sync to cloud - Firestore handles offline state and buffering
    _firestoreService.addTask(task).catchError((e, s) {
      _errorHandlingService.logError(e, s, reason: 'Background cloud addTask failed');
    });

    if (dueDate != null && dueDate.isAfter(DateTime.now())) {
      try {
        await _scheduleTaskNotifications(task);
      } catch (e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Scheduling notification for new task',
        );
        // Not critical enough to show error, but good to know
      }
    }

    await _syncTaskGoogleTasksState(task);

    _refreshPagination();
    notifyListeners();
    updateHomeWidgetWithNotification(); // Show notification when task is added

    // Immediately update task counter notification (bypass widget debounce)
    _updateTaskCounterNotification();

    // Log analytics
    await _analyticsService.logTaskCreated(
      categoryId: categoryIds?.isNotEmpty == true ? categoryIds!.join(',') : (category ?? 'none'),
      hasDueDate: dueDate != null,
    );

    // Check if private task was created without security enabled
    if (category != null) {
      final cat = getCategoryById(category);
      if (cat?.isPrivate == true && !_privateModeService.shouldHidePrivateContent) {
        _showSecurityPrompt = true;
        notifyListeners();
      }
    }
  }

  Future<void> toggleTaskCompletion(Task task) async {
    task.isCompleted = !task.isCompleted;
    task.completedAt = task.isCompleted ? DateTime.now() : null;

    // Record the intended state so the Firestore stream doesn't revert it
    _pendingLocalWrites[task.id] = task.isCompleted;

    notifyListeners();
    await _source.addTask(task);
    _firestoreService.updateTask(task).catchError((e, s) {
      _errorHandlingService.logError(e, s, reason: 'Background cloud updateTask failed');
    }).whenComplete(() {
      // Allow stream to handle this task again after Firestore write settles
      Future.delayed(const Duration(seconds: 3), () {
        _pendingLocalWrites.remove(task.id);
      });
    });

    await _syncTaskGoogleTasksState(task);

    if (task.isCompleted) {
      await _cancelTaskNotifications(task);
    } else if (task.dueDate != null && task.dueDate!.isAfter(DateTime.now())) {
      try {
        await _scheduleTaskNotifications(task);
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
      await _analyticsService.logTaskCompleted();
    }
  }

  Future<void> updateTask(
    Task task, {
    String? title,
    String? description,
    DateTime? dueDate,
    bool clearDueDate = false,
    TaskPriority? priority,
    String? categoryId,
    List<String>? categoryIds,
    List<SubTask>? subTasks,
    bool? requireSubTasksBeforeReminders,
    bool? syncWithGoogleTasks,
    List<String>? attachmentPaths,
    bool? skipReminders,
  }) async {
    if (title != null) task.title = title;
    if (description != null) task.description = description;
    if (clearDueDate) {
      task.dueDate = null;
    } else if (dueDate != null) {
      task.dueDate = dueDate;
    }
    if (priority != null) task.priority = priority;
    if (categoryId != null) task.categoryId = categoryId;
    if (categoryIds != null) task.categoryIds = categoryIds;
    if (subTasks != null) task.subTasks = subTasks;
    if (requireSubTasksBeforeReminders != null) {
      task.requireSubTasksBeforeReminders = requireSubTasksBeforeReminders;
    }
    if (syncWithGoogleTasks != null) {
      task.syncWithGoogleTasks = syncWithGoogleTasks;
    }
    if (attachmentPaths != null) {
      task.attachmentPaths = attachmentPaths;
    }
    if (skipReminders != null) {
      task.skipReminders = skipReminders;
    }

    await _source.addTask(task);
    _firestoreService.updateTask(task).catchError((e, s) {
      _errorHandlingService.logError(e, s, reason: 'Background cloud updateTask failed');
    });

    await _cancelTaskNotifications(task);
    if (!task.isCompleted &&
        task.dueDate != null &&
        task.dueDate!.isAfter(DateTime.now())) {
      try {
        await _scheduleTaskNotifications(task);
      } catch (e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Rescheduling notification after task update',
        );
      }
    }

    await _syncTaskGoogleTasksState(task);

    _refreshPagination();
    notifyListeners();
    updateHomeWidget();
  }

  Future<void> _clearDeprecatedRecurringTaskData() async {
    final tasks = _source.getTasks();
    var changed = false;
    for (final task in tasks) {
      if (task.recurrenceRule != null) {
        task.recurrenceRule = null;
        await _source.addTask(task);
        changed = true;
      }
    }
    if (changed) {
      _refreshPagination();
      notifyListeners();
    }
  }

  Future<void> toggleSubTask(Task task, String subTaskId) async {
    if (task.subTasks == null) return;

    final index = task.subTasks!.indexWhere((st) => st.id == subTaskId);
    if (index != -1) {
      task.subTasks![index].isCompleted = !task.subTasks![index].isCompleted;
      await _source.addTask(task);
      try {
        if (!task.isCompleted &&
            !(task.isDeleted ?? false) &&
            task.dueDate != null &&
            task.dueDate!.isAfter(DateTime.now())) {
          await _scheduleTaskNotifications(task);
        } else {
          await _cancelTaskNotifications(task);
        }
      } catch (e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Rescheduling notifications after subtask toggle',
        );
      }
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
      await _cancelTaskNotifications(task);
      await _removeGoogleTask(task);
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Deleting task');
    }
    _refreshPagination();
    notifyListeners();
    updateHomeWidgetWithNotification(); // Show notification when task is deleted

    await _analyticsService.logTaskDeleted();
  }

  Future<void> restoreTask(Task task) async {
    task.isDeleted = false;
    await _source.addTask(task);
    await _syncTaskGoogleTasksState(task);
    _firestoreService.updateTask(task).catchError((e, s) {
      _errorHandlingService.logError(e, s, reason: 'Background cloud updateTask failed');
    });
    if (!task.isCompleted &&
        task.dueDate != null &&
        task.dueDate!.isAfter(DateTime.now())) {
      try {
        await _scheduleTaskNotifications(task);
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
    final task = getTaskById(id);
    if (task != null) {
      await _removeGoogleTask(task);
    }
    await _source.deleteTask(id);
    _firestoreService.deleteTask(id).catchError((e, s) {
      _errorHandlingService.logError(e, s, reason: 'Background cloud deleteTask failed');
    });
    await _cancelTaskNotificationsById(id);
    _refreshPagination();
    notifyListeners();
    updateHomeWidgetWithNotification(); // Show notification when task is permanently deleted

    await _analyticsService.logTaskDeleted();
  }

  Future<void> clearTrash() async {
    final tasksToDelete = deletedTasks;
    for (final task in tasksToDelete) {
      await _source.deleteTask(task.id);
      _firestoreService.deleteTask(task.id).catchError((e, s) {
        _errorHandlingService.logError(e, s, reason: 'Background cloud bulk deleteTask failed');
      });
      await _cancelTaskNotifications(task);
    }
    _refreshPagination();
    notifyListeners();
    updateHomeWidgetWithNotification();
  }

  bool get canAddCategory {
    if (_subscriptionService.isPremium) return true;
    return categories.length < AppConfig.freeCategoryLimit;
  }

  // --- Bulk Action Methods ---

  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedTaskIds.clear();
    }
    notifyListeners();
  }

  void toggleTaskSelection(String taskId) {
    if (_selectedTaskIds.contains(taskId)) {
      _selectedTaskIds.remove(taskId);
      if (_selectedTaskIds.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedTaskIds.add(taskId);
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedTaskIds.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  Future<void> deleteSelectedTasks() async {
    final idsToDelete = List<String>.from(_selectedTaskIds);
    clearSelection();
    
    for (final id in idsToDelete) {
      await deleteTask(id);
    }
  }

  Future<void> toggleSelectedTasksPin() async {
    final idsToToggle = List<String>.from(_selectedTaskIds);
    final tasksToToggle = _source.getTasks().where((t) => idsToToggle.contains(t.id)).toList();
    
    // Determine the target state (pin if most are unpinned, or vice versa)
    final pinnedCount = tasksToToggle.where((t) => t.isPinned ?? false).length;
    final targetPin = pinnedCount < (tasksToToggle.length / 2);

    for (final task in tasksToToggle) {
      if ((task.isPinned ?? false) != targetPin) {
        await toggleTaskPin(task);
      }
    }
    clearSelection();
  }

  Future<void> moveSelectedTasksToCategory(String? categoryId) async {
    final idsToMove = List<String>.from(_selectedTaskIds);
    final tasksToMove = _source.getTasks().where((t) => idsToMove.contains(t.id)).toList();

    for (final task in tasksToMove) {
      await updateTask(task, categoryId: categoryId);
    }
    clearSelection();
  }

  Future<void> addCategory(
    String name,
    int colorValue,
    int iconCode, {
    bool isPrivate = false,
  }) async {
    if (!canAddCategory) {
      throw Exception('Category limit reached');
    }

    final sanitizedName = ValidationService.sanitizeText(name);
    final category = Category(
      name: sanitizedName,
      colorValue: colorValue,
      iconCode: iconCode,
      isPrivate: isPrivate,
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

    // Check if private category was created without security enabled
    if (isPrivate && !_privateModeService.shouldHidePrivateContent) {
      _showSecurityPrompt = true;
      notifyListeners();
    }
  }

  Future<void> updateCategory(
    Category category, {
    String? name,
    int? colorValue,
    int? iconCode,
    bool? isPrivate,
  }) async {
    if (name != null) category.name = ValidationService.sanitizeText(name);
    if (colorValue != null) category.colorValue = colorValue;
    if (iconCode != null) category.iconCode = iconCode;
    if (isPrivate != null) category.isPrivate = isPrivate;
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

  bool _isPrivateTask(Task task) {
    if (task.categoryIds.isNotEmpty) {
      if (task.categoryIds.any((id) => getCategoryById(id)?.isPrivate == true)) {
        return true;
      }
    }
    final categoryId = task.categoryId;
    if (categoryId == null) return false;
    final category = getCategoryById(categoryId);
    return category?.isPrivate ?? false;
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



  Future<void> _removeGoogleTask(Task task) async {
    final taskId = task.googleTaskId;
    if (taskId == null) return;

    try {
      await _googleTasksService.deleteTask(taskId: taskId);
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Failed to delete Google task',
      );
    }

    task.googleTaskId = null;
    task.googleTaskListId = null;
    await _source.addTask(task);
  }

  Future<void> _syncTaskGoogleTasksState(Task task) async {
    if (task.isDeleted ?? false) {
      await _removeGoogleTask(task);
      return;
    }

    if (!task.syncWithGoogleTasks) {
      await _removeGoogleTask(task);
      return;
    }

    try {
      String? categoryName;
      if (task.categoryIds.isNotEmpty) {
        categoryName = getCategoryById(task.categoryIds.first)?.name;
      } else if (task.categoryId != null) {
        categoryName = getCategoryById(task.categoryId)?.name;
      }

      if (task.googleTaskId == null) {
        final taskId = await _googleTasksService.createTask(
          title: task.title,
          description: task.description.isEmpty ? null : task.description,
          dueDate: task.dueDate,
          categoryName: categoryName,
        );

        if (taskId != null) {
          task.googleTaskId = taskId;
          task.googleTaskListId = 'ROCIs Tasks';
          await _source.addTask(task);
        }
      } else {
        final success = await _googleTasksService.updateTask(
          taskId: task.googleTaskId!,
          title: task.title,
          description: task.description.isEmpty ? null : task.description,
          dueDate: task.dueDate,
          isCompleted: task.isCompleted,
          categoryName: categoryName,
        );

        if (!success) {
          task.googleTaskId = null;
          task.googleTaskListId = null;
          await _source.addTask(task);
          await _syncTaskGoogleTasksState(task);
        }
      }
    } catch (e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Sync task to Google Tasks failed',
      );
    }
  }

  Task? getTaskById(String id) {
    try {
      return _source.getTasks().firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}
