import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/schedule_events_loader.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_calendar/device_calendar.dart';

class WidgetDataService {
  final CalendarService _calendarService;
  final ScheduleFirestoreService _scheduleService;
  Future<List<SyncedScheduleEvent>>? _scheduleLoad;
  DateTime? _scheduleLoadTime;

  WidgetDataService(
    this._calendarService, {
    ScheduleFirestoreService? scheduleService,
  }) : _scheduleService = scheduleService ?? ScheduleFirestoreService();

  /// ROCIs Schedule classes, unless the user hid them. The widgets update
  /// together, so they share one load.
  Future<List<SyncedScheduleEvent>> _getScheduleEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('full_calendar_show_schedule') ?? true)) return [];
    } catch (_) {}
    final loadedAt = _scheduleLoadTime;
    if (_scheduleLoad == null ||
        loadedAt == null ||
        DateTime.now().difference(loadedAt) > const Duration(minutes: 1)) {
      _scheduleLoadTime = DateTime.now();
      _scheduleLoad = loadScheduleEvents(
        scheduleService: _scheduleService,
        calendarService: _calendarService,
      );
    }
    return _scheduleLoad!;
  }

  /// Every class time of [events] on the days from [from] up to [to].
  @visibleForTesting
  static List<({SyncedScheduleEvent event, DateTime start, DateTime end})>
  scheduleOccurrences(
    List<SyncedScheduleEvent> events,
    DateTime from,
    DateTime to,
  ) {
    final first = DateTime(from.year, from.month, from.day);
    final result =
        <({SyncedScheduleEvent event, DateTime start, DateTime end})>[];
    for (final e in events) {
      final duration = e.endTime.difference(e.startTime);
      if (!e.recurring) {
        if (!e.startTime.isBefore(first) && e.startTime.isBefore(to)) {
          result.add((event: e, start: e.startTime, end: e.endTime));
        }
        continue;
      }
      for (
        var day = first;
        day.isBefore(to);
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        if (!e.occursOnDay(day)) continue;
        final start = DateTime(
          day.year,
          day.month,
          day.day,
          e.startTime.hour,
          e.startTime.minute,
        );
        result.add((event: e, start: start, end: start.add(duration)));
      }
    }
    return result;
  }

  /// "Course: Lecture", like the full calendar widget.
  static String _scheduleTitle(SyncedScheduleEvent s, String fallback) {
    final title = s.title.trim();
    final course = s.courseName.trim();
    if (course.isEmpty) return title.isNotEmpty ? title : fallback;
    if (title.isEmpty || title.toLowerCase() == course.toLowerCase()) {
      return course;
    }
    return '$course: $title';
  }

  static String _scheduleSubtitle(SyncedScheduleEvent s) =>
      s.location.isNotEmpty && s.courseCode.isNotEmpty
      ? '${s.courseCode} • ${s.location}'
      : (s.location.isNotEmpty ? s.location : s.courseCode);

  static String _scheduleColor(SyncedScheduleEvent s) =>
      '#${s.color.toARGB32().toRadixString(16).padLeft(8, '0')}';

  /// Local days an event occupies. Same rule as the in-app calendar: an end at
  /// midnight is exclusive, so all-day events don't spill into the next day.
  @visibleForTesting
  static List<DateTime> eventDays(DateTime start, DateTime? end) {
    final s = start.toLocal();
    final e = (end ?? s.add(const Duration(hours: 1))).toLocal();
    final first = DateTime(s.year, s.month, s.day);
    final last = DateTime(e.year, e.month, e.day);
    final endsAtMidnight =
        e.hour == 0 && e.minute == 0 && e.second == 0 && e.millisecond == 0;
    final days = <DateTime>[];
    for (
      var day = first;
      !day.isAfter(last);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      if (day == last && day != first && endsAtMidnight) break;
      days.add(day);
    }
    return days;
  }

  /// Minutes after midnight used to order a day's items; all-day items first.
  static int _sortMinutes(DateTime? time, {required bool allDay}) =>
      allDay || time == null ? -1 : time.hour * 60 + time.minute;

  /// Orders widget items by day, then all-day first, then by start time.
  static int _compareItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    final byDay = (a['dateOnly'] as String).compareTo(b['dateOnly'] as String);
    if (byDay != 0) return byDay;
    return (a['sortMinutes'] as int).compareTo(b['sortMinutes'] as int);
  }

  /// Fetch only events from calendars that are turned ON by the user
  Future<List<Event>> _getFilteredCalendarEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final showGoogle = prefs.getBool('full_calendar_show_google') ?? true;
      if (!showGoogle) return [];

      final selectedIds = prefs.getStringList('full_calendar_selected_ids');
      return await _calendarService.getEvents(
        startDate: startDate,
        endDate: endDate,
        calendarIds: selectedIds,
      );
    } catch (e) {
      AppLogger.debug(
        'Failed to load filtered calendar events for widgets: $e',
      );
      return [];
    }
  }

  /// Clock format for widget times: the app's 12h/24h setting, in the app
  /// language (12h follows the language, e.g. Hebrew still reads 16:30).
  static Future<DateFormat> clockFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang =
          prefs.getString('language_code') ??
          PlatformDispatcher.instance.locale.languageCode;
      final use24h = prefs.getBool('use_24h_format') ?? false;
      return use24h ? DateFormat.Hm(lang) : DateFormat.jm(lang);
    } catch (_) {
      return DateFormat.Hm();
    }
  }

  /// Helper to get active app language
  Future<String> _getAppLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('language_code') ??
          PlatformDispatcher.instance.locale.languageCode;
    } catch (_) {
      return PlatformDispatcher.instance.locale.languageCode;
    }
  }

  Future<String> _getAllDayLabel() async {
    final lang = await _getAppLanguage();
    switch (lang.toLowerCase()) {
      case 'he':
        return 'כל היום';
      case 'es':
        return 'Todo el día';
      case 'de':
        return 'Ganztägig';
      case 'fr':
        return 'Toute la journée';
      case 'ar':
        return 'طوال اليوم';
      case 'sv':
        return 'Hela dagen';
      case 'hi':
        return 'पूरा दिन';
      default:
        return 'All Day';
    }
  }

  Future<String> _getTodayLabel() async {
    final lang = await _getAppLanguage();
    switch (lang.toLowerCase()) {
      case 'he':
        return 'היום';
      case 'es':
        return 'HOY';
      case 'de':
        return 'HEUTE';
      case 'fr':
        return "AUJOURD'HUI";
      case 'ar':
        return 'اليوم';
      case 'sv':
        return 'IDAG';
      case 'hi':
        return 'आज';
      default:
        return 'TODAY';
    }
  }

  Future<String> _getTomorrowLabel() async {
    final lang = await _getAppLanguage();
    switch (lang.toLowerCase()) {
      case 'he':
        return 'מחר';
      case 'es':
        return 'MAÑANA';
      case 'de':
        return 'MORGEN';
      case 'fr':
        return 'DEMAIN';
      case 'ar':
        return 'غداً';
      case 'sv':
        return 'IMORGON';
      case 'hi':
        return 'कल';
      default:
        return 'TOMORROW';
    }
  }

  Future<String> _getNoTitleLabel() async {
    final lang = await _getAppLanguage();
    switch (lang.toLowerCase()) {
      case 'he':
        return 'ללא כותרת';
      case 'es':
        return 'Sin título';
      case 'de':
        return 'Kein Titel';
      case 'fr':
        return 'Sans titre';
      case 'ar':
        return 'بلا عنوان';
      case 'sv':
        return 'Ingen rubrik';
      case 'hi':
        return 'बिना शीर्षक';
      default:
        return 'No Title';
    }
  }

  Future<String> _getOverdueLabel() async {
    final lang = await _getAppLanguage();
    switch (lang.toLowerCase()) {
      case 'he':
        return 'באיחור';
      case 'es':
        return 'Vencida';
      case 'de':
        return 'Überfällig';
      case 'fr':
        return 'En retard';
      case 'ar':
        return 'متأخرة';
      case 'sv':
        return 'Försenad';
      case 'hi':
        return 'अतिदेय';
      default:
        return 'Overdue';
    }
  }

  Future<String> _getAllTasksCompletedLabel() async {
    final lang = await _getAppLanguage();
    switch (lang.toLowerCase()) {
      case 'he':
        return 'כל המשימות הושלמו';
      case 'es':
        return 'Todas las tareas completadas';
      case 'de':
        return 'Alle Aufgaben erledigt';
      case 'fr':
        return 'Toutes les tâches terminées';
      case 'ar':
        return 'اكتملت جميع المهام';
      case 'sv':
        return 'Alla uppgifter slutförda';
      case 'hi':
        return 'सभी कार्य पूरे हो गए';
      default:
        return 'All tasks completed';
    }
  }

  Future<String> _getClearLabel() async {
    final lang = await _getAppLanguage();
    switch (lang.toLowerCase()) {
      case 'he':
        return 'נקי';
      case 'es':
        return 'Limpio';
      case 'de':
        return 'Frei';
      case 'fr':
        return 'Libre';
      case 'ar':
        return 'منجز';
      case 'sv':
        return 'Klart';
      case 'hi':
        return 'साफ़';
      default:
        return 'Clear';
    }
  }

  String _formatDatePattern(String pattern, DateTime date, [String? locale]) {
    if (locale != null && locale.isNotEmpty) {
      try {
        return DateFormat(pattern, locale).format(date);
      } catch (_) {
        try {
          return DateFormat(pattern).format(date);
        } catch (_) {
          return date.toIso8601String();
        }
      }
    }
    return DateFormat(pattern).format(date);
  }

  /// Helper to filter tasks by the user's chosen widget category filter
  Future<List<Task>> _filterTasksByCategory(List<Task> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filterCatId = prefs.getString('widget_filter_category_id');
      if (filterCatId == null || filterCatId.isEmpty || filterCatId == 'all') {
        return tasks;
      }
      return tasks.where((t) {
        return t.categoryIds.contains(filterCatId) ||
            t.categoryId == filterCatId;
      }).toList();
    } catch (_) {
      return tasks;
    }
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
        updateKanbanWidget(allTasks, getCategoryById, userId: userId),
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
    final clock = await clockFormat();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rangeStart = today.subtract(const Duration(days: 60));
    final rangeEnd = today.add(const Duration(days: 120));
    final agendaItems = <Map<String, dynamic>>[];
    final allDayLabel = await _getAllDayLabel();
    final noTitleLabel = await _getNoTitleLabel();

    // 1. Filter tasks by category setting & pending only
    final categoryTasks = await _filterTasksByCategory(allTasks);
    final pendingTasks = categoryTasks.where((t) {
      if (t.isCompleted || (t.isDeleted ?? false)) return false;
      if (t.dueDate == null) return true;
      return t.dueDate!.isAfter(rangeStart) && t.dueDate!.isBefore(rangeEnd);
    });

    for (final t in pendingTasks) {
      final cat = getCategoryById(t.categoryId);
      final isAllDay = t.dueDate == null;
      // Undated tasks default to today so they don't leak into future/past dates
      final taskDate = t.dueDate ?? today;
      final dateOnlyFormatted = DateFormat('yyyy-MM-dd').format(taskDate);

      agendaItems.add({
        'type': 'task',
        'id': t.id,
        'title': t.title,
        'subtitle': cat?.name ?? '',
        'category_color': cat != null
            ? '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}'
            : '#6366F1',
        'date': taskDate.toIso8601String(),
        'dateOnly': dateOnlyFormatted,
        'dateDisplay': dateOnlyFormatted,
        'timeDisplay': isAllDay ? allDayLabel : clock.format(taskDate),
        'isAllDay': isAllDay,
        'sortMinutes': _sortMinutes(t.dueDate, allDay: isAllDay),
        'isCompleted': false,
        'priority': t.priority.name,
      });
    }

    // 2. Calendar Events
    try {
      Map<String, String> calendarColors = {};
      try {
        calendarColors = await _calendarService.getCalendarColors();
      } catch (_) {}

      final calendarEvents = await _getFilteredCalendarEvents(
        startDate: rangeStart,
        endDate: rangeEnd,
      );
      for (final event in calendarEvents) {
        if (event.start == null) continue;
        final isAllDay = event.allDay ?? false;
        final start = event.start!.toLocal();
        final end = event.end?.toLocal();
        final timeDisplay = isAllDay
            ? allDayLabel
            : (end != null
                  ? '${clock.format(start)}-${clock.format(end)}'
                  : clock.format(start));
        final calColor = calendarColors[event.calendarId] ?? '#4285F4';
        final days = eventDays(start, end);

        for (final day in days) {
          final dayFormatted = DateFormat('yyyy-MM-dd').format(day);
          // Later days of a multi-day event continue from midnight.
          final isFirstDay = day == days.first;
          agendaItems.add({
            'type': 'event',
            'id': event.eventId ?? '',
            'title': event.title ?? noTitleLabel,
            'subtitle':
                event.location ?? (isAllDay ? allDayLabel : timeDisplay),
            'date': (isFirstDay ? start : day).toIso8601String(),
            'dateOnly': dayFormatted,
            'dateDisplay': dayFormatted,
            'timeDisplay': timeDisplay,
            'isAllDay': isAllDay,
            'sortMinutes': _sortMinutes(
              isFirstDay ? start : day,
              allDay: isAllDay,
            ),
            'isCompleted': false,
            'category_color': calColor,
            'priority': '',
          });
        }
      }
    } catch (e) {
      AppLogger.debug(
        'Failed to load calendar events for today agenda widget: $e',
      );
    }

    // 3. ROCIs Schedule classes
    final scheduleEvents = await _getScheduleEvents();
    for (final o in scheduleOccurrences(scheduleEvents, rangeStart, rangeEnd)) {
      final day = DateFormat('yyyy-MM-dd').format(o.start);
      agendaItems.add({
        'type': 'schedule',
        'id': o.event.id,
        'title': _scheduleTitle(o.event, noTitleLabel),
        'subtitle': _scheduleSubtitle(o.event),
        'date': o.start.toIso8601String(),
        'dateOnly': day,
        'dateDisplay': day,
        'timeDisplay': '${clock.format(o.start)}-${clock.format(o.end)}',
        'isAllDay': false,
        'sortMinutes': _sortMinutes(o.start, allDay: false),
        'isCompleted': false,
        'category_color': _scheduleColor(o.event),
        'priority': '',
      });
    }

    agendaItems.sort(_compareItems);

    // An empty result only means "no data yet" when no tasks are loaded;
    // otherwise it must replace the old list (e.g. the last task was done).
    if (agendaItems.isEmpty && allTasks.isEmpty) {
      final existing = await HomeWidget.getWidgetData<String>(
        'today_agenda_data',
      );
      if (existing != null && existing.isNotEmpty && existing != '[]') {
        return;
      }
    }

    try {
      await HomeWidget.saveWidgetData<String>(
        'today_agenda_data',
        jsonEncode(agendaItems),
      );
    } catch (e) {
      AppLogger.debug('Failed to save today_agenda_data: $e');
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
      final int offset =
          (await HomeWidget.getWidgetData<int>('month_agenda_offset')) ?? 0;
      final now = DateTime.now();
      final targetMonth = DateTime(now.year, now.month + offset, 1);

      final startOfWeek = prefs.getInt('full_calendar_start_of_week') ?? 7;
      final firstDayOfMonth = targetMonth;
      final difference = (firstDayOfMonth.weekday - startOfWeek) % 7;
      // Calendar-day arithmetic (not 24h durations) so DST changes don't
      // shift the grid.
      final startDate = DateTime(
        firstDayOfMonth.year,
        firstDayOfMonth.month,
        firstDayOfMonth.day - difference,
      );
      final endDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day + 41,
      ); // 6 weeks

      var events = <dynamic>[];
      try {
        events = await _getFilteredCalendarEvents(
          startDate: startDate,
          endDate: endDate,
        );
      } catch (_) {}

      final eventsByDate = <String, bool>{};
      for (final event in events) {
        if (event.start == null) continue;
        for (final day in eventDays(event.start!, event.end)) {
          eventsByDate[DateFormat('yyyy-MM-dd').format(day)] = true;
        }
      }
      final gridEnd = DateTime(endDate.year, endDate.month, endDate.day + 1);
      for (final o in scheduleOccurrences(
        await _getScheduleEvents(),
        startDate,
        gridEnd,
      )) {
        eventsByDate[DateFormat('yyyy-MM-dd').format(o.start)] = true;
      }

      final categoryTasks = await _filterTasksByCategory(allTasks);
      for (final t in categoryTasks.where(
        (t) => !t.isCompleted && !(t.isDeleted ?? false) && t.dueDate != null,
      )) {
        final key = DateFormat('yyyy-MM-dd').format(t.dueDate!);
        eventsByDate[key] = true;
      }

      final gridData = <Map<String, dynamic>>[];
      for (int row = 0; row < 6; row++) {
        for (int col = 0; col < 7; col++) {
          final date = DateTime(
            startDate.year,
            startDate.month,
            startDate.day + row * 7 + col,
          );
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final isToday =
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
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

      final appLang = await _getAppLanguage();
      await Future.wait([
        HomeWidget.saveWidgetData<String>(
          'month_agenda_grid_data',
          jsonEncode(gridData),
        ),
        HomeWidget.saveWidgetData<String>(
          'month_agenda_month_title',
          _formatDatePattern('MMMM yyyy', targetMonth, appLang),
        ),
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
      AppLogger.error(
        'Error updating MonthAgendaWidget: $e',
        error: e,
        stack: stack,
      );
    }
  }

  /// Update Google-style Continuous Agenda Timeline Widget
  Future<void> updateTimelineAgendaWidget(
    List<Task> allTasks,
    Category? Function(String?) getCategoryById, {
    String? userId,
  }) async {
    if (kIsWeb) return;
    final clock = await clockFormat();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rangeStart = today.subtract(const Duration(days: 1));
    final rangeEnd = today.add(const Duration(days: 30));
    final allDayLabel = await _getAllDayLabel();
    final todayLabel = await _getTodayLabel();
    final tomorrowLabel = await _getTomorrowLabel();
    final noTitleLabel = await _getNoTitleLabel();
    final appLang = await _getAppLanguage();

    final rawItems = <Map<String, dynamic>>[];

    // 1. Pending Tasks Only (Filter out completed & deleted)
    final categoryTasks = await _filterTasksByCategory(allTasks);
    for (final t in categoryTasks.where(
      (t) => !t.isCompleted && !(t.isDeleted ?? false),
    )) {
      final taskDate = t.dueDate ?? today;
      if (taskDate.isAfter(rangeStart) && taskDate.isBefore(rangeEnd)) {
        final cat = getCategoryById(t.categoryId);
        rawItems.add({
          'type': 'task',
          'id': t.id,
          'title': t.title,
          'subtitle': cat?.name ?? '',
          'category_color': cat != null
              ? '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}'
              : '#6366F1',
          'date': taskDate.toIso8601String(),
          'dateOnly': DateFormat('yyyy-MM-dd').format(taskDate),
          'timeDisplay': t.dueDate != null
              ? clock.format(t.dueDate!)
              : allDayLabel,
          'isAllDay': t.dueDate == null,
          'sortMinutes': _sortMinutes(t.dueDate, allDay: t.dueDate == null),
          'isCompleted': false,
          'priority': t.priority.name,
        });
      }
    }

    // 2. Calendar Events
    try {
      Map<String, String> calendarColors = {};
      try {
        calendarColors = await _calendarService.getCalendarColors();
      } catch (_) {}

      final calendarEvents = await _getFilteredCalendarEvents(
        startDate: rangeStart,
        endDate: rangeEnd,
      );
      for (final event in calendarEvents) {
        if (event.start == null) continue;
        final isAllDay = event.allDay ?? false;
        final start = event.start!.toLocal();
        final end = event.end?.toLocal();
        final timeDisplay = isAllDay
            ? allDayLabel
            : (end != null
                  ? '${clock.format(start)}-${clock.format(end)}'
                  : clock.format(start));
        final calColor = calendarColors[event.calendarId] ?? '#4285F4';
        final days = eventDays(start, end);

        for (final day in days) {
          // Only days inside the timeline window (rangeStart is exclusive).
          if (!day.isAfter(rangeStart) || !day.isBefore(rangeEnd)) continue;
          final isFirstDay = day == days.first;
          rawItems.add({
            'type': 'event',
            'id': event.eventId ?? '',
            'title': event.title ?? noTitleLabel,
            'subtitle':
                event.location ?? (isAllDay ? allDayLabel : timeDisplay),
            'date': (isFirstDay ? start : day).toIso8601String(),
            'dateOnly': DateFormat('yyyy-MM-dd').format(day),
            'timeDisplay': timeDisplay,
            'isAllDay': isAllDay,
            'sortMinutes': _sortMinutes(
              isFirstDay ? start : day,
              allDay: isAllDay,
            ),
            'isCompleted': false,
            'category_color': calColor,
            'priority': '',
          });
        }
      }
    } catch (_) {}

    // 3. ROCIs Schedule classes (rangeStart is exclusive, as above)
    for (final o in scheduleOccurrences(
      await _getScheduleEvents(),
      today,
      rangeEnd,
    )) {
      rawItems.add({
        'type': 'schedule',
        'id': o.event.id,
        'title': _scheduleTitle(o.event, noTitleLabel),
        'subtitle': _scheduleSubtitle(o.event),
        'date': o.start.toIso8601String(),
        'dateOnly': DateFormat('yyyy-MM-dd').format(o.start),
        'timeDisplay': '${clock.format(o.start)}-${clock.format(o.end)}',
        'isAllDay': false,
        'sortMinutes': _sortMinutes(o.start, allDay: false),
        'isCompleted': false,
        'category_color': _scheduleColor(o.event),
        'priority': '',
      });
    }

    rawItems.sort(_compareItems);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);

    // Group with Section Headers
    final timelineData = <Map<String, dynamic>>[];
    String? currentGroupKey;

    for (final item in rawItems) {
      final dateOnly = item['dateOnly'] as String;
      if (dateOnly != currentGroupKey) {
        currentGroupKey = dateOnly;
        final parsedDate = DateTime.parse(dateOnly);
        final isToday = parsedDate == today;
        final isTomorrow = parsedDate == tomorrow;

        final dayLabel = isToday
            ? todayLabel
            : (isTomorrow
                  ? tomorrowLabel
                  : _formatDatePattern(
                      'EEEE',
                      parsedDate,
                      appLang,
                    ).toUpperCase());
        final dateDisplay = _formatDatePattern('MMM d', parsedDate, appLang);

        timelineData.add({
          'isHeader': true,
          'dayLabel': dayLabel,
          'dateDisplay': dateDisplay,
        });
      }

      timelineData.add(item);
    }

    if (timelineData.isEmpty && allTasks.isEmpty) {
      final existing = await HomeWidget.getWidgetData<String>(
        'timeline_agenda_data',
      );
      if (existing != null && existing.isNotEmpty && existing != '[]') {
        return;
      }
    }

    try {
      await HomeWidget.saveWidgetData<String>(
        'timeline_agenda_data',
        jsonEncode(timelineData),
      );
    } catch (e) {
      AppLogger.debug('Failed to save timeline_agenda_data: $e');
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

  /// Update Quick Actions Control Center Widget
  Future<void> updateQuickActionWidget(
    List<Task> allTasks, {
    String? userId,
  }) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final categoryTasks = await _filterTasksByCategory(allTasks);
    final pendingToday = categoryTasks.where((t) {
      if (t.isCompleted || (t.isDeleted ?? false)) return false;
      if (t.dueDate == null) return true;
      return t.dueDate!.isAfter(today.subtract(const Duration(seconds: 1))) &&
          t.dueDate!.isBefore(tomorrow);
    }).length;

    final completedToday = categoryTasks.where((t) {
      if (!t.isCompleted || (t.isDeleted ?? false)) return false;
      if (t.dueDate == null) return true;
      return t.dueDate!.isAfter(today.subtract(const Duration(seconds: 1))) &&
          t.dueDate!.isBefore(tomorrow);
    }).length;

    await Future.wait([
      HomeWidget.saveWidgetData<int>(
        'quick_action_pending_count',
        pendingToday,
      ),
      HomeWidget.saveWidgetData<int>(
        'quick_action_completed_count',
        completedToday,
      ),
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
    final clock = await clockFormat();
    final now = DateTime.now();
    final upcomingList = <Map<String, dynamic>>[];

    // 1. Pending tasks. Undated tasks rank after anything due in the next
    // 24 hours, so a meeting in 10 minutes isn't hidden behind them.
    final categoryTasks = await _filterTasksByCategory(allTasks);
    for (final t in categoryTasks.where(
      (t) => !t.isCompleted && !(t.isDeleted ?? false),
    )) {
      final due = t.dueDate?.toLocal();
      if (due != null && !due.isAfter(now.subtract(const Duration(hours: 1)))) {
        continue;
      }
      final cat = getCategoryById(t.categoryId);
      upcomingList.add({
        'type': 'task',
        'id': t.id,
        'title': t.title,
        'subtitle': cat?.name ?? '',
        'category_color': cat != null
            ? '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}'
            : '#6366F1',
        'rank': due ?? now.add(const Duration(hours: 24)),
        'start': due,
        'priority': t.priority.name,
      });
    }

    // 2. Timed calendar events (all-day events aren't "up next").
    try {
      Map<String, String> calendarColors = {};
      try {
        calendarColors = await _calendarService.getCalendarColors();
      } catch (_) {}
      final noTitleLabel = await _getNoTitleLabel();
      final calendarEvents = await _getFilteredCalendarEvents(
        startDate: now,
        endDate: now.add(const Duration(days: 3)),
      );
      for (final e in calendarEvents) {
        if (e.start == null || (e.allDay ?? false)) continue;
        final start = e.start!.toLocal();
        if (!start.isAfter(now.subtract(const Duration(minutes: 15)))) {
          continue;
        }
        upcomingList.add({
          'type': 'event',
          'id': e.eventId ?? '',
          'title': e.title ?? noTitleLabel,
          'subtitle': e.location ?? '',
          'category_color': calendarColors[e.calendarId] ?? '#4285F4',
          'rank': start,
          'start': start,
          'priority': '',
        });
      }
    } catch (_) {}

    // 3. ROCIs Schedule classes
    final noTitle = await _getNoTitleLabel();
    for (final o in scheduleOccurrences(
      await _getScheduleEvents(),
      now,
      now.add(const Duration(days: 3)),
    )) {
      if (!o.start.isAfter(now.subtract(const Duration(minutes: 15)))) {
        continue;
      }
      upcomingList.add({
        'type': 'schedule',
        'id': o.event.id,
        'title': _scheduleTitle(o.event, noTitle),
        'subtitle': _scheduleSubtitle(o.event),
        'category_color': _scheduleColor(o.event),
        'rank': o.start,
        'start': o.start,
        'priority': '',
      });
    }

    upcomingList.sort(
      (a, b) => (a['rank'] as DateTime).compareTo(b['rank'] as DateTime),
    );

    if (upcomingList.isNotEmpty) {
      final nextItem = upcomingList.first;
      final start = nextItem['start'] as DateTime?;
      final lang = await _getAppLanguage();
      // Fallback text for older widget builds; the widget formats the
      // relative time itself from up_next_start_millis at render time.
      final timeDisplay = start == null
          ? await _getTodayLabel()
          : _isSameDay(start, now)
          ? clock.format(start)
          : _formatDatePattern('MMM d', start, lang);

      await Future.wait([
        HomeWidget.saveWidgetData<String>('up_next_type', nextItem['type']),
        HomeWidget.saveWidgetData<String>('up_next_id', nextItem['id']),
        HomeWidget.saveWidgetData<String>('up_next_title', nextItem['title']),
        HomeWidget.saveWidgetData<String>(
          'up_next_subtitle',
          nextItem['subtitle'],
        ),
        HomeWidget.saveWidgetData<String>('up_next_time_display', timeDisplay),
        HomeWidget.saveWidgetData<int>(
          'up_next_start_millis',
          start?.millisecondsSinceEpoch ?? -1,
        ),
        HomeWidget.saveWidgetData<String>(
          'up_next_priority',
          nextItem['priority'],
        ),
        HomeWidget.saveWidgetData<String>(
          'up_next_color',
          nextItem['category_color'],
        ),
      ]);
    } else {
      final completedTitle = await _getAllTasksCompletedLabel();
      final clearBadge = await _getClearLabel();
      await Future.wait([
        HomeWidget.saveWidgetData<String>('up_next_type', 'none'),
        HomeWidget.saveWidgetData<String>('up_next_id', ''),
        HomeWidget.saveWidgetData<String>('up_next_title', completedTitle),
        HomeWidget.saveWidgetData<String>('up_next_subtitle', ''),
        HomeWidget.saveWidgetData<String>('up_next_time_display', clearBadge),
        HomeWidget.saveWidgetData<int>('up_next_start_millis', -1),
        HomeWidget.saveWidgetData<String>('up_next_priority', ''),
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

  /// Update Kanban Board Widget
  Future<void> updateKanbanWidget(
    List<Task> allTasks,
    Category? Function(String?) getCategoryById, {
    String? userId,
  }) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);

    final lang = await _getAppLanguage();
    final todayLabel = await _getTodayLabel();
    final tomorrowLabel = await _getTomorrowLabel();
    final overdueLabel = await _getOverdueLabel();

    final todoTasks = <Map<String, dynamic>>[];
    final inFocusTasks = <Map<String, dynamic>>[];
    final doneTasks = <Map<String, dynamic>>[];

    // Filter active and completed (ignore deleted) after applying category preference
    final categoryTasks = await _filterTasksByCategory(allTasks);
    final validTasks = categoryTasks
        .where((t) => !(t.isDeleted ?? false))
        .toList();

    for (final t in validTasks) {
      final cat = getCategoryById(t.categoryId);
      final isOverdue =
          !t.isCompleted && t.dueDate != null && t.dueDate!.isBefore(today);
      final isToday = t.dueDate != null && _isSameDay(t.dueDate!, today);
      final isTomorrow = t.dueDate != null && _isSameDay(t.dueDate!, tomorrow);

      String dateDisplay = '';
      if (t.dueDate != null) {
        final formattedDate = _formatDatePattern('MMM d', t.dueDate!, lang);
        if (isToday) {
          dateDisplay = todayLabel;
        } else if (isTomorrow) {
          dateDisplay = tomorrowLabel;
        } else if (isOverdue) {
          dateDisplay = '$overdueLabel ($formattedDate)';
        } else {
          dateDisplay = formattedDate;
        }
      }

      final item = {
        'id': t.id,
        'title': t.title,
        'category': cat?.name ?? '',
        'category_color': cat != null
            ? '#${cat.colorValue.toRadixString(16).padLeft(8, '0')}'
            : '#6366F1',
        'priority': t.priority.name,
        'isCompleted': t.isCompleted,
        'isOverdue': isOverdue,
        'dateDisplay': dateDisplay,
      };

      if (t.isCompleted) {
        doneTasks.add(item);
      } else if (isToday || isOverdue || t.priority == TaskPriority.high) {
        inFocusTasks.add(item);
      } else {
        todoTasks.add(item);
      }
    }

    final kanbanData = {
      'column_todo': todoTasks,
      'column_infocus': inFocusTasks,
      'column_done': doneTasks,
    };

    final bool isKanbanEmpty =
        todoTasks.isEmpty && inFocusTasks.isEmpty && doneTasks.isEmpty;
    if (isKanbanEmpty && allTasks.isEmpty) {
      final existing = await HomeWidget.getWidgetData<String>('kanban_data');
      if (existing != null && existing.isNotEmpty && existing != '{}') {
        return;
      }
    }

    try {
      await HomeWidget.saveWidgetData<String>(
        'kanban_data',
        jsonEncode(kanbanData),
      );
    } catch (e) {
      AppLogger.debug('Failed to save kanban_data: $e');
    }

    try {
      await HomeWidget.updateWidget(
        name: 'KanbanWidgetProvider',
        iOSName: 'KanbanWidget',
      );
    } catch (e) {
      AppLogger.debug('Failed to update KanbanWidget: $e');
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
