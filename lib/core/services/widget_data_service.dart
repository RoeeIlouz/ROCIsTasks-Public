import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/services/task_widget_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

class WidgetDataService {
  final CalendarService _calendarService;
  final ScheduleFirestoreService _scheduleService;
  bool _scheduleServiceInitialized = false;

  WidgetDataService(this._calendarService)
    : _scheduleService = ScheduleFirestoreService();

  /// Initialize the schedule service (call once after Firebase is ready)
  Future<void> initScheduleService() async {
    if (_scheduleServiceInitialized) return;
    await _scheduleService.initialize();
    _scheduleServiceInitialized = true;
  }

  /// Set the user email for cross-app schedule data lookup
  void setUserEmail(String? email) {
    _scheduleService.setUserEmail(email);
  }

  Future<void> updateScheduleWidget(
    List<Task> allTasks,
    Category? Function(String?) getCategoryById, {
    String? userId,
  }) async {
    if (kIsWeb) return;
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

    for (final t in scheduleTasks) {
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

    // Fetch device calendar events
    try {
      final calendarEvents = await _calendarService.getEvents(
        startDate: scheduleStart,
        endDate: scheduleEnd,
      );
      for (final event in calendarEvents) {
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
    } catch (e, s) {
      AppLogger.error(
        'Error fetching calendar events for schedule widget',
        error: e,
        stack: s,
      );
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

  Future<void> updateCalendarListWidget(
    List<Task> allTasks, {
    String? userId,
  }) async {
    if (kIsWeb) return;
    final listStart = DateTime.now();
    final listEnd = listStart.add(const Duration(days: 7));
    final calendarListEvents = <Map<String, dynamic>>[];

    try {
      final events = await _calendarService.getEvents(
        startDate: listStart,
        endDate: listEnd,
      );
      for (final event in events) {
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

      for (final t in listTasks) {
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
        name: 'CalendarWidgetProvider',
        iOSName: 'CalendarListWidget',
      );
    } catch (e, s) {
      AppLogger.error(
        'Error updating calendar list widget',
        error: e,
        stack: s,
      );
    }
  }

  Future<void> updateMonthEventsMap(
    List<Task> allTasks, {
    String? userId,
  }) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month + 2, 0);
    final eventsByDay = <String, bool>{};

    for (final task in allTasks.where((t) => !(t.isDeleted ?? false))) {
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
      for (final event in calendarEvents) {
        if (event.start != null) {
          final eventStart = DateTime(event.start!.year, event.start!.month, event.start!.day);
          final end = event.end ?? event.start!.add(const Duration(hours: 1));
          final eventEnd = DateTime(end.year, end.month, end.day);
          
          var current = eventStart;
          while (current.isBefore(eventEnd) || _isSameDay(current, eventEnd)) {
            // Exclusive end check - skip for all-day events
            if (current == eventEnd &&
                event.allDay != true &&
                end.hour == 0 &&
                end.minute == 0 &&
                end.second == 0 &&
                end.millisecond == 0 &&
                current != eventStart) {
              break;
            }
            
            final dateKey = DateFormat('yyyy-MM-dd').format(current);
            eventsByDay[dateKey] = true;
            current = current.add(const Duration(days: 1));
          }
        }
      }
    } catch (e, s) {
      AppLogger.error(
        'Error fetching calendar events for month map',
        error: e,
        stack: s,
      );
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

  /// Clear the schedule service cache (call when user logs out)
  void clearScheduleCache() {
    _scheduleService.clearCache();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
