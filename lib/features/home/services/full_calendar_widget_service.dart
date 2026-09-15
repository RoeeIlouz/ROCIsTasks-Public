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

      // Calculate calendar grid (6 weeks) based on startOfWeek preference (7=Sunday, 1=Monday, 6=Saturday)
      final startOfWeek = prefs.getInt('full_calendar_start_of_week') ?? 7;
      final firstDayOfMonth = targetMonth;
      final difference = (firstDayOfMonth.weekday - startOfWeek) % 7;
      final startDate = firstDayOfMonth.subtract(Duration(days: difference));
      final endDate = startDate.add(const Duration(days: 41));

      // 1. Fetch Google Calendar events (if filter enabled)
      Future<List<dynamic>> fetchGoogleEvents() async {
        if (!filters.showGoogleCalendar) return [];
        final cacheKey =
            '${startDate.toIso8601String()}_${endDate.toIso8601String()}_${filters.selectedCalendarIds.join(',')}';
        if (!forceRefresh &&
            _cachedEvents != null &&
            _cachedEventsKey == cacheKey &&
            _cachedEventsTime != null &&
            DateTime.now().difference(_cachedEventsTime!) < _widgetCacheTtl) {
          return _cachedEvents!;
        }
        try {
          final res = await _calendarService.getEvents(
            startDate: startDate,
            endDate: endDate,
            calendarIds: filters.selectedCalendarIds,
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
        final eventStart = DateTime(
          event.start!.year,
          event.start!.month,
          event.start!.day,
        );
        final end = event.end ?? event.start!.add(const Duration(hours: 1));
        final endDay = DateTime(end.year, end.month, end.day);

        // Add event to every day it spans
        var day = eventStart;
        while (!day.isAfter(endDay)) {
          // Skip the end day for non-all-day events ending at midnight
          if (day == endDay &&
              event.allDay != true &&
              end.hour == 0 &&
              end.minute == 0 &&
              end.second == 0 &&
              end.millisecond == 0) {
            break;
          }
          final key = DateFormat('yyyy-MM-dd').format(day);
          eventsByDate.putIfAbsent(key, () => []).add(event);
          day = day.add(const Duration(days: 1));
        }
      }

      // Pre-index ROCIs Schedule events by date for O(1) lookup
      final scheduleEventsByDate = <String, List<SyncedScheduleEvent>>{};
      if (filters.showRocisSchedule) {
        for (final sEvent in scheduleEvents) {
          if (sEvent.recurring) {
            DateTime day = startDate;
            while (!day.isAfter(endDate)) {
              if (sEvent.occursOnDay(day)) {
                final key = DateFormat('yyyy-MM-dd').format(day);
                scheduleEventsByDate.putIfAbsent(key, () => []).add(sEvent);
              }
              day = day.add(const Duration(days: 1));
            }
          } else {
            final key = DateFormat('yyyy-MM-dd').format(sEvent.startTime);
            scheduleEventsByDate.putIfAbsent(key, () => []).add(sEvent);
          }
        }
      }

      // Pre-index tasks by date for O(1) lookup
      final tasksByDate = <String, List<dynamic>>{};
      List<dynamic> filteredTasks = [];
      try {
        final allTasks = _taskSource.getTasks();
        if (filters.showTasks) {
          filteredTasks = allTasks
              .where(
                (t) =>
                    !(t.isDeleted ?? false) &&
                    !t.isCompleted &&
                    t.dueDate != null,
              )
              .toList();
        }
      } catch (e, stack) {
        AppLogger.error(
          'Failed to fetch tasks for widget',
          error: e,
          stack: stack,
        );
      }

      for (final t in filteredTasks) {
        final key = DateFormat('yyyy-MM-dd').format(t.dueDate!);
        tasksByDate.putIfAbsent(key, () => []).add(t);
      }

      // Pre-load categories for color lookup
      final categories = _taskSource.getCategories();

      final gridData = <Map<String, dynamic>>[];

      for (int row = 0; row < 6; row++) {
        final rowStartDate = startDate.add(Duration(days: row * 7));
        final weekNumber = _getWeekNumber(rowStartDate);

        gridData.add({'isWeekNumber': true, 'weekNumber': weekNumber});

        for (int col = 0; col < 7; col++) {
          final date = rowStartDate.add(Duration(days: col));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);

          // O(1) lookup instead of O(n) filter
          final dayEvents = eventsByDate[dateKey] ?? [];
          final dayTasks = tasksByDate[dateKey] ?? [];

          // Create summaries (up to 4 items)
          final summaries = <Map<String, dynamic>>[];

          // 1. Prioritize tasks
          for (final t in dayTasks) {
            if (summaries.length >= 4) break;
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

          for (final e in dayEvents) {
            if (summaries.length >= 4) break;
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

          for (final s in (scheduleEventsByDate[dateKey] ?? [])) {
            if (summaries.length >= 4) break;
            final timeStr = _formatEventTime(s.startTime, s.endTime, l10n);
            final displayTitle = s.title.isNotEmpty
                ? s.title
                : (l10n?.event ?? 'Class');
            final title = displayTitle.length > 25
                ? '${displayTitle.substring(0, 22)}...'
                : displayTitle;
            final location = s.location.length > 20
                ? '${s.location.substring(0, 17)}...'
                : s.location;
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
      // ONLY for the current month (offset == 0). For navigated months (offset != 0), allow empty grids.
      final int totalSummaries = gridData.fold<int>(
        0,
        (sum, day) => sum + ((day['summaries'] as List?)?.length ?? 0),
      );
      if (totalSummaries == 0 && offset == 0) {
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
                'Newly generated grid has 0 summaries while existing grid has $existingSummaries. Preserving existing grid for current month.',
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
