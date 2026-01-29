import 'dart:convert';
import 'package:flutter/material.dart';
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
    debugPrint(
      'FullCalendarWidgetService: toggleFilter called for $filterName',
    );
    final current = await getFilters();
    debugPrint(
      'FullCalendarWidgetService: Current filters - tasks: ${current.showTasks}, google: ${current.showGoogleCalendar}, rocis: ${current.showRocisSchedule}',
    );
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
        debugPrint(
          'FullCalendarWidgetService: Unknown filter name: $filterName',
        );
        updated = current;
    }

    debugPrint(
      'FullCalendarWidgetService: Updated filters - tasks: ${updated.showTasks}, google: ${updated.showGoogleCalendar}, rocis: ${updated.showRocisSchedule}',
    );
    await saveFilters(updated);
    debugPrint('FullCalendarWidgetService: Filters saved');
    return updated;
  }

  Future<void> updateFullCalendarWidget({
    int? monthOffset,
    String? userId,
  }) async {
    debugPrint(
      'FullCalendarWidget: updateFullCalendarWidget started with offset: $monthOffset',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final int offset =
          monthOffset ?? (prefs.getInt('full_calendar_offset') ?? 0);

      debugPrint('FullCalendarWidget: Using offset: $offset');

      // Save offset if provided
      if (monthOffset != null) {
        await prefs.setInt('full_calendar_offset', offset);
      }

      // Get filter settings
      final filters = await getFilters();
      debugPrint(
        'FullCalendarWidget: Filters - tasks: ${filters.showTasks}, google: ${filters.showGoogleCalendar}, rocis: ${filters.showRocisSchedule}',
      );

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
      debugPrint('FullCalendarWidget: Target month: $monthName');

      // Calculate calendar grid (5 weeks)
      final firstDayOfMonth = targetMonth;
      final difference = firstDayOfMonth.weekday % 7;
      final startDate = firstDayOfMonth.subtract(Duration(days: difference));
      final endDate = startDate.add(
        const Duration(days: 34),
      ); // 35 days (5 weeks)

      debugPrint('FullCalendarWidget: Date range: $startDate to $endDate');

      // Fetch Google Calendar events (if filter enabled)
      final events = filters.showGoogleCalendar
          ? await _calendarService.getEvents(
              startDate: startDate,
              endDate: endDate,
              calendarIds: filters.selectedCalendarIds,
            )
          : [];

      // Fetch tasks (if filter enabled)
      final allTasks = _taskSource.getTasks();
      final tasks = filters.showTasks
          ? allTasks
                .where(
                  (t) =>
                      !(t.isDeleted ?? false) &&
                      !t.isCompleted &&
                      t.dueDate != null,
                )
                .toList()
          : [];

      // Fetch ROCIs-Schedule events (if filter enabled and user is authenticated)
      List<Map<String, dynamic>> scheduleData = [];
      if (filters.showRocisSchedule &&
          _scheduleService.isReady &&
          _scheduleService.isAuthenticated) {
        try {
          final effectiveUserId = userId ?? 'default';
          scheduleData = await _scheduleService.getScheduleDataForWidget(
            effectiveUserId,
            startDate,
            endDate,
          );
          debugPrint(
            'FullCalendarWidget: Fetched ${scheduleData.length} ROCIs-Schedule items',
          );
        } catch (e) {
          debugPrint(
            'FullCalendarWidget: Error fetching ROCIs-Schedule data: $e',
          );
        }
      }

      debugPrint(
        'FullCalendarWidget: Found ${events.length} Google events, ${tasks.length} tasks, ${scheduleData.length} schedule items',
      );

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
            final itemDate = DateTime.parse(item['date'] as String);
            final itemDateKey = DateFormat('yyyy-MM-dd').format(itemDate);
            return itemDateKey == dateKey;
          }).toList();

          // Create summaries (up to 3 items)
          final summaries = <Map<String, dynamic>>[];

          for (var e in dayEvents) {
            if (summaries.length >= 3) break;
            final timeStr = e.start != null
                ? DateFormat('HH:mm').format(e.start!)
                : '';
            summaries.add({
              'text': e.title ?? 'Event',
              'time': timeStr,
              'subtitle': e.location ?? '',
              'color': googleColorHex,
              'type': 'google',
            });
          }

          // Add ROCIs-Schedule events and assignments (custom colors)
          for (var item in dayScheduleItems) {
            if (summaries.length >= 3) break;
            final type = item['type'] as String;
            final color = type == 'assignment'
                ? assignmentColorHex
                : scheduleColorHex;
            // Normalize type for filtering - both schedule_event and assignment should be filtered by 'rocis' filter
            final itemDateStr = item['date'] as String;
            final itemDate = DateTime.parse(itemDateStr);
            final startTime = item['startTime'] != null
                ? DateFormat('HH:mm').format(itemDate)
                : '';

            // Normalize type for filtering - both schedule_event and assignment should be filtered by 'rocis' filter
            summaries.add({
              'text': item['title'] as String,
              'time': startTime,
              'subtitle': item['location'] ?? '',
              'color': color,
              'type': type, // Keep original type (schedule_event or assignment)
            });
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

            summaries.add({
              'text': t.title,
              'priority': t.priority.name,
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

      debugPrint('FullCalendarWidget: Generated ${gridData.length} grid cells');

      // Save Data
      final gridDataJson = jsonEncode(gridData);
      debugPrint(
        'FullCalendarWidget: Saving grid data (length: ${gridDataJson.length})',
      );
      await HomeWidget.saveWidgetData<String>(
        'full_calendar_grid_data',
        gridDataJson,
      );

      // Save Month Name
      debugPrint('FullCalendarWidget: Saving month name: $monthName');
      await HomeWidget.saveWidgetData<String>(
        'full_calendar_month_name',
        monthName,
      );

      // Save filter states for widget display
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

      debugPrint(
        'FullCalendarWidget: Signaling update for FullCalendarWidgetProvider',
      );

      await HomeWidget.updateWidget(
        name: 'FullCalendarWidgetProvider',
        iOSName: 'FullCalendarWidget',
      );

      debugPrint('FullCalendarWidget: updateWidget call successfully signaled');
    } catch (e, stack) {
      debugPrint(
        'FullCalendarWidget: CRITICAL ERROR in updateFullCalendarWidget: $e\n$stack',
      );
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
