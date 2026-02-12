import 'dart:convert';
import 'package:flutter/material.dart';
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

    // Fetch device calendar events
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
    } catch (e, s) {
      AppLogger.error(
        'Error fetching calendar events for schedule widget',
        error: e,
        stack: s,
      );
    }

    // Fetch ROCIs-Schedule data if user is logged in and authenticated in secondary Firebase
    if (userId != null && _scheduleService.isReady) {
      if (!_scheduleService.isAuthenticated) {
        AppLogger.warning(
          'WidgetDataService: User not authenticated in secondary Firebase (rocis-schedule). Schedule integration requires signing in with Google.',
        );
      } else {
        try {
          AppLogger.info(
            'WidgetDataService: Fetching ROCIs-Schedule data for user $userId (Auth ID: ${_scheduleService.authenticatedUserId})',
          );
          final scheduleData = await _scheduleService.getScheduleDataForWidget(
            userId,
            scheduleStart,
            scheduleEnd,
          );

          // Add schedule events and assignments
          for (var item in scheduleData) {
            final date = DateTime.parse(item['date'] as String);
            scheduleItems.add({
              'type': item['type'],
              'id': item['id'],
              'title': item['title'],
              'description': item['description'] ?? '',
              'date': item['date'],
              'dateDisplay': TaskWidgetService.formatDateForDisplay(date),
              'timeDisplay': item['isAllDay'] == true
                  ? (item['type'] == 'assignment' ? 'Due' : 'All Day')
                  : DateFormat('HH:mm').format(date),
              'isAllDay': item['isAllDay'] ?? false,
              'location': item['location'] ?? '',
              'category_color': item['category_color'] ?? '#4285F4',
              'priority': item['priority'] ?? '',
              'eventType': item['eventType'] ?? '',
            });
          }
          AppLogger.info(
            'WidgetDataService: Added ${scheduleData.length} items from ROCIs-Schedule',
          );
        } catch (e, s) {
          AppLogger.error(
            'Error fetching ROCIs-Schedule data',
            error: e,
            stack: s,
          );
        }
      }
    } else if (userId == null) {
      debugPrint(
        'WidgetDataService: No userId provided, skipping ROCIs-Schedule data',
      );
    } else if (!_scheduleService.isReady) {
      AppLogger.info(
        'WidgetDataService: Schedule service not ready, skipping ROCIs-Schedule data',
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

      // Fetch ROCIs-Schedule data if user is logged in and authenticated
      if (userId != null &&
          _scheduleService.isReady &&
          _scheduleService.isAuthenticated) {
        try {
          final scheduleData = await _scheduleService.getScheduleDataForWidget(
            userId,
            listStart,
            listEnd,
          );

          for (var item in scheduleData) {
            final date = DateTime.parse(item['date'] as String);
            calendarListEvents.add({
              'type': item['type'],
              'id': item['id'],
              'title': item['title'],
              'start': item['date'],
              'startDisplay': item['isAllDay'] == true
                  ? (item['type'] == 'assignment' ? 'Due' : 'All Day')
                  : DateFormat('HH:mm').format(date),
              'dateDisplay': TaskWidgetService.formatDateForDisplay(date),
              'category_color': item['category_color'] ?? '#4285F4',
            });
          }
        } catch (e, s) {
          AppLogger.error(
            'Error fetching ROCIs-Schedule data for calendar list',
            error: e,
            stack: s,
          );
        }
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
    } catch (e, s) {
      AppLogger.error(
        'Error fetching calendar events for month map',
        error: e,
        stack: s,
      );
    }

    // Add ROCIs-Schedule events to the month map
    if (userId != null &&
        _scheduleService.isReady &&
        _scheduleService.isAuthenticated) {
      try {
        final scheduleEvents = await _scheduleService.getScheduleEvents(
          userId,
          start,
          end,
        );
        for (var event in scheduleEvents) {
          final dateKey = DateFormat('yyyy-MM-dd').format(event.startTime);
          eventsByDay[dateKey] = true;
        }

        final assignments = await _scheduleService.getAssignments(
          userId,
          start,
          end,
        );
        for (var assignment in assignments) {
          final dateKey = DateFormat('yyyy-MM-dd').format(assignment.dueDate);
          eventsByDay[dateKey] = true;
        }
      } catch (e, s) {
        AppLogger.error(
          'Error fetching ROCIs-Schedule data for month map',
          error: e,
          stack: s,
        );
      }
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
}
