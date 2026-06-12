import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

class MonthWidgetService {
  final CalendarService _calendarService;
  final LocalTaskSource _taskSource;

  MonthWidgetService(this._calendarService, this._taskSource);

  Future<void> updateMonthWidget({int? monthOffset}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int offset =
          monthOffset ?? (prefs.getInt('month_widget_offset') ?? 0);

      // Save offset if provided
      if (monthOffset != null) {
        await prefs.setInt('month_widget_offset', offset);
      }

      final now = DateTime.now();
      final targetMonth = DateTime(now.year, now.month + offset, 1);

      // Month view now shows 5 weeks for more compact display
      final firstDayOfMonth = targetMonth;
      // Calculate start date (Sunday before or on firstDay)
      final difference = firstDayOfMonth.weekday % 7;
      final startDate = firstDayOfMonth.subtract(Duration(days: difference));
      final endDate = startDate.add(
        const Duration(days: 34),
      ); // 35 days total (5 weeks)

      final events = await _calendarService.getEvents(
        startDate: startDate,
        endDate: endDate,
      );
      final tasks = _taskSource
          .getTasks()
          .where(
            (t) =>
                !(t.isDeleted ?? false) && !t.isCompleted && t.dueDate != null,
          )
          .toList();

      final gridData = <Map<String, dynamic>>[];

      for (int row = 0; row < 5; row++) {
        // First cell of each row is the Week Number
        final rowStartDate = startDate.add(Duration(days: row * 7));
        final weekNumber = _getWeekNumber(rowStartDate);

        gridData.add({
          'isWeekNumber': true,
          'weekNumber': weekNumber,
          'isCurrentMonth': true, // Style as week number
          'isToday': false,
          'hasEvents': false,
          'hasTasks': false,
        });

        for (int col = 0; col < 7; col++) {
          final date = rowStartDate.add(Duration(days: col));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);

          // Find events for this day (including multi-day events)
          final dayEvents = events.where((e) {
            if (e.start == null) return false;

            // Normalize to dates (midnight)
            final eventStart = DateTime(
              e.start!.year,
              e.start!.month,
              e.start!.day,
            );

            // Handle null end by assuming 1 hour duration
            final end = e.end ?? e.start!.add(const Duration(hours: 1));
            final endDay = DateTime(end.year, end.month, end.day);

            final currentDate = date;

            // Standard inclusive-start, exclusive-end check
            if (currentDate.isBefore(eventStart) || currentDate.isAfter(endDay)) {
              return false;
            }

            // Special case: if end is exactly midnight and it is not the start day,
            // we don't include that day, unless it's an all-day event.
            if (currentDate == endDay &&
                e.allDay != true &&
                end.hour == 0 &&
                end.minute == 0 &&
                end.second == 0 &&
                end.millisecond == 0 &&
                currentDate != eventStart) {
              return false;
            }

            return true;
          }).toList();

          // Find tasks for this day
          final dayTasks = tasks.where((t) {
            if (t.dueDate == null) return false;
            final tDate = DateFormat('yyyy-MM-dd').format(t.dueDate!);
            return tDate == dateKey;
          }).toList();

          // Create summaries
          final summaries = <Map<String, dynamic>>[];
          // Events usually don't have categories in this app yet, but we'll check
          for (final e in dayEvents) {
            if (summaries.length >= 3) break;
            summaries.add({
              'text': e.title ?? 'No Title',
              'color': '', // Placeholder for event color if needed
            });
          }
          for (final t in dayTasks) {
            if (summaries.length >= 3) break;
            // Lookup category color
            int? colorVal;
            try {
              final cat = _taskSource.getCategories().firstWhere(
                (c) => c.id == t.categoryId,
              );
              colorVal = cat.colorValue;
            } catch (e) {
              AppLogger.debug('Category not found for task in widget: ${t.title}');
            }

            summaries.add({
              'text': t.title,
              'color': colorVal != null
                  ? '#${colorVal.toRadixString(16).padLeft(8, '0')}'
                  : '',
            });
          }

          gridData.add({
            'isWeekNumber': false,
            'date': dateKey, // Full date for deep linking
            'day': date.day,
            'isCurrentMonth': date.month == targetMonth.month,
            'isToday':
                date.year == now.year &&
                date.month == now.month &&
                date.day == now.day,
            'hasEvents': dayEvents.isNotEmpty,
            'hasTasks': dayTasks.isNotEmpty,
            'eventCount': dayEvents.length,
            'taskCount': dayTasks.length,
            'summaries': summaries,
          });
        }
      }

      // Save Data
      await HomeWidget.saveWidgetData<String>(
        'month_grid_data',
        jsonEncode(gridData),
      );

      // Save Month Name
      await HomeWidget.saveWidgetData<String>(
        'month_name',
        DateFormat('MMMM yyyy').format(targetMonth),
      );

      await HomeWidget.updateWidget(
        name: 'MonthWidgetProvider',
        iOSName: 'MonthWidget',
      );
    } catch (e, stack) {
      AppLogger.error('Error updating Month Widget', error: e, stack: stack);
    }
  }

  int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat('D').format(date));
    int woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (woy < 1) {
      // Handle edge case for first week of year
      woy = _getWeekNumber(DateTime(date.year - 1, 12, 31));
    } else if (woy > 52) {
      if (DateTime(date.year, 12, 31).weekday < 4) {
        woy = 1;
      }
    }
    return woy;
  }
}
