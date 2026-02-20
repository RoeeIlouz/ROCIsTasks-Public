import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  FullCalendarWidgetService(this._calendarService, this._taskSource)
    : _scheduleService = ScheduleFirestoreService();

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
    return FullCalendarFilters(
      showTasks: prefs.getBool('full_calendar_show_tasks') ?? true,
      showGoogleCalendar: prefs.getBool('full_calendar_show_google') ?? true,
      showRocisSchedule: prefs.getBool('full_calendar_show_rocis') ?? true,
      selectedCalendarIds:
          prefs.getStringList('full_calendar_selected_ids') ?? [],
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
    await prefs.setBool('full_calendar_show_rocis', filters.showRocisSchedule);
    await prefs.setStringList(
      'full_calendar_selected_ids',
      filters.selectedCalendarIds,
    );

    // Also save to widget data for native access
    await HomeWidget.saveWidgetData<bool>(
      'full_calendar_show_tasks',
      filters.showTasks,
    );
    await HomeWidget.saveWidgetData<bool>(
      'full_calendar_show_google',
      filters.showGoogleCalendar,
    );
    await HomeWidget.saveWidgetData<bool>(
      'full_calendar_show_rocis',
      filters.showRocisSchedule,
    );
    await HomeWidget.saveWidgetData<String>(
      'full_calendar_selected_ids',
      jsonEncode(filters.selectedCalendarIds),
    );
  }

  /// Toggle a specific filter
  Future<FullCalendarFilters> toggleFilter(String filterName) async {
    // Toggle filter called
    final current = await getFilters();
    // Current filters retrieved
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
      case 'rocis':
        updated = current.copyWith(
          showRocisSchedule: !current.showRocisSchedule,
        );
        break;
      default:
        // Unknown filter name
        updated = current;
    }

    // Updated filters applied
    await saveFilters(updated);
    // Filters saved
    return updated;
  }

  Future<void> updateFullCalendarWidget({
    int? monthOffset,
    String? userId,
  }) async {
    // updateFullCalendarWidget started
    try {
      final prefs = await SharedPreferences.getInstance();
      final int offset =
          monthOffset ??
          (await HomeWidget.getWidgetData<int>('full_calendar_offset') ?? 0);

      // Using offset

      // Save offset if provided
      if (monthOffset != null) {
        await HomeWidget.saveWidgetData<int>('full_calendar_offset', offset);
      }

      // Get filter settings
      final filters = await getFilters();
      // Filters loaded

      // Get custom colors (stored as int values)
      final taskColorInt =
          prefs.getInt(CalendarColorService.keyTaskColor) ??
          CalendarColorService.defaultTaskColor.toARGB32();
      final googleColorInt =
          prefs.getInt(CalendarColorService.keyGoogleColor) ??
          CalendarColorService.defaultGoogleColor.toARGB32();
      final scheduleColorInt =
          prefs.getInt(CalendarColorService.keyScheduleColor) ??
          CalendarColorService.defaultScheduleColor.toARGB32();
      final assignmentColorInt =
          prefs.getInt(CalendarColorService.keyAssignmentColor) ??
          CalendarColorService.defaultAssignmentColor.toARGB32();

      // Convert to hex strings
      final taskColorHex = '#${taskColorInt.toRadixString(16).padLeft(8, '0')}';
      final googleColorHex =
          '#${googleColorInt.toRadixString(16).padLeft(8, '0')}';
      final scheduleColorHex =
          '#${scheduleColorInt.toRadixString(16).padLeft(8, '0')}';
      final assignmentColorHex =
          '#${assignmentColorInt.toRadixString(16).padLeft(8, '0')}';

      final now = DateTime.now();
      final targetMonth = DateTime(now.year, now.month + offset, 1);
      final monthName = DateFormat('MMMM yyyy').format(targetMonth);
      // Target month calculated

      // Calculate calendar grid (5 weeks)
      final firstDayOfMonth = targetMonth;
      final difference = firstDayOfMonth.weekday % 7;
      final startDate = firstDayOfMonth.subtract(Duration(days: difference));
      final endDate = startDate.add(
        const Duration(days: 34),
      ); // 35 days (5 weeks)

      // Date range calculated

      // Fetch Google Calendar events (if filter enabled)
      var events = [];
      try {
        if (filters.showGoogleCalendar) {
          events = await _calendarService.getEvents(
            startDate: startDate,
            endDate: endDate,
            calendarIds: filters.selectedCalendarIds,
          );
        }
      } catch (e) {
        // Ignore Google Calendar fetch errors to prevent widget crash
      }

      // Fetch tasks (if filter enabled)
      var tasks = <dynamic>[];
      try {
        final allTasks = _taskSource.getTasks();
        if (filters.showTasks) {
          tasks = allTasks
              .where(
                (t) =>
                    !(t.isDeleted ?? false) &&
                    !t.isCompleted &&
                    t.dueDate != null,
              )
              .toList();
        }
      } catch (e) {
        // Ignore task fetch errors
      }

      // Fetch ROCIs-Schedule events (if filter enabled and user is authenticated)
      List<Map<String, dynamic>> scheduleData = [];
      try {
        if (filters.showRocisSchedule &&
            _scheduleService.isReady &&
            _scheduleService.isAuthenticated) {
          final effectiveUserId = userId ?? 'default';
          scheduleData = await _scheduleService.getScheduleDataForWidget(
            effectiveUserId,
            startDate,
            endDate,
          );
          // Fetched ROCIs-Schedule items
        }
      } catch (e) {
        // Ignore schedule fetch errors
      }

      // Found events, tasks, and schedule items

      final gridData = <Map<String, dynamic>>[];

      for (int row = 0; row < 5; row++) {
        // First cell of each row is the Week Number
        final rowStartDate = startDate.add(Duration(days: row * 7));
        final weekNumber = _getWeekNumber(rowStartDate);

        gridData.add({'isWeekNumber': true, 'weekNumber': weekNumber});

        for (int col = 0; col < 7; col++) {
          final date = rowStartDate.add(Duration(days: col));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);

          // Find Google Calendar events for this day
          final dayEvents = events.where((e) {
            if (e.start == null) return false;
            final eDate = DateFormat('yyyy-MM-dd').format(e.start!);
            return eDate == dateKey;
          }).toList();

          // Find tasks for this day
          final dayTasks = tasks.where((t) {
            if (t.dueDate == null) return false;
            final tDate = DateFormat('yyyy-MM-dd').format(t.dueDate!);
            return tDate == dateKey;
          }).toList();

          // Find ROCIs-Schedule items for this day
          final dayScheduleItems = scheduleData.where((item) {
            try {
              final dateObj = item['date'];
              if (dateObj == null) return false;

              DateTime itemDate;
              if (dateObj is DateTime) {
                itemDate = dateObj;
              } else if (dateObj is String) {
                itemDate = DateTime.parse(dateObj);
              } else {
                return false;
              }

              final itemDateKey = DateFormat('yyyy-MM-dd').format(itemDate);
              return itemDateKey == dateKey;
            } catch (e) {
              return false;
            }
          }).toList();

          // Create summaries (up to 3 items)
          final summaries = <Map<String, dynamic>>[];

          for (var e in dayEvents) {
            if (summaries.length >= 3) break;
            final timeStr = e.start != null
                ? DateFormat('HH:mm').format(e.start!)
                : '';

            final title = (e.title ?? 'Event').length > 30
                ? '${(e.title ?? 'Event').substring(0, 27)}...'
                : (e.title ?? 'Event');
            final location = (e.location ?? '').length > 30
                ? '${(e.location ?? '').substring(0, 27)}...'
                : (e.location ?? '');

            summaries.add({
              'text': title,
              'time': timeStr,
              'subtitle': location,
              'color': googleColorHex,
              'type': 'google',
            });
          }

          // Add ROCIs-Schedule events and assignments (custom colors)
          for (var item in dayScheduleItems) {
            if (summaries.length >= 3) break;
            try {
              final type = (item['type'] as String?) ?? 'schedule_event';
              final color = type == 'assignment'
                  ? assignmentColorHex
                  : scheduleColorHex;

              final itemDateStr = item['date'] as String?;
              if (itemDateStr == null) continue;

              final itemDate = DateTime.parse(itemDateStr);
              // Use the event date for time if startTime key is missing or null
              // schedule_event usually has a specific time, assignments usually don't (or are all day)
              final startTime = type == 'schedule_event'
                  ? DateFormat('HH:mm').format(itemDate)
                  : '';

              final rawTitle = (item['title'] as String?) ?? 'Event';
              final rawLocation = (item['location'] as String?) ?? '';

              final title = rawTitle.length > 30
                  ? '${rawTitle.substring(0, 27)}...'
                  : rawTitle;
              final location = rawLocation.length > 30
                  ? '${rawLocation.substring(0, 27)}...'
                  : rawLocation;

              summaries.add({
                'text': title,
                'time': startTime,
                'subtitle': location,
                'color': color,
                'type': type,
              });
            } catch (e) {
              // Ignore individual item errors to prevent widget crash
              continue;
            }
          }

          for (var t in dayTasks) {
            if (summaries.length >= 3) break;
            // Lookup category color
            int? colorVal;
            try {
              final cat = _taskSource.getCategories().firstWhere(
                (c) => c.id == t.categoryId,
              );
              colorVal = cat.colorValue;
            } catch (_) {}

            final title = t.title.length > 30
                ? '${t.title.substring(0, 27)}...'
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

      // Created grid

      // Save Data
      final gridDataJson = jsonEncode(gridData);

      if (gridDataJson.length > 500000) {}

      // Saving grid data
      await HomeWidget.saveWidgetData<String>(
        'full_calendar_grid_data',
        gridDataJson,
      );

      // Save Month Name
      await HomeWidget.saveWidgetData<String>(
        'full_calendar_month_name',
        monthName,
      );

      // Save filter states
      await HomeWidget.saveWidgetData<bool>(
        'full_calendar_show_tasks',
        filters.showTasks,
      );
      await HomeWidget.saveWidgetData<bool>(
        'full_calendar_show_google',
        filters.showGoogleCalendar,
      );
      await HomeWidget.saveWidgetData<bool>(
        'full_calendar_show_rocis',
        filters.showRocisSchedule,
      );

      // Signaling update for widget
      await HomeWidget.updateWidget(
        name: 'FullCalendarWidgetProvider',
        iOSName: 'FullCalendarWidget',
      );
    } catch (e) {
      // Attempt fallback to at least show the dates
      await _generateFallbackGrid(monthOffset, userId);
    }
  }

  /// Generates a grid with just dates (no events) to prevent blank widget
  Future<void> _generateFallbackGrid(int? monthOffset, String? userId) async {
    try {
      final int offset =
          monthOffset ??
          (await HomeWidget.getWidgetData<int>('full_calendar_offset') ?? 0);

      final now = DateTime.now();
      final targetMonth = DateTime(now.year, now.month + offset, 1);
      final monthName = DateFormat('MMMM yyyy').format(targetMonth);

      final firstDayOfMonth = targetMonth;
      final difference = firstDayOfMonth.weekday % 7;
      final startDate = firstDayOfMonth.subtract(Duration(days: difference));

      final gridData = <Map<String, dynamic>>[];

      for (int row = 0; row < 5; row++) {
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
    } catch (e) {
      // Ignore fallback grid generation errors
    }
  }

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
