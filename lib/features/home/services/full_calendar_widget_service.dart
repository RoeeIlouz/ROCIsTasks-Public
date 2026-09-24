import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/services/task_recurrence_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/helpers/task_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/core/services/auth/google_oauth_manager.dart';

/// Filter options for the full calendar widget
class FullCalendarFilters {
  final bool showTasks;
  final bool showGoogleCalendar;
  final bool showRocisSchedule;
  final List<String> selectedCalendarIds;

  const FullCalendarFilters({
    this.showTasks = true,
    this.showGoogleCalendar = true,
    this.showRocisSchedule = true,
    this.selectedCalendarIds = const [],
  });

  Map<String, dynamic> toMap() => {
    'showTasks': showTasks,
    'showGoogleCalendar': showGoogleCalendar,
    'showRocisSchedule': showRocisSchedule,
    'selectedCalendarIds': selectedCalendarIds,
  };

  factory FullCalendarFilters.fromMap(Map<String, dynamic> map) {
    return FullCalendarFilters(
      showTasks: map['showTasks'] ?? true,
      showGoogleCalendar: map['showGoogleCalendar'] ?? true,
      showRocisSchedule: map['showRocisSchedule'] ?? true,
      selectedCalendarIds: List<String>.from(map['selectedCalendarIds'] ?? []),
    );
  }

  FullCalendarFilters copyWith({
    bool? showTasks,
    bool? showGoogleCalendar,
    bool? showRocisSchedule,
    List<String>? selectedCalendarIds,
  }) {
    return FullCalendarFilters(
      showTasks: showTasks ?? this.showTasks,
      showGoogleCalendar: showGoogleCalendar ?? this.showGoogleCalendar,
      showRocisSchedule: showRocisSchedule ?? this.showRocisSchedule,
      selectedCalendarIds: selectedCalendarIds ?? this.selectedCalendarIds,
    );
  }
}

class FullCalendarWidgetService {
  final CalendarService _calendarService;
  final LocalTaskSource _taskSource;
  final ScheduleFirestoreService _scheduleService;

  static List<dynamic>? _cachedEvents;
  static String? _cachedEventsKey;
  static DateTime? _cachedEventsTime;

  /// The widget draws up to 2 pills or 3 dots, but needs the real count for
  /// its "+N" label; this only bounds the saved data size.
  static const _maxSummariesPerDay = 30;

  static List<SyncedScheduleEvent>? _cachedScheduleEvents;
  static String? _cachedScheduleKey;
  static DateTime? _cachedScheduleTime;

  static AppLocalizations? _cachedL10n;
  static String? _cachedLocaleCode;

  static const _widgetCacheTtl = Duration(minutes: 5);

  /// Invalidate widget in-memory caches
  static void invalidateCaches() {
    _cachedEvents = null;
    _cachedEventsKey = null;
    _cachedEventsTime = null;
    _cachedScheduleEvents = null;
    _cachedScheduleKey = null;
    _cachedScheduleTime = null;
    _cachedL10n = null;
    _cachedLocaleCode = null;
  }

  FullCalendarWidgetService(
    this._calendarService,
    this._taskSource, {
    ScheduleFirestoreService? scheduleService,
  }) : _scheduleService = scheduleService ?? ScheduleFirestoreService();

  /// Initialize the schedule service
  Future<void> initScheduleService() async {
    await _scheduleService.initialize();
  }

  /// Set the user email for ROCIs-Schedule lookup
  void setUserEmail(String? email) {
    _scheduleService.setUserEmail(email);
  }

  /// Get current filter settings
  Future<FullCalendarFilters> getFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final showTasks = prefs.getBool('full_calendar_show_tasks') ?? true;
    final showGoogle = prefs.getBool('full_calendar_show_google') ?? true;
    final showSchedule = prefs.getBool('full_calendar_show_schedule') ?? true;
    final selectedCalendarIds =
        prefs.getStringList('full_calendar_selected_ids') ?? [];

