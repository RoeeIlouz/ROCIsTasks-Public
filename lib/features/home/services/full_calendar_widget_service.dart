import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

/// Filter options for the full calendar widget
class FullCalendarFilters {
  final bool showTasks;
  final bool showGoogleCalendar;
  final bool showRocisSchedule;
  final List<String> selectedCalendarIds;

  const FullCalendarFilters({
    this.showTasks = true,
    this.showGoogleCalendar = true,
    this.showRocisSchedule = false,
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
      showRocisSchedule: false,
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

  FullCalendarWidgetService(this._calendarService, this._taskSource);

  /// Initialize the schedule service
  Future<void> initScheduleService() async {}

  /// Set the user email for ROCIs-Schedule lookup
  void setUserEmail(String? email) {}

  /// Get current filter settings
  Future<FullCalendarFilters> getFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final showTasks = prefs.getBool('full_calendar_show_tasks') ?? true;
    final showGoogle = prefs.getBool('full_calendar_show_google') ?? true;
    final selectedCalendarIds =
        prefs.getStringList('full_calendar_selected_ids') ?? [];

    return FullCalendarFilters(
      showTasks: showTasks,
      showGoogleCalendar: showGoogle,
      showRocisSchedule: false,
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
    await prefs.setBool('full_calendar_show_rocis', false);
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
    await HomeWidget.saveWidgetData<bool>('full_calendar_show_rocis', false);
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
      default:
        updated = current;
    }

    await saveFilters(updated);
    return updated;
  }

  Future<void> updateFullCalendarWidget({
    int? monthOffset,
    String? userId,
  }) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final int offset =
          monthOffset ??
          (await HomeWidget.getWidgetData<int>('full_calendar_offset') ?? 0);

      // Save offset if provided
      if (monthOffset != null) {
        await HomeWidget.saveWidgetData<int>('full_calendar_offset', offset);
      }

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

      // Fetch Google Calendar events (if filter enabled)
      var events = <dynamic>[];
      Map<String, String> calendarColors = {};
      try {
        if (filters.showGoogleCalendar) {
          events = await _calendarService.getEvents(
            startDate: startDate,
            endDate: endDate,
            calendarIds: filters.selectedCalendarIds,
          );
          calendarColors = await _calendarService.getCalendarColors();
        }
      } catch (e, stack) {
        AppLogger.error(
          'Failed to fetch Google Calendar events for widget',
          error: e,
          stack: stack,
        );
      }

      // Pre-index events by date for O(1) lookup instead of O(n) per day
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

      // Load localization for background strings
      AppLocalizations? l10n;
      try {
        final localeCode = prefs.getString('language_code') ?? 'en';
        l10n = await AppLocalizations.delegate.load(Locale(localeCode));
      } catch (e) {
        AppLogger.debug('Failed to load l10n for widget service: $e');
      }

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
        HomeWidget.saveWidgetData<bool>(
          'full_calendar_show_tasks',
          filters.showTasks,
        ),
        HomeWidget.saveWidgetData<bool>(
          'full_calendar_show_google',
          filters.showGoogleCalendar,
        ),
        HomeWidget.saveWidgetData<bool>('full_calendar_show_rocis', false),
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
      await _generateFallbackGrid(monthOffset, userId);
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
