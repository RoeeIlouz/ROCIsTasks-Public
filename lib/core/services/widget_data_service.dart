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
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Master method to update all Android Home Screen Widgets
  Future<void> updateAllWidgets(
    List<Task> allTasks,
    Category? Function(String?) getCategoryById, {
    String? userId,
  }) async {
    if (kIsWeb) return;
    try {
      await Future.wait([
        updateTodayAgendaWidget(allTasks, getCategoryById, userId: userId),
        updateMonthAgendaWidget(allTasks, getCategoryById, userId: userId),
        updateTimelineAgendaWidget(allTasks, getCategoryById, userId: userId),
        updateQuickActionWidget(allTasks, userId: userId),
        updateUpNextWidget(allTasks, getCategoryById, userId: userId),
        updateScheduleWidget(allTasks, getCategoryById, userId: userId),
      ]);
    } catch (e, stack) {
      AppLogger.error('Error updating all widgets: $e', error: e, stack: stack);
    }
  }

  /// Update Day-by-Day Today Agenda Widget
  Future<void> updateTodayAgendaWidget(
    List<Task> allTasks,
    Category? Function(String?) getCategoryById, {
    String? userId,
  }) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final rangeStart = now.subtract(const Duration(days: 30));
    final rangeEnd = now.add(const Duration(days: 60));
    final agendaItems = <Map<String, dynamic>>[];

    // 1. Tasks
    final activeTasks = allTasks.where((t) {
      if ((t.isDeleted ?? false) || t.dueDate == null) return false;
      return t.dueDate!.isAfter(rangeStart) && t.dueDate!.isBefore(rangeEnd);
    });

    for (final t in activeTasks) {
      final cat = getCategoryById(t.categoryId);
      agendaItems.add({
        'type': 'task',
        'id': t.id,
        'title': t.title,
        'subtitle': cat?.name ?? '',
        'category_color': cat != null
            ? '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}'
            : '#6C63FF',
        'date': t.dueDate!.toIso8601String(),
        'dateDisplay': TaskWidgetService.formatDateForDisplay(t.dueDate!),
        'timeDisplay': DateFormat('HH:mm').format(t.dueDate!),
        'isAllDay': false,
        'isCompleted': t.isCompleted,
        'priority': t.priority.name,
      });
    }

    // 2. Calendar Events
    try {
      final calendarEvents = await _calendarService.getEvents(
        startDate: rangeStart,
        endDate: rangeEnd,
      );
      for (final event in calendarEvents) {
        if (event.start != null) {
          final isAllDay = event.allDay ?? false;
          final timeDisplay = isAllDay
              ? 'All Day'
              : (event.end != null
                  ? '${DateFormat('HH:mm').format(event.start!)}-${DateFormat('HH:mm').format(event.end!)}'
                  : DateFormat('HH:mm').format(event.start!));

          agendaItems.add({
            'type': 'event',
            'id': event.eventId ?? '',
            'title': event.title ?? 'No Title',
            'subtitle': event.location ?? '',
            'date': event.start!.toIso8601String(),
            'dateDisplay': TaskWidgetService.formatDateForDisplay(event.start!),
            'timeDisplay': timeDisplay,
            'isAllDay': isAllDay,
            'isCompleted': false,
            'category_color': '#4285F4',
            'priority': '',
          });
        }
      }
    } catch (e) {
      AppLogger.debug('Failed to load calendar events for today agenda widget: $e');
    }

    agendaItems.sort(
      (a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])),
    );

    try {
      await HomeWidget.saveWidgetData<String>(
        'today_agenda_data',
        jsonEncode(agendaItems),
      );
    } catch (e) {
      await HomeWidget.saveWidgetData<String>('today_agenda_data', '[]');
    }

    try {
      await HomeWidget.updateWidget(
        name: 'TodayAgendaWidgetProvider',
        iOSName: 'TodayAgendaWidget',
      );
    } catch (e) {
      AppLogger.debug('Failed to update today agenda widget: $e');
    }
  }

  /// Update Samsung-style Month + Day Agenda Split Widget
  Future<void> updateMonthAgendaWidget(
    List<Task> allTasks,
    Category? Function(String?) getCategoryById, {
    String? userId,
  }) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final int offset = prefs.getInt('month_agenda_offset') ?? 0;
      final now = DateTime.now();
      final targetMonth = DateTime(now.year, now.month + offset, 1);

      final startOfWeek = prefs.getInt('full_calendar_start_of_week') ?? 7;
      final firstDayOfMonth = targetMonth;
      final difference = (firstDayOfMonth.weekday - startOfWeek) % 7;
      final startDate = firstDayOfMonth.subtract(Duration(days: difference));
      final endDate = startDate.add(const Duration(days: 41)); // 6 weeks

      var events = <dynamic>[];
      try {
        events = await _calendarService.getEvents(
          startDate: startDate,
          endDate: endDate,
        );
      } catch (_) {}

      final eventsByDate = <String, bool>{};
      for (final event in events) {
        if (event.start != null) {
          final key = DateFormat('yyyy-MM-dd').format(event.start!);
          eventsByDate[key] = true;
        }
      }

      for (final t in allTasks.where((t) => !(t.isDeleted ?? false) && t.dueDate != null)) {
        final key = DateFormat('yyyy-MM-dd').format(t.dueDate!);
        eventsByDate[key] = true;
      }

      final gridData = <Map<String, dynamic>>[];
      for (int row = 0; row < 6; row++) {
        final rowStartDate = startDate.add(Duration(days: row * 7));
        for (int col = 0; col < 7; col++) {
          final date = rowStartDate.add(Duration(days: col));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
          final isCurrentMonth = date.month == targetMonth.month;

          gridData.add({
            'date': dateKey,
            'day': date.day,
            'isCurrentMonth': isCurrentMonth,
            'isToday': isToday,
            'hasEvents': eventsByDate[dateKey] == true,
          });
        }
      }

      await Future.wait([
        HomeWidget.saveWidgetData<String>('month_agenda_grid_data', jsonEncode(gridData)),
        HomeWidget.saveWidgetData<String>('month_agenda_month_title', DateFormat('MMMM yyyy').format(targetMonth)),
      ]);

      try {
        await HomeWidget.updateWidget(
          name: 'MonthAgendaWidgetProvider',
          iOSName: 'MonthAgendaWidget',
        );
      } catch (e) {
        AppLogger.debug('Failed to update month agenda widget: $e');
      }
    } catch (e, stack) {
      AppLogger.error('Error updating MonthAgendaWidget: $e', error: e, stack: stack);
    }
  }

  /// Update Google-style Continuous Agenda Timeline Widget
  Future<void> updateTimelineAgendaWidget(
    List<Task> allTasks,
    Category? Function(String?) getCategoryById, {
    String? userId,
  }) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rangeStart = today.subtract(const Duration(days: 1));
    final rangeEnd = today.add(const Duration(days: 30));

    final rawItems = <Map<String, dynamic>>[];

    // 1. Active Tasks
    for (final t in allTasks.where((t) => !(t.isDeleted ?? false) && t.dueDate != null)) {
      if (t.dueDate!.isAfter(rangeStart) && t.dueDate!.isBefore(rangeEnd)) {
        final cat = getCategoryById(t.categoryId);
        rawItems.add({
          'type': 'task',
          'id': t.id,
          'title': t.title,
          'subtitle': cat?.name ?? '',
          'category_color': cat != null
              ? '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}'
              : '#6C63FF',
          'date': t.dueDate!.toIso8601String(),
          'dateOnly': DateFormat('yyyy-MM-dd').format(t.dueDate!),
          'timeDisplay': DateFormat('HH:mm').format(t.dueDate!),
          'isCompleted': t.isCompleted,
          'priority': t.priority.name,
        });
      }
    }

    // 2. Events
    try {
      final calendarEvents = await _calendarService.getEvents(
        startDate: rangeStart,
        endDate: rangeEnd,
      );
      for (final event in calendarEvents) {
        if (event.start != null) {
          final isAllDay = event.allDay ?? false;
          final timeDisplay = isAllDay
              ? 'All Day'
              : (event.end != null
                  ? '${DateFormat('HH:mm').format(event.start!)}-${DateFormat('HH:mm').format(event.end!)}'
                  : DateFormat('HH:mm').format(event.start!));

          rawItems.add({
            'type': 'event',
            'id': event.eventId ?? '',
            'title': event.title ?? 'No Title',
            'subtitle': event.location ?? '',
            'date': event.start!.toIso8601String(),
            'dateOnly': DateFormat('yyyy-MM-dd').format(event.start!),
            'timeDisplay': timeDisplay,
            'isCompleted': false,
            'category_color': '#4285F4',
            'priority': '',
          });
        }
      }
    } catch (_) {}

    rawItems.sort(
      (a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])),
    );

    // Group with Section Headers
    final timelineData = <Map<String, dynamic>>[];
    String? currentGroupKey;

    for (final item in rawItems) {
      final dateOnly = item['dateOnly'] as String;
      if (dateOnly != currentGroupKey) {
        currentGroupKey = dateOnly;
        final itemDate = DateTime.parse(dateOnly);
        final diffDays = itemDate.difference(today).inDays;

        final String dayLabel;
        if (diffDays == 0) {
          dayLabel = 'TODAY';
        } else if (diffDays == 1) {
          dayLabel = 'TOMORROW';
        } else if (diffDays == -1) {
          dayLabel = 'YESTERDAY';
        } else {
          dayLabel = DateFormat('EEEE').format(itemDate).toUpperCase();
        }

        final dateDisplay = DateFormat('EEE, MMM d').format(itemDate);

        timelineData.add({
          'isHeader': true,
          'dayLabel': dayLabel,
          'dateDisplay': dateDisplay,
          'date': dateOnly,
        });
      }

      timelineData.add({
        'isHeader': false,
        'type': item['type'],
        'id': item['id'],
        'title': item['title'],
        'subtitle': item['subtitle'],
        'category_color': item['category_color'],
        'timeDisplay': item['timeDisplay'],
        'isCompleted': item['isCompleted'],
        'priority': item['priority'],
      });
    }

    try {
      await HomeWidget.saveWidgetData<String>(
        'timeline_agenda_data',
        jsonEncode(timelineData),
      );
    } catch (_) {
      await HomeWidget.saveWidgetData<String>('timeline_agenda_data', '[]');
    }

    try {
      await HomeWidget.updateWidget(
        name: 'TimelineAgendaWidgetProvider',
        iOSName: 'TimelineAgendaWidget',
      );
    } catch (e) {
      AppLogger.debug('Failed to update timeline agenda widget: $e');
    }
  }

  /// Update Quick Action & Progress Ring Widget
  Future<void> updateQuickActionWidget(
    List<Task> allTasks, {
    String? userId,
  }) async {
    if (kIsWeb) return;
    int pendingCount = 0;
    int completedCount = 0;

    for (final task in allTasks) {
      if (!(task.isDeleted ?? false)) {
        if (task.isCompleted) {
          completedCount++;
        } else {
          pendingCount++;
        }
      }
    }

    await Future.wait([
      HomeWidget.saveWidgetData<int>('quick_action_pending_count', pendingCount),
      HomeWidget.saveWidgetData<int>('quick_action_completed_count', completedCount),
    ]);

    try {
      await HomeWidget.updateWidget(
        name: 'QuickActionWidgetProvider',
        iOSName: 'QuickActionWidget',
      );
    } catch (e) {
      AppLogger.debug('Failed to update quick action widget: $e');
    }
  }

  /// Update Up Next Minimalist Pill Widget
  Future<void> updateUpNextWidget(
    List<Task> allTasks,
    Category? Function(String?) getCategoryById, {
    String? userId,
  }) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final upcomingList = <Map<String, dynamic>>[];

    // 1. Pending Tasks
    for (final t in allTasks.where((t) => !t.isCompleted && !(t.isDeleted ?? false) && t.dueDate != null)) {
      if (t.dueDate!.isAfter(now.subtract(const Duration(hours: 1)))) {
        final cat = getCategoryById(t.categoryId);
        upcomingList.add({
          'type': 'task',
          'id': t.id,
          'title': t.title,
          'subtitle': cat?.name ?? 'Task',
          'category_color': cat != null
              ? '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}'
              : '#6C63FF',
          'date': t.dueDate!,
          'timeDisplay': DateFormat('HH:mm').format(t.dueDate!),
        });
      }
    }

    // 2. Calendar Events
    try {
      final calendarEvents = await _calendarService.getEvents(
        startDate: now,
        endDate: now.add(const Duration(days: 3)),
      );
      for (final e in calendarEvents) {
        if (e.start != null && e.start!.isAfter(now.subtract(const Duration(minutes: 15)))) {
          upcomingList.add({
            'type': 'event',
            'id': e.eventId ?? '',
            'title': e.title ?? 'Meeting',
            'subtitle': e.location ?? 'Calendar',
            'category_color': '#4285F4',
            'date': e.start!,
            'timeDisplay': DateFormat('HH:mm').format(e.start!),
          });
        }
      }
    } catch (_) {}

    upcomingList.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    if (upcomingList.isNotEmpty) {
      final nextItem = upcomingList.first;
      final itemDate = nextItem['date'] as DateTime;
      final diffMin = itemDate.difference(now).inMinutes;

      final String relativeTime;
      if (diffMin <= 0) {
        relativeTime = 'Now';
      } else if (diffMin < 60) {
        relativeTime = 'In ${diffMin}m';
      } else if (diffMin < 1440) {
        relativeTime = DateFormat('HH:mm').format(itemDate);
      } else {
        relativeTime = DateFormat('MMM d').format(itemDate);
      }

      await Future.wait([
        HomeWidget.saveWidgetData<String>('up_next_type', nextItem['type']),
        HomeWidget.saveWidgetData<String>('up_next_id', nextItem['id']),
        HomeWidget.saveWidgetData<String>('up_next_title', nextItem['title']),
        HomeWidget.saveWidgetData<String>('up_next_subtitle', nextItem['subtitle']),
        HomeWidget.saveWidgetData<String>('up_next_time_display', relativeTime),
        HomeWidget.saveWidgetData<String>('up_next_color', nextItem['category_color']),
      ]);
    } else {
      await Future.wait([
        HomeWidget.saveWidgetData<String>('up_next_type', 'none'),
        HomeWidget.saveWidgetData<String>('up_next_id', ''),
        HomeWidget.saveWidgetData<String>('up_next_title', 'All tasks completed'),
        HomeWidget.saveWidgetData<String>('up_next_subtitle', 'No upcoming items'),
        HomeWidget.saveWidgetData<String>('up_next_time_display', 'Clear'),
        HomeWidget.saveWidgetData<String>('up_next_color', '#10B981'),
      ]);
    }

    try {
      await HomeWidget.updateWidget(
        name: 'UpNextWidgetProvider',
        iOSName: 'UpNextWidget',
      );
    } catch (e) {
      AppLogger.debug('Failed to update up next widget: $e');
    }
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

    try {
      await HomeWidget.updateWidget(
        name: 'TimelineAgendaWidgetProvider',
        iOSName: 'ScheduleWidget',
      );
    } catch (e) {
      AppLogger.debug('Failed to update schedule widget: $e');
    }
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
          'category_color': '',
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
      try {
        await HomeWidget.updateWidget(
          name: 'FullCalendarWidgetProvider',
          iOSName: 'CalendarListWidget',
        );
      } catch (e) {
        AppLogger.debug('Failed to update calendar list widget: $e');
      }
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

    try {
      await HomeWidget.updateWidget(
        name: 'FullCalendarWidgetProvider',
        iOSName: 'CalendarWidget',
      );
    } catch (e) {
      AppLogger.debug('Failed to update month events map: $e');
    }
  }

  void clearScheduleCache() {
    _scheduleService.clearCache();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
