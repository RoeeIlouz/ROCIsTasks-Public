import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/services/task_widget_service.dart';

class WidgetDataService {
  final CalendarService _calendarService;

  WidgetDataService(this._calendarService);

  Future<void> updateScheduleWidget(
    List<Task> allTasks,
    Category? Function(String?) getCategoryById,
  ) async {
    final scheduleStart = DateTime.now().subtract(const Duration(days: 1));
    final scheduleEnd = DateTime.now().add(const Duration(days: 30));
    final scheduleItems = <Map<String, dynamic>>[];

    final scheduleTasks = allTasks.where((t) {
      if (t.isCompleted || (t.isDeleted ?? false) || t.dueDate == null) {
        return false;
      }
      return t.dueDate!.isAfter(scheduleStart) &&
          t.dueDate!.isBefore(scheduleEnd);
    });

    for (var t in scheduleTasks) {
      final cat = getCategoryById(t.categoryId);
      scheduleItems.add({
        'type': 'task',
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'category_color': cat != null
            ? '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}'
            : '',
        'date': t.dueDate!.toIso8601String(),
        'dateDisplay': TaskWidgetService.formatDateForDisplay(t.dueDate!),
        'timeDisplay': DateFormat('HH:mm').format(t.dueDate!),
        'isAllDay': false,
        'location': '',
        'priority': t.priority.name,
      });
    }

    try {
      final calendarEvents = await _calendarService.getEvents(
        startDate: scheduleStart,
        endDate: scheduleEnd,
      );
      for (var event in calendarEvents) {
        if (event.start != null) {
          scheduleItems.add({
            'type': 'event',
            'id': event.eventId ?? '',
            'title': event.title ?? 'No Title',
            'description': event.description ?? '',
            'date': event.start!.toIso8601String(),
            'dateDisplay': TaskWidgetService.formatDateForDisplay(event.start!),
            'timeDisplay': event.allDay == true
                ? 'All Day'
                : DateFormat('HH:mm').format(event.start!),
            'isAllDay': event.allDay ?? false,
            'location': event.location ?? '',
            'category_color': '#4285F4',
            'priority': '',
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching calendar events for schedule: $e');
    }

    scheduleItems.sort(
      (a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])),
    );

    try {
      await HomeWidget.saveWidgetData<String>(
        'schedule_list',
        jsonEncode(scheduleItems),
      );
    } catch (e) {
      await HomeWidget.saveWidgetData<String>('schedule_list', '[]');
    }

    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      iOSName: 'ScheduleWidget',
    );
  }

  Future<void> updateCalendarListWidget(List<Task> allTasks) async {
    final listStart = DateTime.now();
    final listEnd = listStart.add(const Duration(days: 7));
    final calendarListEvents = <Map<String, dynamic>>[];

    try {
      final events = await _calendarService.getEvents(
        startDate: listStart,
        endDate: listEnd,
      );
      for (var event in events) {
        if (event.start != null) {
          calendarListEvents.add({
            'type': 'event',
            'id': event.eventId ?? '',
            'title': event.title ?? 'No Title',
            'start': event.start!.toIso8601String(),
            'startDisplay': event.allDay == true
                ? 'All Day'
                : DateFormat('HH:mm').format(event.start!),
            'dateDisplay': TaskWidgetService.formatDateForDisplay(event.start!),
            'category_color': '#4285F4',
          });
        }
      }

      final listTasks = allTasks.where((t) {
        if (t.isCompleted || (t.isDeleted ?? false) || t.dueDate == null) {
          return false;
        }
        return t.dueDate!.isAfter(listStart) && t.dueDate!.isBefore(listEnd);
      });

      for (var t in listTasks) {
        calendarListEvents.add({
          'type': 'task',
          'id': t.id,
          'title': t.title,
          'start': t.dueDate!.toIso8601String(),
          'startDisplay': DateFormat('HH:mm').format(t.dueDate!),
          'dateDisplay': TaskWidgetService.formatDateForDisplay(t.dueDate!),
          'category_color': '', // Can be improved by passing a lookup if needed
        });
      }

      calendarListEvents.sort(
        (a, b) =>
            DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])),
      );

      await HomeWidget.saveWidgetData<String>(
        'calendar_list_data',
        jsonEncode(calendarListEvents),
      );
      await HomeWidget.updateWidget(
        name: 'CalendarListWidgetProvider',
        iOSName: 'CalendarListWidget',
      );
    } catch (e) {
      debugPrint('Error updating calendar list widget: $e');
    }
  }

  Future<void> updateMonthEventsMap(List<Task> allTasks) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month + 2, 0);
    final eventsByDay = <String, bool>{};

    for (var task in allTasks.where((t) => !(t.isDeleted ?? false))) {
      if (task.dueDate != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(task.dueDate!);
        eventsByDay[dateKey] = true;
      }
    }

    try {
      final calendarEvents = await _calendarService.getEvents(
        startDate: start,
        endDate: end,
      );
      for (var event in calendarEvents) {
        if (event.start != null) {
          final dateKey = DateFormat('yyyy-MM-dd').format(event.start!);
          eventsByDay[dateKey] = true;
        }
      }
    } catch (e) {
      debugPrint('Error fetching calendar events for map: $e');
    }

    try {
      await HomeWidget.saveWidgetData<String>(
        'month_events_map',
        jsonEncode(eventsByDay),
      );
    } catch (e) {
      await HomeWidget.saveWidgetData<String>('month_events_map', '{}');
    }

    await HomeWidget.updateWidget(
      name: 'CalendarWidgetProvider',
      iOSName: 'CalendarWidget',
    );
  }
}
