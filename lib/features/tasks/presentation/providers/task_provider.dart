import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rocis_tasks/shared/ui/app_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rocis_tasks/core/dev/screenshot_seed.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/review_prompt_service.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/firestore_service.dart';
import 'package:rocis_tasks/core/services/google_tasks_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/core/services/security_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/core/services/validation_service.dart';
import 'package:rocis_tasks/core/services/widget_data_service.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/features/home/services/month_widget_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/services/task_recurrence_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/helpers/task_filter_service.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/helpers/task_notification_manager.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/helpers/task_sync_manager.dart';
import 'package:rocis_tasks/features/tasks/services/task_widget_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/l10n/l10n_helper.dart';
import 'package:rocis_tasks/shared/ui/ui_kit.dart';

export 'package:rocis_tasks/features/tasks/presentation/providers/helpers/task_filter_service.dart'
    show TaskSortOption, DateTimeFilterOption;

/// Main provider for task management and synchronization.
///
/// This class handles local persistence via Hive, cloud synchronization via Firestore,
/// and coordination between various services (notifications, widgets, etc.).
class TaskProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppLocalizations get _l10n {
    final currentLocale =
        _themeService.locale ?? PlatformDispatcher.instance.locale;
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
  List<Task> _visibleTasks = const [];

  late final TaskFilterService _filterService;
  late final TaskNotificationManager _notificationManager;
  late final TaskSyncManager _syncManager;

  bool _isLoading = true;
  StreamSubscription? _authSubscription;
  VoidCallback? _connectivityListener;
  bool _materializingRecurring = false;
  bool _lastKnownPremium = false;
  StreamSubscription? _notificationSubscription;
  String? _lastUserId;

  // Reminders & Quiet Hours settings
  bool _advancedRemindersEnabled = false;
  bool _nagRemindersEnabled = false;
  int _nagIntervalMinutes = 15;
  int _nagCount = 3;
  bool _quietHoursEnabled = false;
  int _quietStartMinutes = 22 * 60;
  int _quietEndMinutes = 7 * 60;
  bool _showMyTasksGuideShortcut = true;

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
       _analyticsService = analyticsService ?? AnalyticsService() {
    _filterService = TaskFilterService();
    _notificationManager = TaskNotificationManager(
      notificationService: _notificationService,
    );
    _syncManager = TaskSyncManager(
      authService: _authService,
      firestoreService: _firestoreService,
      googleTasksService: _googleTasksService,
      calendarService: _calendarService,
      source: _source,
      errorHandlingService: _errorHandlingService,
    );
  }

  Timer? _widgetDebounce;
  bool _widgetUpdateInProgress = false;
  bool _pendingWidgetUpdate = false;
  bool _pendingWidgetNotification = false;
  bool get isLoading => _isLoading;

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

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final sortIndex = prefs.getInt('sort_option');
    if (sortIndex != null && sortIndex < TaskSortOption.values.length) {
      _filterService.currentSortOption = TaskSortOption.values[sortIndex];
    }
    final dateFilterIndex = prefs.getInt('date_filter');
    if (dateFilterIndex != null &&
        dateFilterIndex < DateTimeFilterOption.values.length) {
      _filterService.currentDateFilter =
          DateTimeFilterOption.values[dateFilterIndex];
    }
    _filterService.selectedCategoryIds =
        prefs.getStringList('category_filters') ?? [];
    _filterService.showCompleted = prefs.getBool('show_completed') ?? true;
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
    _filterService.searchQuery = '';

    _monthWidgetService = MonthWidgetService(_calendarService, _source);
    final scheduleService = ScheduleFirestoreService();
    _fullCalendarWidgetService = FullCalendarWidgetService(
      _calendarService,
      _source,
      scheduleService: scheduleService,
    );
    _widgetDataService = WidgetDataService(
      _calendarService,
      scheduleService: scheduleService,
    );

    // Initialize widget schedule integration asynchronously
    unawaited(
      _fullCalendarWidgetService.initScheduleService().catchError((e, s) {
        AppLogger.warning('FullCalendar schedule init warning: $e');
      }),
    );

    try {
      await _source.init();
      if (ScreenshotSeed.enabled) {
        // Store-screenshot builds only (compile-time flag).
        final prefs = await SharedPreferences.getInstance();
        await ScreenshotSeed.apply(
          _source,
          prefs.getString('language_code') ?? 'en',
        );
      }
      // Ensure notification service is initialized without blocking UI on permission prompt
      await _notificationService.init();
      unawaited(
        _notificationService.requestPermissions().catchError((e) {
          AppLogger.warning('Permission request warning: $e');
        }),
      );
      WidgetsBinding.instance.addObserver(this);
      await checkAndMaterializeDueRecurringTasks();
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Initialization failed');
      _setError(_l10n.initializationFailedError);
    }