    return FullCalendarFilters(
      showTasks: showTasks,
      showGoogleCalendar: showGoogle,
      showRocisSchedule: showSchedule,
      selectedCalendarIds: selectedCalendarIds,
    );
  }

  /// Save filter settings
  Future<void> saveFilters(FullCalendarFilters filters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('full_calendar_show_tasks', filters.showTasks);
    await prefs.setBool(
      'full_calendar_show_google',
      filters.showGoogleCalendar,
    );
    await prefs.setBool(
      'full_calendar_show_schedule',
      filters.showRocisSchedule,
    );
    await prefs.setStringList(
      'full_calendar_selected_ids',
      filters.selectedCalendarIds,
    );

    if (kIsWeb) return;

    await HomeWidget.saveWidgetData<bool>(
      'full_calendar_show_tasks',
      filters.showTasks,
    );
    await HomeWidget.saveWidgetData<bool>(
      'full_calendar_show_google',
      filters.showGoogleCalendar,
    );
    await HomeWidget.saveWidgetData<bool>(
      'full_calendar_show_schedule',
      filters.showRocisSchedule,
    );
    await HomeWidget.saveWidgetData<String>(
      'full_calendar_selected_ids',
      jsonEncode(filters.selectedCalendarIds),
    );
  }

  /// Toggle a specific filter
  Future<FullCalendarFilters> toggleFilter(String filterName) async {
    final current = await getFilters();
    FullCalendarFilters updated;

    switch (filterName) {
      case 'tasks':
        updated = current.copyWith(showTasks: !current.showTasks);
        break;
      case 'google':
        updated = current.copyWith(
          showGoogleCalendar: !current.showGoogleCalendar,
        );
        break;
      case 'schedule':
      case 'rocis':
        updated = current.copyWith(
          showRocisSchedule: !current.showRocisSchedule,
        );
        break;
      default:
        updated = current;
    }

    await saveFilters(updated);
    return updated;
  }

  /// Adopts a filter value the native widget already flipped.
  ///
  /// The widget's filter buttons toggle the flag natively (for an instant
  /// redraw) before waking Dart; toggling again here would flip it back
  /// whenever the two stores had drifted apart. The widget's value wins.
  Future<FullCalendarFilters> adoptWidgetFilter(String filterName) async {
    final current = await getFilters();
    Future<bool?> widgetValue(String key) =>
        HomeWidget.getWidgetData<bool>(key);

    final updated = switch (filterName) {
      'tasks' => current.copyWith(
        showTasks:
            await widgetValue('full_calendar_show_tasks') ?? current.showTasks,
      ),
      'google' => current.copyWith(
        showGoogleCalendar:
            await widgetValue('full_calendar_show_google') ??
            current.showGoogleCalendar,
      ),
      'schedule' || 'rocis' => current.copyWith(
        showRocisSchedule:
            await widgetValue('full_calendar_show_schedule') ??
            current.showRocisSchedule,
      ),
      _ => current,
    };
    await saveFilters(updated);
    return updated;
  }

  Future<void> updateFullCalendarWidget({
    int? monthOffset,
    String? userId,
    String? userEmail,
    bool forceRefresh = false,
  }) async {
    if (kIsWeb) return;
    try {
      if (forceRefresh) {
        invalidateCaches();
      }

      final prefs = await SharedPreferences.getInstance();
      final int offset =
          monthOffset ??
          (await HomeWidget.getWidgetData<int>('full_calendar_offset') ?? 0);

      // Save offset if provided
      if (monthOffset != null) {
        await HomeWidget.saveWidgetData<int>('full_calendar_offset', offset);
      }

      // Save beta integration flag to home widget
      final betaScheduleIntegration =
          prefs.getBool('beta_schedule_integration') ?? false;
      await HomeWidget.saveWidgetData<bool>(
        'beta_schedule_integration',
        betaScheduleIntegration,
      );

      // Get filter settings
      final filters = await getFilters();

      // Get custom colors (stored as int values)
      final taskColorInt =
          prefs.getInt(CalendarColorService.keyTaskColor) ??
          CalendarColorService.defaultTaskColor.toARGB32();
      final googleColorInt =
          prefs.getInt(CalendarColorService.keyGoogleColor) ??
          CalendarColorService.defaultGoogleColor.toARGB32();

      // Convert to hex strings
      final taskColorHex = '#${taskColorInt.toRadixString(16).padLeft(8, '0')}';
      final googleColorHex =
          '#${googleColorInt.toRadixString(16).padLeft(8, '0')}';

      final localeCode =
          prefs.getString('language_code') ??
          PlatformDispatcher.instance.locale.languageCode;
      final now = DateTime.now();
      final targetMonth = DateTime(now.year, now.month + offset, 1);
      final monthName = DateFormat('MMMM yyyy', localeCode).format(targetMonth);

      // Multi-month buffer window: from 6 months before targetMonth to 12 months after (18 months total)
      final bufferStartDate = DateTime(
        targetMonth.year,
        targetMonth.month - 6,
        1,
      );
      final bufferEndDate = DateTime(
        targetMonth.year,
        targetMonth.month + 13,
        0,
        23,
        59,
        59,
      );

      // Calculate calendar grid (6 weeks) based on startOfWeek preference (7=Sunday, 1=Monday, 6=Saturday)
      final startOfWeek = prefs.getInt('full_calendar_start_of_week') ?? 7;
      final firstDayOfMonth = targetMonth;
      final difference = (firstDayOfMonth.weekday - startOfWeek) % 7;
      final startDate = firstDayOfMonth.subtract(Duration(days: difference));

      // Sources that could not be refreshed this run; only their previously
      // saved entries are carried forward (see mergeStaleSummaries).
      var googleRefreshFailed = false;
      var scheduleRefreshFailed = false;

      // 1. Fetch Google Calendar events (if filter enabled)
      Future<List<dynamic>> fetchGoogleEvents() async {
        if (!filters.showGoogleCalendar) return [];
        // Same calendar selection as the in-app calendar: saved ids that still
        // exist, or every available calendar when none of them do.
        var calendarIds = filters.selectedCalendarIds;
        try {
          final available = (await _calendarService.getAvailableCalendars())
              .map((c) => c.id)
              .whereType<String>()
              .toSet();
          if (available.isNotEmpty) {
            final valid = calendarIds.toSet().intersection(available);
            calendarIds = (valid.isEmpty ? available : valid).toList();
          }
        } catch (_) {}
        final cacheKey =
            '${bufferStartDate.toIso8601String()}_${bufferEndDate.toIso8601String()}_${calendarIds.join(',')}';
        if (!forceRefresh &&
            _cachedEvents != null &&
            _cachedEventsKey == cacheKey &&
            _cachedEventsTime != null &&
            DateTime.now().difference(_cachedEventsTime!) < _widgetCacheTtl) {
          return _cachedEvents!;
        }
        try {
          final res = await _calendarService.getEvents(
            startDate: bufferStartDate,
            endDate: bufferEndDate,
            calendarIds: calendarIds,
          );
          _cachedEvents = res;
          _cachedEventsKey = cacheKey;
          _cachedEventsTime = DateTime.now();
          return res;
        } catch (e, stack) {
          AppLogger.error(
            'Failed to fetch Google Calendar events for widget',
            error: e,
            stack: stack,
          );
          googleRefreshFailed = true;
          return _cachedEvents ?? [];
        }
      }

      // 2. Fetch Google Calendar colors
      Future<Map<String, String>> fetchColors() async {
        if (!filters.showGoogleCalendar) return {};
        try {
          final colors = await _calendarService.getCalendarColors(
            forceRefresh: forceRefresh,
          );
          for (final key in prefs.getKeys()) {
            if (key.startsWith(
              CalendarColorService.keySubcalendarColorsPrefix,
            )) {
              final calId = key.substring(
                CalendarColorService.keySubcalendarColorsPrefix.length,
              );
              final colorInt = prefs.getInt(key);
              if (colorInt != null) {
                colors[calId] =
                    '#${colorInt.toRadixString(16).padLeft(8, '0')}';
              }
            }
          }
          return colors;
        } catch (_) {
          return {};
        }
      }

      // 3. Fetch ROCIs Schedule events (if filter enabled)
      Future<List<SyncedScheduleEvent>> fetchScheduleEvents() async {
        if (!filters.showRocisSchedule) return [];
        final effectiveUid =
            userId ??
            (Firebase.apps.isNotEmpty
                ? FirebaseAuth.instance.currentUser?.uid
                : null);
        final effectiveEmail =
            userEmail ??
            (Firebase.apps.isNotEmpty
                ? FirebaseAuth.instance.currentUser?.email
                : null) ??
            prefs.getString(GoogleOAuthManager.keyUserEmail) ??
            prefs.getString('user_email');
        final scheduleKey = '${effectiveUid ?? ''}_${effectiveEmail ?? ''}';

        if (!forceRefresh &&
            _cachedScheduleEvents != null &&
            _cachedScheduleKey == scheduleKey &&
            _cachedScheduleTime != null &&
            DateTime.now().difference(_cachedScheduleTime!) < _widgetCacheTtl) {
          return _cachedScheduleEvents!;
        }
        try {
          final res = await _scheduleService.fetchEvents(
            uid: effectiveUid,
            email: effectiveEmail,
            forceRefresh: forceRefresh,
          );
          // fetchEvents returns [] both for "no classes" and "offline with no
          // cache"; treat empty as not refreshed so offline runs don't wipe.
          if (res.isEmpty) scheduleRefreshFailed = true;
          _cachedScheduleEvents = res;
          _cachedScheduleKey = scheduleKey;
          _cachedScheduleTime = DateTime.now();
          return res;
        } catch (e, stack) {
          AppLogger.error(
            'Failed to fetch ROCIs Schedule events for widget',
            error: e,
            stack: stack,
          );
          scheduleRefreshFailed = true;
          return _cachedScheduleEvents ?? [];
        }
      }

      // 4. Load localization
      Future<AppLocalizations?> fetchL10n() async {
        if (_cachedLocaleCode == localeCode && _cachedL10n != null) {
          return _cachedL10n;
        }
        try {
          final loaded = await AppLocalizations.delegate.load(
            Locale(localeCode),
          );
          _cachedLocaleCode = localeCode;
          _cachedL10n = loaded;
          return loaded;
        } catch (e) {
          AppLogger.debug('Failed to load l10n for widget service: $e');
          return _cachedL10n;
        }
      }

      // Run network/IO queries in parallel
      final asyncResults = await Future.wait([
        fetchGoogleEvents(),
        fetchColors(),
        fetchScheduleEvents(),
        fetchL10n(),
      ]);

      final events = asyncResults[0] as List<dynamic>;
      final calendarColors = asyncResults[1] as Map<String, String>;
      final scheduleEvents = asyncResults[2] as List<SyncedScheduleEvent>;
      final l10n = asyncResults[3] as AppLocalizations?;

      // Pre-index Google events by date for O(1) lookup
      final eventsByDate = <String, List<dynamic>>{};
      for (final event in events) {
        if (event.start == null) continue;
        // Same rule as the in-app calendar: local time, and an end at midnight
        // is exclusive (all-day events end at the next day's midnight, so they
        // must not spill into that day).
        final start = (event.start as DateTime).toLocal();
        final end =
            ((event.end as DateTime?) ?? start.add(const Duration(hours: 1)))
                .toLocal();
        final eventStart = DateTime(start.year, start.month, start.day);
        final endDay = DateTime(end.year, end.month, end.day);

        // Add event to every day it spans
        var day = eventStart;
        while (!day.isAfter(endDay)) {
          if (day == endDay &&
              day != eventStart &&
              end.hour == 0 &&
              end.minute == 0 &&
              end.second == 0 &&
              end.millisecond == 0) {
            break;
          }
          final key = DateFormat('yyyy-MM-dd').format(day);
          eventsByDate.putIfAbsent(key, () => []).add(event);
          day = DateTime(day.year, day.month, day.day + 1);
        }
      }

      // Pre-index ROCIs Schedule events by date for O(1) lookup across the multi-month buffer
      final scheduleEventsByDate = <String, List<SyncedScheduleEvent>>{};
      if (filters.showRocisSchedule) {
        for (final sEvent in scheduleEvents) {
          if (sEvent.recurring) {
            DateTime day = bufferStartDate;
            while (!day.isAfter(bufferEndDate)) {
              if (sEvent.occursOnDay(day)) {
                final key = DateFormat('yyyy-MM-dd').format(day);
                scheduleEventsByDate.putIfAbsent(key, () => []).add(sEvent);
              }
              day = DateTime(day.year, day.month, day.day + 1);
            }
          } else {
            if (sEvent.occursOnDay(sEvent.startTime)) {
              final key = DateFormat('yyyy-MM-dd').format(sEvent.startTime);
              scheduleEventsByDate.putIfAbsent(key, () => []).add(sEvent);
            }
          }
        }
      }

      // Pre-load categories for color lookup and privacy
      final categories = _taskSource.getCategories();

      // Tasks: exactly the ones the in-app calendar shows — the task list after
      // the user's saved list filters, each on its due date (recurring tasks
      // are not expanded), plus premium previews of the next recurrence.
      final tasksByDate = <String, List<dynamic>>{};
      if (filters.showTasks) {
        try {
          final isPremium =
              await HomeWidget.getWidgetData<bool>('is_premium') ?? false;
          final categoryById = {for (final c in categories) c.id: c};
          bool isPrivateTask(Task t) => [
            ...t.categoryIds,
            if (t.categoryId != null) t.categoryId!,
          ].any((id) => categoryById[id]?.isPrivate == true);
          // A home-screen widget is never "unlocked": hide private tasks
          // whenever private mode is on, like the other widgets.
          final hidePrivate =
              isPremium && (prefs.getBool('private_mode_enabled_v1') ?? false);

          final dateFilterIndex = prefs.getInt('date_filter');
          final filterService = TaskFilterService()
            ..showCompleted = prefs.getBool('show_completed') ?? true
            ..selectedCategoryIds =
                prefs.getStringList('category_filters') ?? []
            ..currentDateFilter =
                dateFilterIndex != null &&
                    dateFilterIndex < DateTimeFilterOption.values.length
                ? DateTimeFilterOption.values[dateFilterIndex]
                : DateTimeFilterOption.all;
          final visibleTasks = filterService.filterAndSortTasks(
            allTasks: _taskSource.getTasks(),
            getCategoryById: (id) => id == null ? null : categoryById[id],
            isPrivateTask: isPrivateTask,
            shouldMaskPrivateContent: hidePrivate,
          );
          for (final t in visibleTasks) {
            if (t.dueDate == null || (hidePrivate && isPrivateTask(t))) {
              continue;
            }
            final key = DateFormat('yyyy-MM-dd').format(t.dueDate!);
            tasksByDate.putIfAbsent(key, () => []).add(t);
          }

          if (isPremium) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            for (final t in _taskSource.getTasks()) {
              final next = t.nextRecurrenceDate;
              if (!t.isCompleted || next == null || (t.isDeleted ?? false)) {
                continue;
              }
              if (hidePrivate && isPrivateTask(t)) continue;
              if (!DateTime(next.year, next.month, next.day).isAfter(today)) {
                continue;
              }
              final key = DateFormat('yyyy-MM-dd').format(next);
              tasksByDate
                  .putIfAbsent(key, () => [])
                  .add(
                    TaskRecurrenceService.createUpcomingPreviewTask(t, next),
                  );
            }
          }
        } catch (e, stack) {
          AppLogger.error(
            'Failed to fetch tasks for widget',
            error: e,
            stack: stack,
          );
        }
      }

      // Master summary builder for any given date
      List<Map<String, dynamic>> buildSummariesForDate(String dateKey) {
        final dayEvents = eventsByDate[dateKey] ?? [];
        final dayTasks = tasksByDate[dateKey] ?? [];
        final daySchedule = scheduleEventsByDate[dateKey] ?? [];

        final summaries = <Map<String, dynamic>>[];

        // 1. Prioritize tasks
        for (final t in dayTasks) {
          if (summaries.length >= _maxSummariesPerDay) break;
          int? colorVal;
          try {
            final cat = categories.firstWhere(
              (c) => t.categoryIds.isNotEmpty
                  ? t.categoryIds.contains(c.id)
                  : c.id == t.categoryId,
            );
            colorVal = cat.colorValue;
          } catch (_) {}

          final title = t.title.length > 25
              ? '${t.title.substring(0, 22)}...'
              : t.title;

          summaries.add({
            'text': title,
            'priority': t.priority.toString().split('.').last,
            'color': colorVal != null
                ? '#${colorVal.toRadixString(16).padLeft(8, '0')}'
                : taskColorHex,
            'type': 'task',
          });
        }

        // 2. Google Calendar events
        for (final e in dayEvents) {
          if (summaries.length >= _maxSummariesPerDay) break;
          final timeStr = e.start != null
              ? _formatEventTime(e.start, e.end, l10n)
              : '';

          final displayTitle = e.title ?? l10n?.event ?? 'Event';
          final title = displayTitle.length > 25
              ? '${displayTitle.substring(0, 22)}...'
              : displayTitle;
          final location = (e.location ?? '').length > 20
              ? '${(e.location ?? '').substring(0, 17)}...'
              : (e.location ?? '');

          final eventColor =
              e.calendarId != null && calendarColors.containsKey(e.calendarId)
              ? calendarColors[e.calendarId]
              : googleColorHex;

          summaries.add({
            'text': title,
            'time': timeStr,
            'subtitle': location,
            'color': eventColor,
            'type': 'google',
          });
        }

        // 3. ROCIs Schedule events
        for (final s in daySchedule) {
          if (summaries.length >= _maxSummariesPerDay) break;
          final timeStr = _formatEventTime(s.startTime, s.endTime, l10n);
          final displayTitle = s.courseName.isNotEmpty
              ? (s.title.isNotEmpty &&
                        s.title.toLowerCase().trim() !=
                            s.courseName.toLowerCase().trim()
                    ? '${s.courseName}: ${s.title}'
                    : s.courseName)
              : (s.title.isNotEmpty ? s.title : (l10n?.event ?? 'Class'));
          final title = displayTitle.length > 28
              ? '${displayTitle.substring(0, 25)}...'
              : displayTitle;
          final rawSubtitle = s.location.isNotEmpty
              ? (s.courseCode.isNotEmpty
                    ? '${s.courseCode} • ${s.location}'
                    : s.location)
              : s.courseCode;
          final location = rawSubtitle.length > 25
              ? '${rawSubtitle.substring(0, 22)}...'
              : rawSubtitle;
          final eventColor =
              '#${s.color.toARGB32().toRadixString(16).padLeft(8, '0')}';

          summaries.add({
            'text': title,
            'time': timeStr,
            'subtitle': location,
            'color': eventColor,
            'type': 'schedule',
          });
        }

        return summaries;
      }

      // Build master multi-month summaries map for instantaneous native widget navigation
      final allDateKeys = <String>{
        ...tasksByDate.keys,
        ...eventsByDate.keys,
        ...scheduleEventsByDate.keys,
      };
      final masterSummariesByDate = <String, List<Map<String, dynamic>>>{};
      for (final dateKey in allDateKeys) {
        final list = buildSummariesForDate(dateKey);
        if (list.isNotEmpty) {
          masterSummariesByDate[dateKey] = list;
        }
      }

      // Carry forward previously saved entries only for sources that could
      // not be refreshed this run. Merging every old date back in made the
      // saved data append-only, so deleted events and wrong dates from older
      // versions lingered in the widget forever.
      final staleTypes = <String>{
        if (filters.showGoogleCalendar && googleRefreshFailed) 'google',
        if (filters.showRocisSchedule && scheduleRefreshFailed) 'schedule',
      };
      if (staleTypes.isNotEmpty) {
        try {
          final existingEventsJson = await HomeWidget.getWidgetData<String>(
            'full_calendar_events_by_date',
          );
          if (existingEventsJson != null && existingEventsJson.isNotEmpty) {
            mergeStaleSummaries(
              masterSummariesByDate,
              jsonDecode(existingEventsJson) as Map<String, dynamic>,
              staleTypes,
            );
          }
        } catch (_) {}
      }

      final eventsByDateJson = jsonEncode(masterSummariesByDate);

      // Build 42-day calendar grid for targetMonth
      final gridData = <Map<String, dynamic>>[];

      for (int row = 0; row < 6; row++) {
        final rowStartDate = startDate.add(Duration(days: row * 7));
        final weekNumber = _getWeekNumber(rowStartDate);

        gridData.add({'isWeekNumber': true, 'weekNumber': weekNumber});

        for (int col = 0; col < 7; col++) {
          final date = rowStartDate.add(Duration(days: col));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final summaries = masterSummariesByDate[dateKey] ?? [];

          gridData.add({
            'isWeekNumber': false,
            'date': dateKey,
            'day': date.day,
            'isCurrentMonth': date.month == targetMonth.month,
            'isToday':
                date.year == now.year &&
                date.month == now.month &&
                date.day == now.day,
            'summaries': summaries,
          });
        }
      }

      // If the newly generated grid has 0 summaries but previous grid was populated,
      // preserve previous grid to prevent empty-screen wipe during background sleep/offline
      final int totalSummaries = gridData.fold<int>(
        0,
        (sum, day) => sum + ((day['summaries'] as List?)?.length ?? 0),
      );
      if (totalSummaries == 0 && masterSummariesByDate.isEmpty) {
        final existingData = await HomeWidget.getWidgetData<String>(
          'full_calendar_grid_data',
        );
        if (existingData != null &&
            existingData.isNotEmpty &&
            existingData != '[]') {
          try {
            final decoded = jsonDecode(existingData) as List<dynamic>;
            final int existingSummaries = decoded.fold<int>(
              0,
              (sum, day) => sum + ((day['summaries'] as List?)?.length ?? 0),
            );
            if (existingSummaries > 0) {
              AppLogger.warning(
                'Newly generated grid has 0 summaries while existing grid has $existingSummaries. Preserving existing grid.',
              );
              return;
            }
          } catch (_) {}
        }
      }

      // Save all widget data atomically
      final gridDataJson = jsonEncode(gridData);

      if (gridDataJson.length > 500000) {
        AppLogger.warning(
          'FullCalendar widget data is very large: ${gridDataJson.length} bytes',
        );
      }

      // Batch all SharedPreferences writes before signaling the widget
      await Future.wait([
        HomeWidget.saveWidgetData<String>(
          'full_calendar_events_by_date',
          eventsByDateJson,
        ),
        HomeWidget.saveWidgetData<String>(
          'full_calendar_grid_data',
          gridDataJson,
        ),
        HomeWidget.saveWidgetData<String>(
          'full_calendar_month_name',
          monthName,
        ),
        HomeWidget.saveWidgetData<int>('full_calendar_offset', offset),
        HomeWidget.saveWidgetData<bool>(
          'full_calendar_show_tasks',
          filters.showTasks,
        ),
        HomeWidget.saveWidgetData<bool>(
          'full_calendar_show_google',
          filters.showGoogleCalendar,
        ),
        HomeWidget.saveWidgetData<bool>(
          'full_calendar_show_schedule',
          filters.showRocisSchedule,
        ),
      ]);

      // Small delay to ensure SharedPreferences are flushed to disk
      // before the native widget reads them
      await Future.delayed(const Duration(milliseconds: 100));

      // Signal update for widget
      await HomeWidget.updateWidget(
        name: 'FullCalendarWidgetProvider',
        iOSName: 'FullCalendarWidget',
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error in FullCalendarWidgetService.updateFullCalendarWidget',
        error: e,
        stack: stack,
      );
      final existingData = await HomeWidget.getWidgetData<String>(
        'full_calendar_grid_data',
      );
      if (existingData == null ||
          existingData.isEmpty ||
          existingData == '[]') {
        await _generateFallbackGrid(monthOffset, userId);
      }
    }
  }

  /// Adds saved summaries of [staleTypes] (sources that failed to refresh)
  /// back into [fresh], keeping at most [_maxSummariesPerDay] per day.
  @visibleForTesting
  static void mergeStaleSummaries(
    Map<String, List<Map<String, dynamic>>> fresh,
    Map<String, dynamic> saved,
    Set<String> staleTypes,
  ) {
    for (final entry in saved.entries) {
      if (entry.value is! List) continue;
      final kept = (entry.value as List)
          .whereType<Map<String, dynamic>>()
          .where((summary) => staleTypes.contains(summary['type']))
          .toList();
      if (kept.isEmpty) continue;
      final day = fresh.putIfAbsent(entry.key, () => []);
      for (final summary in kept) {
        if (day.length >= _maxSummariesPerDay) break;
        day.add(summary);
      }
    }
  }

  /// Update the selected date on the widget and trigger refresh
  Future<void> updateSelectedDate(DateTime date, String? userId) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      await HomeWidget.saveWidgetData<String>(
        'full_calendar_selected_date',
        dateStr,
      );
      await updateFullCalendarWidget(userId: userId);
    } catch (e, stack) {
      AppLogger.error(
        'Failed to update selected date on widget',
        error: e,
        stack: stack,
      );
    }
  }

  /// Generates a grid with just dates (no events) to prevent blank widget
  Future<void> _generateFallbackGrid(int? monthOffset, String? userId) async {
    try {
      final existingData = await HomeWidget.getWidgetData<String>(
        'full_calendar_grid_data',
      );
      if (existingData != null &&
          existingData.isNotEmpty &&
          existingData != '[]') {
        AppLogger.info(
          'Preserving existing full_calendar_grid_data instead of overwriting with fallback',
        );
        return;
      }

      final int offset =
          monthOffset ??
          (await HomeWidget.getWidgetData<int>('full_calendar_offset') ?? 0);

      final prefs = await SharedPreferences.getInstance();
      final localeCode =
          prefs.getString('language_code') ??
          PlatformDispatcher.instance.locale.languageCode;
      final now = DateTime.now();
      final targetMonth = DateTime(now.year, now.month + offset, 1);
      final monthName = DateFormat('MMMM yyyy', localeCode).format(targetMonth);
      // Calculate calendar grid (6 weeks) based on startOfWeek preference (7=Sunday, 1=Monday, 6=Saturday)
      final startOfWeek = prefs.getInt('full_calendar_start_of_week') ?? 7;
      final firstDayOfMonth = targetMonth;
      final difference = (firstDayOfMonth.weekday - startOfWeek) % 7;
      final startDate = firstDayOfMonth.subtract(Duration(days: difference));

      final gridData = <Map<String, dynamic>>[];

      for (int row = 0; row < 6; row++) {
        final rowStartDate = startDate.add(Duration(days: row * 7));
        final weekNumber = _getWeekNumber(rowStartDate);

        gridData.add({'isWeekNumber': true, 'weekNumber': weekNumber});

        for (int col = 0; col < 7; col++) {
          final date = rowStartDate.add(Duration(days: col));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);

          gridData.add({
            'isWeekNumber': false,
            'date': dateKey,
            'day': date.day,
            'isCurrentMonth': date.month == targetMonth.month,
            'isToday':
                date.year == now.year &&
                date.month == now.month &&
                date.day == now.day,
            'summaries': [], // Empty summaries
          });
        }
      }

      final gridDataJson = jsonEncode(gridData);
      await HomeWidget.saveWidgetData<String>(
        'full_calendar_grid_data',
        gridDataJson,
      );
      await HomeWidget.saveWidgetData<String>(
        'full_calendar_month_name',
        monthName,
      );

      await HomeWidget.updateWidget(
        name: 'FullCalendarWidgetProvider',
        iOSName: 'FullCalendarWidget',
      );
    } catch (e, stack) {
      AppLogger.error(
        'Critical failure in widget fallback',
        error: e,
        stack: stack,
      );
    }
  }

  String _formatEventTime(
    DateTime? start,
    DateTime? end,
    AppLocalizations? l10n,
  ) {
    if (start == null) return '';

    // Handle all-day events (when end is null or same day start/end with no time difference)
    if (end == null) {
      return DateFormat('HH:mm').format(start);
    }

    // Check if it's an all-day event (same date, start at midnight, end at midnight next day)
    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);

    if (startOnly == endOnly &&
        start.hour == 0 &&
        start.minute == 0 &&
        end.hour == 0 &&
        end.minute == 0) {
      return l10n?.allDay ?? 'All Day';
    }

    // Same day event
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '${DateFormat('HH:mm').format(start)}-${DateFormat('HH:mm').format(end)}';
    }

    // Multi-day event
    return '${DateFormat('MM/dd HH:mm').format(start)}-${DateFormat('MM/dd HH:mm').format(end)}';
  }

  int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat('D').format(date));
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
