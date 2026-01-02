import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FullCalendarWidgetService {
  final CalendarService _calendarService;
  final LocalTaskSource _taskSource;

  FullCalendarWidgetService(this._calendarService, this._taskSource);

  Future<void> updateFullCalendarWidget({int? monthOffset}) async {
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

      // Fetch events and tasks
      final events = await _calendarService.getEvents(
        startDate: startDate,
        endDate: endDate,
      );
      final allTasks = _taskSource.getTasks();
      final tasks = allTasks
          .where(
            (t) =>
                !(t.isDeleted ?? false) && !t.isCompleted && t.dueDate != null,
          )
          .toList();

      debugPrint(
        'FullCalendarWidget: Found ${events.length} events and ${tasks.length} tasks',
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

          // Find events for this day
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

          // Create summaries (up to 3 items)
          final summaries = <Map<String, dynamic>>[];

          for (var e in dayEvents) {
            if (summaries.length >= 3) break;
            summaries.add({
              'text': e.title ?? 'Event',
              'color': '#4285F4', // Google Calendar blue
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
              'color': colorVal != null
                  ? '#${colorVal.toRadixString(16).padLeft(8, '0')}'
                  : '#9E9E9E',
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