    _refreshPagination();

    _lastKnownPremium = _subscriptionService.isPremium;
    _subscriptionService.addListener(_onSubscriptionChanged);
    _privateModeService.addListener(_onPrivateModeChanged);

    // Populate all home screen widgets with initial data and restore task counter notification
    unawaited(_updateWidgets(showNotification: true));

    Future.delayed(const Duration(seconds: 2), rescheduleAllTaskNotifications);

    // Connectivity probing can take several seconds offline (DNS fallbacks),
    // so never hold the first frame on it; the listener catches the result.
    unawaited(_connectivityService.init());

    _connectivityListener = () {
      if (_connectivityService.isOnline && _authService.currentUser != null) {
        syncWithCloud();
      }
    };
    _connectivityService.addListener(_connectivityListener!);

    _lastUserId = _authService.currentUser?.uid;
    _authSubscription = _authService.authStateChanges.listen((
      User? user,
    ) async {
      if (user != null) {
        _lastUserId = user.uid;
        _firestoreService.setUserId(user.uid);
        _refreshPagination();
        uploadLocalDataToCloud();
        syncWithCloud();
        unawaited(_prefetchCompletedTasksIfNeeded());
      } else {
        if (_lastUserId != null) {
          AppLogger.info(
            'User signed out, clearing local data...',
            tag: 'Tasks',
          );
          _firestoreService.setUserId(null);
          await _syncManager.cancelSubscriptions();
          await _source.clearAll();
          updateHomeWidget();
          _lastUserId = null;
        }
      }
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();

    Future.delayed(
      const Duration(seconds: 1),
      () async => await updateHomeWidgetWithNotification(),
    );

    if (_authService.currentUser != null) {
      _firestoreService.setUserId(_authService.currentUser!.uid);
      _refreshPagination();

      uploadLocalDataToCloud().catchError((e, s) {
        _errorHandlingService.logError(e, s, reason: 'Initial upload');
      });
      syncWithCloud().then((_) => updateHomeWidget()).catchError((e, s) {
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
      final task = getTaskById(taskId);
      if (task == null) return;
      _taskToEdit = task;
      notifyListeners();
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Navigating to task');
    }
  }

  Future<void> _snoozeTask(String taskId, String? actionId) async {
    try {
      final task = getTaskById(taskId);
      if (task != null && task.dueDate != null) {
        final newDate = _notificationManager.getSnoozedDate(
          task.dueDate!,
          actionId,
        );
        await updateTask(task, dueDate: newDate);
      }
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Snoozing task');
    }
  }

  Future<void> _completeTaskFromNotification(String taskId) async {
    try {
      final task = getTaskById(taskId);
      if (task != null && !task.isCompleted) {
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

  Future<void> _cancelTaskNotifications(Task task) async {
    await _notificationManager.cancelTaskNotifications(task);
  }

  Future<void> _cancelTaskNotificationsById(String taskId) async {
    await _notificationManager.cancelTaskNotificationsById(taskId);
  }

  /// Re-arms every task's reminders, including the deferred next iteration
  /// of completed recurring tasks.
  Future<void> rescheduleAllTaskNotifications({
    bool cancelExisting = false,
  }) async {
    final allTasks = _source.getTasks();
    if (cancelExisting) await _notificationService.cancelAllNotifications();
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
  }

  Future<void> _scheduleTaskNotifications(Task task) async {
    // A completed recurring task owns the reminder for its deferred next
    // iteration; bulk reschedules (startup, full sync, remote sync) must
    // restore that preview or the chain stops notifying after one cycle.
    if (task.isCompleted &&
        task.nextRecurrenceDate != null &&
        (task.recurrenceRule?.trim().isNotEmpty ?? false) &&
        !(task.isDeleted ?? false) &&
        _subscriptionService.isPremium) {
      task = TaskRecurrenceService.createUpcomingPreviewTask(
        task,
        task.nextRecurrenceDate!,
      );
    }
    await _notificationManager.scheduleTaskNotifications(
      task,
      l10n: _l10n,
      isPremium: _subscriptionService.isPremium,
      advancedRemindersEnabled: advancedRemindersEnabled,
      nagRemindersEnabled: nagRemindersEnabled,
      nagCount: _nagCount,
      nagIntervalMinutes: _nagIntervalMinutes,
      quietHoursEnabled: quietHoursEnabled,
      quietStartMinutes: _quietStartMinutes,
      quietEndMinutes: _quietEndMinutes,
      isPrivate: _isPrivateTask(task),
      shouldHidePrivate: _shouldMaskPrivateContent(),
    );
  }

  void _onSubscriptionChanged() {
    final isPremium = _subscriptionService.isPremium;
    final becamePremium = isPremium && !_lastKnownPremium;
    _lastKnownPremium = isPremium;
    notifyListeners();
    // Premium status is resolved after startup, so deferred recurring tasks
    // that came due while the app was closed are materialized here.
    if (becamePremium) {
      unawaited(checkAndMaterializeDueRecurringTasks());
    }
  }

  void _onPrivateModeChanged() {
    _refreshPagination();
    notifyListeners();
    updateHomeWidget();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    if (_connectivityListener != null) {
      _connectivityService.removeListener(_connectivityListener!);
    }
    _subscriptionService.removeListener(_onSubscriptionChanged);
    _notificationSubscription?.cancel();
    _widgetDebounce?.cancel();
    _privateModeService.removeListener(_onPrivateModeChanged);
    _syncManager.cancelSubscriptions();
    super.dispose();
  }

  Future<void> uploadLocalDataToCloud() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('disable_cloud_sync') == true) return;
    await _syncManager.uploadLocalDataToCloud();
  }

  Future<void> _prefetchCompletedTasksIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('disable_cloud_sync') == true) return;
    await _syncManager.prefetchCompletedTasksIfNeeded(
      showCompleted: _filterService.showCompleted,
      onDataChanged: () {
        _refreshPagination();
        notifyListeners();
      },
    );
  }

  Future<void> syncWithCloud() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('disable_cloud_sync') == true) return;
    await _syncManager.startCloudSync(
      getTaskById: getTaskById,
      scheduleTaskNotifications: _scheduleTaskNotifications,
      cancelNotificationsById: _cancelTaskNotificationsById,
      onDataChanged: () {
        _refreshPagination();
        notifyListeners();
        updateHomeWidget();
      },
    );
  }

  Future<void> performFullSync() async {
    try {
      await syncWithCloud();
      await syncGoogleTasksToLocal();
      await _syncManager.processGoogleCalendarUpstreamRocisTasksHook(
        isPremium: _subscriptionService.isPremium,
        scheduleTaskNotifications: _scheduleTaskNotifications,
        onDataChanged: () {
          _refreshPagination();
          notifyListeners();
          updateHomeWidget();
        },
      );
      await updateHomeWidgetWithNotification();

      await rescheduleAllTaskNotifications(cancelExisting: true);
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Performing full sync');
      rethrow;
    }
  }

  TaskSortOption get currentSortOption => _filterService.currentSortOption;
  DateTimeFilterOption get currentDateFilter =>
      _filterService.currentDateFilter;
  List<String> get selectedCategoryIds => _filterService.selectedCategoryIds;
  bool get showCompleted => _filterService.showCompleted;
  bool get advancedRemindersEnabled =>
      _subscriptionService.isPremium && _advancedRemindersEnabled;
  bool get nagRemindersEnabled =>
      _subscriptionService.isPremium && _nagRemindersEnabled;
  int get nagIntervalMinutes =>
      _subscriptionService.isPremium ? _nagIntervalMinutes : 15;
  int get nagCount => _subscriptionService.isPremium ? _nagCount : 0;
  bool get quietHoursEnabled =>
      _subscriptionService.isPremium && _quietHoursEnabled;
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
    _filterService.currentSortOption = option;
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
    _filterService.currentDateFilter = option;
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
    _filterService.toggleCategoryFilter(categoryId);
    _refreshPagination();
    notifyListeners();
    _saveCategoryFilters();
  }

  void selectSingleCategoryFilter(String categoryId) {
    if (_filterService.selectedCategoryIds.length == 1 &&
        _filterService.selectedCategoryIds.contains(categoryId)) {
      _filterService.selectedCategoryIds.clear();
    } else {
      _filterService.selectedCategoryIds = [categoryId];
    }
    _refreshPagination();
    notifyListeners();
    _saveCategoryFilters();
  }

  void clearCategoryFilters() {
    _filterService.clearCategoryFilters();
    _refreshPagination();
    notifyListeners();
    _saveCategoryFilters();
  }

  void resetAllFilters() {
    _filterService.currentSortOption = TaskSortOption.dueDate;
    _filterService.currentDateFilter = DateTimeFilterOption.all;
    _filterService.clearCategoryFilters();
    _filterService.showCompleted = true;
    _refreshPagination();
    notifyListeners();
    _saveCategoryFilters();
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setInt('sort_option', TaskSortOption.dueDate.index);
          prefs.setInt('date_filter', DateTimeFilterOption.all.index);
          prefs.setBool('show_completed', true);
        })
        .catchError((e, s) {
          _errorHandlingService.logError(e, s, reason: 'Resetting filters');
        });
  }

  void _saveCategoryFilters() {
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setStringList(
            'category_filters',
            _filterService.selectedCategoryIds,
          );
        })
        .catchError((e, s) {
          _errorHandlingService.logError(
            e,
            s,
            reason: 'Saving category filters',
          );
        });
  }

  String get searchQuery => _filterService.searchQuery;

  void setSearchQuery(String query) {
    _filterService.setSearchQuery(query);
    _refreshPagination();
    notifyListeners();
  }

  void toggleShowCompleted(bool value) {
    _filterService.showCompleted = value;
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

  /// The filtered + sorted task list shown in the UI. Recomputed only when
  /// data or filters change (see [_refreshPagination]); a new list instance is
  /// produced on each refresh so `Selector`s rebuild correctly.
  List<Task> get tasks {
    if (_isLoading) return [];
    return _visibleTasks;
  }

  List<Task> get allTasks {
    if (_isLoading) return [];
    var tasks = _source
        .getTasks()
        .where((t) => !(t.isDeleted ?? false))
        .toList();
    if (_shouldMaskPrivateContent()) {
      tasks = tasks.where((t) => !_isPrivateTask(t)).toList();
    }
    return tasks;
  }

  List<Task> _getFilteredAndSortedTasks() {
    return _filterService.filterAndSortTasks(
      allTasks: _source.getTasks(),
      getCategoryById: getCategoryById,
      isPrivateTask: _isPrivateTask,
      shouldMaskPrivateContent: _shouldMaskPrivateContent(),
    );
  }

  List<Task> get deletedTasks {
    if (_isLoading) return [];
    return _source.getTasks().where((t) => t.isDeleted ?? false).toList();
  }

  List<Category> get categories {
    if (_isLoading) return [];
    return _source.getCategories();
  }

  int get totalTaskCount => _visibleTasks.length;

  void _refreshPagination() {
    _visibleTasks = List.unmodifiable(_getFilteredAndSortedTasks());
  }

  List<Task> _getTasksForPublicSurfaces() {
    final all = _source.getTasks();
    if (!_shouldMaskPrivateContent()) return all;
    final privateCategoryIds = _source
        .getCategories()
        .where((c) => c.isPrivate)
        .map((c) => c.id)
        .toSet();
    return all
        .where(
          (t) =>
              !privateCategoryIds.contains(t.categoryId) &&
              !t.categoryIds.any(privateCategoryIds.contains),
        )
        .toList();
  }

  bool _shouldMaskPrivateContent() {
    return _subscriptionService.isPremium &&
        _privateModeService.shouldHidePrivateContent;
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
        ? task.categoryIds
              .map((id) => getCategoryById(id)?.name)
              .where((n) => n != null)
              .join(', ')
        : getCategoryById(task.categoryId)?.name;
    final parts = <String>[
      if (categoryName != null && categoryName.isNotEmpty) categoryName,
      priority,
      task.title,
    ];
    return parts.join(' • ');
  }

  Future<void> _updateTaskCounterNotification() async {
    final allTasks = _source.getTasks();
    final uncompletedTasks = allTasks
        .where((t) => !t.isCompleted && !(t.isDeleted ?? false))
        .toList();

    await _notificationManager.updateTaskCounterNotification(
      uncompletedTasks: uncompletedTasks,
      isDarkMode: _themeService.isDarkMode,
      l10n: _l10n,
    );
  }

  Future<void> updateHomeWidget() async {
    await _updateWidgets(showNotification: false);
  }

  Future<void> updateHomeWidgetWithNotification() async {
    await _updateWidgets(showNotification: true);
  }

  Future<void> _updateWidgets({required bool showNotification}) async {
    if (kIsWeb) return;
    if (_widgetUpdateInProgress) {
      _pendingWidgetUpdate = true;
      _pendingWidgetNotification |= showNotification;
      return;
    }

    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(
      Duration(milliseconds: AppConfig.notificationDebounceMs),
      () async {
        if (_widgetUpdateInProgress) {
          _pendingWidgetUpdate = true;
          _pendingWidgetNotification |= showNotification;
          return;
        }

        _widgetUpdateInProgress = true;
        try {
          final tasksForPublicSurfaces = _getTasksForPublicSurfaces();
          final tasksForTaskWidgetAndCounter =
              _getTasksForTaskWidgetAndCounter();
          final chartPath = await TaskWidgetService.updateTaskWidget(
            tasksForTaskWidgetAndCounter,
            getCategoryById,
            isDarkText: !_themeService.isDarkMode,
          );

          if (showNotification) {
            final uncompletedTasks = tasksForTaskWidgetAndCounter
                .where((t) => !t.isCompleted && !(t.isDeleted ?? false))
                .toList();

            await _notificationManager.updateTaskCounterNotification(
              uncompletedTasks: uncompletedTasks,
              isDarkMode: _themeService.isDarkMode,
              l10n: _l10n,
              largeIconPath: chartPath,
              formattedTitles: uncompletedTasks
                  .map(_formatTaskTitleForCounter)
                  .toList(),
            );
          }

          final userId = _authService.currentUser?.uid;
          final userEmail = _authService.currentUser?.email;

          _fullCalendarWidgetService.setUserEmail(userEmail);

          await Future.wait([
            _widgetDataService.updateAllWidgets(
              tasksForPublicSurfaces,
              getCategoryById,
              userId: userId,
            ),
            _monthWidgetService.updateMonthWidget(),
            _fullCalendarWidgetService.updateFullCalendarWidget(userId: userId),
          ]);
        } catch (e, s) {
          _errorHandlingService.logError(e, s, reason: 'Updating home widgets');
        } finally {
          _widgetUpdateInProgress = false;
          if (_pendingWidgetUpdate) {
            final withNotification = _pendingWidgetNotification;
            _pendingWidgetUpdate = false;
            _pendingWidgetNotification = false;
            _updateWidgets(showNotification: withNotification);
          }
        }
      },
    );
  }

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
    bool isGroceryList = false,
    String? recurrenceRule,
    List<TaskCustomField>? customFields,
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
      isGroceryList: isGroceryList,
      recurrenceRule: recurrenceRule,
      customFields: customFields,
    );
    task.touch();
    await _source.addTask(task);
    // Show the task immediately; reminders and Google Tasks sync follow.
    _refreshPagination();
    notifyListeners();

    _firestoreService.addTask(task).catchError((e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Background cloud addTask failed',
      );
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
      }
    }

    await _syncTaskGoogleTasksState(task);

    updateHomeWidgetWithNotification();
    _updateTaskCounterNotification();

    await _analyticsService.logTaskCreated(
      categoryId: categoryIds?.isNotEmpty == true
          ? categoryIds!.join(',')
          : (category ?? 'none'),
      hasDueDate: dueDate != null,
    );

    if (category != null) {
      final cat = getCategoryById(category);
      if (cat?.isPrivate == true &&
          !_privateModeService.shouldHidePrivateContent) {
        _showSecurityPrompt = true;
        notifyListeners();
      }
    }
  }

  /// Open subtasks that block completing [task] ("Subtasks required").
  int blockingSubTaskCount(Task task) {
    if (!task.requireSubTasksBeforeReminders || task.isCompleted) return 0;
    return task.subTasks?.where((st) => !st.isCompleted).length ?? 0;
  }

  /// Returns false when the task could not be completed because required
  /// subtasks are still open.
  Future<bool> toggleTaskCompletion(Task task) async {
    final blocking = blockingSubTaskCount(task);
    if (blocking > 0) {
      HapticFeedback.heavyImpact();
      appMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_l10n.completeSubtasksFirst(blocking))),
        );
      return false;
    }
    task.isCompleted = !task.isCompleted;
    task.completedAt = task.isCompleted ? DateTime.now() : null;

    _syncManager.recordPendingWrite(task.id, task.isCompleted);

    task.touch();
    await _source.addTask(task);
    _refreshPagination();
    notifyListeners();
    _firestoreService
        .updateTask(task)
        .catchError((e, s) {
          _errorHandlingService.logError(
            e,
            s,
            reason: 'Background cloud updateTask failed',
          );
        })
        .whenComplete(() {
          _syncManager.schedulePendingWriteCleanup(
            task.id,
            delay: const Duration(seconds: 15),
          );
        });

    await _syncTaskGoogleTasksState(task);

    if (task.isCompleted) {
      await _cancelTaskNotifications(task);
      unawaited(ReviewPromptService().onTaskCompleted());

      // If this is a recurring task and user is Pro, determine the next recurring instance
      if (task.recurrenceRule != null &&
          task.recurrenceRule!.trim().isNotEmpty &&
          _subscriptionService.isPremium) {
        final baseDate = task.dueDate ?? task.createdAt;
        final nextDueDate = TaskRecurrenceService.getNextDueDate(
          baseDate,
          task.recurrenceRule!,
          after: DateTime.now(),
        );

        if (nextDueDate != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final nextDay = DateTime(
            nextDueDate.year,
            nextDueDate.month,
            nextDueDate.day,
          );

          // Under the deferred recurrence model, the next iteration is deferred until its scheduled date
          if (nextDay.isAfter(today)) {
            task.nextRecurrenceDate = nextDueDate;
            task.touch();
            await _source.updateTask(task);
            _firestoreService.updateTask(task).catchError((e, s) {
              _errorHandlingService.logError(
                e,
                s,
                reason:
                    'Background cloud updateTask for deferred recurrence failed',
              );
            });

            // Pre-schedule notification for the deferred iteration
            final previewTask = TaskRecurrenceService.createUpcomingPreviewTask(
              task,
              nextDueDate,
            );
            try {
              await _scheduleTaskNotifications(previewTask);
            } catch (e, s) {
              _errorHandlingService.logError(
                e,
                s,
                reason:
                    'Scheduling pre-notification for deferred recurring task',
              );
            }
          }
        }
      }
    } else {
      // If task was un-completed and it had recurrence:
      if (task.recurrenceRule != null &&
          task.recurrenceRule!.trim().isNotEmpty) {
        // 1. If it had a deferred recurrence scheduled, cancel its notification and clear date
        if (task.nextRecurrenceDate != null) {
          final previewTask = TaskRecurrenceService.createUpcomingPreviewTask(
            task,
            task.nextRecurrenceDate!,
          );
          await _cancelTaskNotifications(previewTask);
          task.nextRecurrenceDate = null;
          task.touch();
          await _source.updateTask(task);
          _firestoreService.updateTask(task).catchError((e, s) {
            _errorHandlingService.logError(
              e,
              s,
              reason: 'Background cloud clear nextRecurrenceDate failed',
            );
          });
        }

        // 2. Clean up any already materialized uncompleted spawned next instances
        try {
          final spawnedTasks = _source
              .getTasks()
              .where(
                (t) =>
                    t.recurringParentId == task.id &&
                    !t.isCompleted &&
                    (t.isDeleted != true),
              )
              .toList();
          for (final spawnedTask in spawnedTasks) {
            await deleteTaskPermanently(spawnedTask.id);
          }
        } catch (e, s) {
          _errorHandlingService.logError(
            e,
            s,
            reason: 'Cleaning up spawned recurring task after uncompletion',
          );
        }
      }

      if (task.dueDate != null && task.dueDate!.isAfter(DateTime.now())) {
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
    }
    _refreshPagination();
    notifyListeners();
    unawaited(_updateTaskCounterNotification());
    updateHomeWidgetWithNotification();

    if (task.isCompleted) {
      await _analyticsService.logTaskCompleted();
    }
    return true;
  }

  Future<Task?> _materializeRecurringTask(
    Task parentTask,
    DateTime scheduledDueDate,
  ) async {
    final finalDueDate = TaskRecurrenceService.adjustDueDateForCatchUp(
      scheduledDueDate,
      DateTime.now(),
    );
    final nextTask = TaskRecurrenceService.createNextRecurringTask(
      parentTask,
      finalDueDate,
    );

    // Cancel any pre-scheduled preview notifications before scheduling real task notifications
    final previewTask = TaskRecurrenceService.createUpcomingPreviewTask(
      parentTask,
      scheduledDueDate,
    );
    await _cancelTaskNotifications(previewTask);

    nextTask.touch();
    await _source.addTask(nextTask);
    _firestoreService.addTask(nextTask).catchError((e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Background cloud addTask for recurring next instance failed',
      );
    });

    if (nextTask.dueDate != null && nextTask.dueDate!.isAfter(DateTime.now())) {
      try {
        await _scheduleTaskNotifications(nextTask);
      } catch (e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Scheduling notification for next recurring task',
        );
      }
    }

    await _syncTaskGoogleTasksState(nextTask);

    // Clear nextRecurrenceDate on parent so it's not materialized again
    parentTask.nextRecurrenceDate = null;
    parentTask.touch();
    await _source.updateTask(parentTask);
    _firestoreService.updateTask(parentTask).catchError((e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason:
            'Background cloud updateTask clearing nextRecurrenceDate failed',
      );
    });

    return nextTask;
  }

  Future<void> checkAndMaterializeDueRecurringTasks() async {
    if (!_subscriptionService.isPremium) return;
    // Resume + premium-resolved can fire together; running twice would spawn
    // duplicate instances before nextRecurrenceDate is cleared.
    if (_materializingRecurring) return;
    _materializingRecurring = true;
    try {
      await _materializeDueRecurringTasks();
    } finally {
      _materializingRecurring = false;
    }
  }

  Future<void> _materializeDueRecurringTasks() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dueDeferredTasks = _source
        .getTasks()
        .where(
          (t) =>
              t.isCompleted &&
              t.nextRecurrenceDate != null &&
              !(t.isDeleted ?? false),
        )
        .where((t) {
          final targetDay = DateTime(
            t.nextRecurrenceDate!.year,
            t.nextRecurrenceDate!.month,
            t.nextRecurrenceDate!.day,
          );
          return today.isAtSameMomentAs(targetDay) || today.isAfter(targetDay);
        })
        .toList();

    if (dueDeferredTasks.isEmpty) return;

    bool anyMaterialized = false;
    for (final task in dueDeferredTasks) {
      try {
        await _materializeRecurringTask(task, task.nextRecurrenceDate!);
        anyMaterialized = true;
      } catch (e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Materializing deferred recurring task ${task.id}',
        );
      }
    }

    if (anyMaterialized) {
      _refreshPagination();
      notifyListeners();
      unawaited(_updateTaskCounterNotification());
      updateHomeWidgetWithNotification();
    }
  }

  List<Task> get upcomingRecurringTasks {
    if (!_subscriptionService.isPremium) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _source
        .getTasks()
        .where(
          (t) =>
              t.isCompleted &&
              t.nextRecurrenceDate != null &&
              !(t.isDeleted ?? false),
        )
        .where((t) {
          final targetDay = DateTime(
            t.nextRecurrenceDate!.year,
            t.nextRecurrenceDate!.month,
            t.nextRecurrenceDate!.day,
          );
          return targetDay.isAfter(today);
        })
        .map(
          (t) => TaskRecurrenceService.createUpcomingPreviewTask(
            t,
            t.nextRecurrenceDate!,
          ),
        )
        .toList();
  }

  List<Task> getUpcomingRecurringTasksForDay(DateTime day) {
    if (!_subscriptionService.isPremium) return [];

    final targetDay = DateTime(day.year, day.month, day.day);

    return upcomingRecurringTasks.where((task) {
      if (task.dueDate == null) return false;
      final taskDay = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );
      return taskDay.isAtSameMomentAs(targetDay);
    }).toList();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkAndMaterializeDueRecurringTasks());
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
    bool? isGroceryList,
    String? recurrenceRule,
    bool clearRecurrenceRule = false,
    List<TaskCustomField>? customFields,
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
    if (isGroceryList != null) {
      task.isGroceryList = isGroceryList;
    }
    if (customFields != null) {
      task.customFields = customFields;
    }
    if (clearRecurrenceRule) {
      task.recurrenceRule = null;
    } else if (recurrenceRule != null) {
      task.recurrenceRule = recurrenceRule;
    }

    if (task.isGroceryList &&
        task.subTasks != null &&
        task.subTasks!.isNotEmpty) {
      final allCompleted = task.subTasks!.every((st) => st.isCompleted);
      if (allCompleted && !task.isCompleted) {
        task.isCompleted = true;
        task.completedAt = DateTime.now();
        _syncManager.recordPendingWrite(task.id, true);
      } else if (!allCompleted && task.isCompleted) {
        task.isCompleted = false;
        task.completedAt = null;
        _syncManager.recordPendingWrite(task.id, false);
      }
    }

    task.touch();
    await _source.addTask(task);
    _refreshPagination();
    notifyListeners();
    final taskId = task.id;
    _firestoreService
        .updateTask(task)
        .catchError((e, s) {
          _errorHandlingService.logError(
            e,
            s,
            reason: 'Background cloud updateTask failed',
          );
        })
        .whenComplete(() {
          _syncManager.schedulePendingWriteCleanup(
            taskId,
            delay: const Duration(seconds: 15),
          );
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

    unawaited(_updateTaskCounterNotification());
    updateHomeWidgetWithNotification();
  }

  Future<void> toggleSubTask(Task task, dynamic identifier) async {
    if (task.subTasks == null || task.subTasks!.isEmpty) return;

    int index = -1;
    if (identifier is int &&
        identifier >= 0 &&
        identifier < task.subTasks!.length) {
      index = identifier;
    } else if (identifier is String) {
      index = task.subTasks!.indexWhere((st) => st.id == identifier);
    }

    if (index != -1) {
      task.subTasks![index].isCompleted = !task.subTasks![index].isCompleted;

      if (task.isGroceryList &&
          task.subTasks != null &&
          task.subTasks!.isNotEmpty) {
        final allCompleted = task.subTasks!.every((st) => st.isCompleted);
        if (allCompleted && !task.isCompleted) {
          task.isCompleted = true;
          task.completedAt = DateTime.now();
          _syncManager.recordPendingWrite(task.id, true);
        } else if (!allCompleted && task.isCompleted) {
          task.isCompleted = false;
          task.completedAt = null;
          _syncManager.recordPendingWrite(task.id, false);
        }
      }

      task.touch();
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

      final taskId = task.id;
      _firestoreService
          .addTask(task)
          .catchError((e, s) {
            _errorHandlingService.logError(
              e,
              s,
              reason: 'Cloud addTask failed',
            );
          })
          .whenComplete(() {
            _syncManager.schedulePendingWriteCleanup(
              taskId,
              delay: const Duration(seconds: 15),
            );
          });

      unawaited(_updateTaskCounterNotification());
      updateHomeWidgetWithNotification();
    }
  }

  Future<void> toggleTaskPin(Task task) async {
    task.isPinned = !(task.isPinned ?? false);
    notifyListeners();
    task.touch();
    await _source.addTask(task);
    _firestoreService.updateTask(task).catchError((e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Background cloud updateTask failed',
      );
    });
    _refreshPagination();
    notifyListeners();
    updateHomeWidget();
  }

  Future<void> deleteTask(String id) async {
    try {
      final task = getTaskById(id);
      if (task == null) return;
      task.isDeleted = true;
      task.touch();
      await _source.addTask(task);
      // A swiped Dismissible must leave the tree before any network await.
      _refreshPagination();
      notifyListeners();
      _firestoreService.updateTask(task).catchError((e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Background cloud updateTask failed',
        );
      });
      await _cancelTaskNotifications(task);
      await _removeGoogleTask(task);
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Deleting task');
    }
    unawaited(_updateTaskCounterNotification());
    updateHomeWidgetWithNotification();

    await _analyticsService.logTaskDeleted();
  }

  Future<void> restoreTask(Task task) async {
    task.isDeleted = false;
    task.touch();
    await _source.addTask(task);
    _refreshPagination();
    notifyListeners();
    await _syncTaskGoogleTasksState(task);
    _firestoreService.updateTask(task).catchError((e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Background cloud updateTask failed',
      );
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
    unawaited(_updateTaskCounterNotification());
    updateHomeWidgetWithNotification();
  }

  Future<void> deleteTaskPermanently(String id) async {
    final task = getTaskById(id);
    final googleTaskId = task?.googleTaskId;
    await _source.deleteTask(id);
    _refreshPagination();
    notifyListeners();
    if (googleTaskId != null) {
      await _syncManager.removeGoogleTaskById(googleTaskId);
    }
    _firestoreService.deleteTask(id).catchError((e, s) {
      _errorHandlingService.logError(
        e,
        s,
        reason: 'Background cloud deleteTask failed',
      );
    });
    await _cancelTaskNotificationsById(id);
    _refreshPagination();
    notifyListeners();
    updateHomeWidgetWithNotification();

    await _analyticsService.logTaskDeleted();
  }

  Future<void> clearTrash() async {
    final tasksToDelete = deletedTasks;
    for (final task in tasksToDelete) {
      await _source.deleteTask(task.id);
      _firestoreService.deleteTask(task.id).catchError((e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'Background cloud bulk deleteTask failed',
        );
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
    final tasksToToggle = _source
        .getTasks()
        .where((t) => idsToToggle.contains(t.id))
        .toList();

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
    final tasksToMove = _source
        .getTasks()
        .where((t) => idsToMove.contains(t.id))
        .toList();

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
      if (task.categoryIds.any(
        (id) => getCategoryById(id)?.isPrivate == true,
      )) {
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
    return _source.getCategory(id);
  }

  Future<void> _removeGoogleTask(Task task) async {
    await _syncManager.removeGoogleTask(task);
  }

  Future<void> _syncTaskGoogleTasksState(Task task) async {
    await _syncManager.syncTaskGoogleTasksState(
      task,
      getCategoryById: getCategoryById,
    );
  }

  Task? getTaskById(String id) => _source.getTask(id);

  Future<void> syncGoogleTasksToLocal() async {
    await _syncManager.syncGoogleTasksToLocal(
      cancelTaskNotifications: _cancelTaskNotificationsById,
      scheduleTaskNotifications: _scheduleTaskNotifications,
      onDataChanged: () {
        _refreshPagination();
        notifyListeners();
        updateHomeWidgetWithNotification();
      },
    );
  }

  Future<void> addGroceryItem(
    Task task,
    String itemTitle, {
    String? quantity,
  }) async {
    if (itemTitle.trim().isEmpty) return;
    final subTasks = List<SubTask>.from(task.subTasks ?? []);
    subTasks.add(SubTask(title: itemTitle.trim(), quantity: quantity?.trim()));
    await updateTask(task, subTasks: subTasks);
  }

  Future<void> resetGroceryList(Task task) async {
    final subTasks = task.subTasks;
    if (subTasks == null || subTasks.isEmpty) return;

    for (final st in subTasks) {
      st.isCompleted = false;
    }
    await updateTask(task, subTasks: subTasks);
  }

  Future<void> clearCompletedSubTasks(Task task) async {
    final subTasks = task.subTasks;
    if (subTasks == null || subTasks.isEmpty) return;

    final remaining = subTasks.where((st) => !st.isCompleted).toList();
    await updateTask(task, subTasks: remaining);
  }

  /// Alias for widget refresh
  void updateAllWidgets() => updateHomeWidget();
}
