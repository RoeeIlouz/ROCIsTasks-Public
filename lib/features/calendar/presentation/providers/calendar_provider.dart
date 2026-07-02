import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

class CalendarProvider extends ChangeNotifier {
  final CalendarService _calendarService;
  final FullCalendarWidgetService _widgetService;
  Map<DateTime, List<dynamic>> _eventsMap = {};
  List<Event> _events = [];
  bool _showTasks = true;
  bool _showGoogleCalendar = true;
  bool _isLoading = false;
  String? _userId;
  List<Calendar> _availableCalendars = [];
  Set<String> _selectedCalendarIds = {};
  bool _isGoogleCalendarTokenExpired = false;

  CalendarProvider(this._calendarService, this._widgetService);

  bool get isGoogleCalendarTokenExpired => _isGoogleCalendarTokenExpired;
  List<Event> get events => _events;
  bool get showTasks => _showTasks;
  bool get showGoogleCalendar => _showGoogleCalendar;
  bool get isLoading => _isLoading;
  List<Calendar> get availableCalendars => _availableCalendars;
  Set<String> get selectedCalendarIds => _selectedCalendarIds;
  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  /// Set the user ID for fetching schedule data
  /// Note: This does NOT automatically reload events to avoid setState during build.
  /// Call loadEvents() separately after setting the user ID.
  void setUserId(String? userId) {
    _userId = userId;
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final nextShowTasks = prefs.getBool('full_calendar_show_tasks') ?? true;
    final nextShowGoogleCalendar =
        prefs.getBool('full_calendar_show_google') ?? true;
    final savedCalendarIds = prefs.getStringList('full_calendar_selected_ids');

    final hasChanges =
        nextShowTasks != _showTasks ||
        nextShowGoogleCalendar != _showGoogleCalendar ||
        savedCalendarIds != null;

    _showTasks = nextShowTasks;
    _showGoogleCalendar = nextShowGoogleCalendar;
    if (savedCalendarIds != null) {
      _selectedCalendarIds = savedCalendarIds.toSet();
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  Future<void> updateFilters({
    bool? showTasks,
    bool? showGoogleCalendar,
  }) async {
    final nextShowTasks = showTasks ?? _showTasks;
    final nextShowGoogleCalendar = showGoogleCalendar ?? _showGoogleCalendar;

    final hasChanges =
        nextShowTasks != _showTasks ||
        nextShowGoogleCalendar != _showGoogleCalendar;

    _showTasks = nextShowTasks;
    _showGoogleCalendar = nextShowGoogleCalendar;

    if (hasChanges) {
      notifyListeners();
      _updateWidgetFilters();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('full_calendar_show_tasks', _showTasks);
    await prefs.setBool('full_calendar_show_google', _showGoogleCalendar);
  }

  Future<void> toggleCalendarSelection(String calendarId) async {
    if (_selectedCalendarIds.contains(calendarId)) {
      _selectedCalendarIds.remove(calendarId);
    } else {
      _selectedCalendarIds.add(calendarId);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'full_calendar_selected_ids',
      _selectedCalendarIds.toList(),
    );

    // Refresh events from selected calendars
    loadEvents();
    _updateWidgetFilters();
  }

  Future<void> setAllCalendars(bool selected) async {
    if (selected) {
      _selectedCalendarIds = _availableCalendars.map((c) => c.id!).toSet();
    } else {
      _selectedCalendarIds = {};
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'full_calendar_selected_ids',
      _selectedCalendarIds.toList(),
    );

    loadEvents();
    _updateWidgetFilters();
  }

  Future<void> _updateWidgetFilters() async {
    final filters = FullCalendarFilters(
      showTasks: _showTasks,
      showGoogleCalendar: _showGoogleCalendar,
      selectedCalendarIds: _selectedCalendarIds.toList(),
    );
    await _widgetService.saveFilters(filters);
    await _widgetService.updateFullCalendarWidget(userId: _userId);
  }

  Future<void> loadEvents() async {
    _isLoading = true;
    _isGoogleCalendarTokenExpired = false;
    notifyListeners();

    try {
      // Fetch available calendars first to populate the list
      _availableCalendars = await _calendarService.getAvailableCalendars();

      if (_availableCalendars.isNotEmpty) {
        final availableIds = _availableCalendars
            .map((c) => c.id)
            .whereType<String>()
            .toSet();
        final validSelectedIds = _selectedCalendarIds.intersection(
          availableIds,
        );
        if (validSelectedIds.isEmpty) {
          // If no selected calendars are valid in the current platform's available calendars,
          // default to selecting all available calendars.
          _selectedCalendarIds = availableIds;
        } else {
          _selectedCalendarIds = validSelectedIds;
        }
      } else {
        _selectedCalendarIds = {};
      }

      // Load device calendar events
      _events = await _calendarService.getEvents(
        calendarIds: _selectedCalendarIds.toList(),
      );

      _processEventsToMap();
    } on GoogleTokenExpiredException {
      _isGoogleCalendarTokenExpired = true;
      _events = [];
      _eventsMap = {};
      AppLogger.warning('Google Calendar token expired on Web.');
    } catch (e, s) {
      // Also catch String exception representation if needed
      if (e.toString().contains('GoogleTokenExpiredException')) {
        _isGoogleCalendarTokenExpired = true;
        _events = [];
        _eventsMap = {};
      } else {
        AppLogger.error(
          'Error loading events in calendar provider',
          error: e,
          stack: s,
        );
        _events = [];
        _eventsMap = {};
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _processEventsToMap() {
    _eventsMap = {};

    // Process device calendar events
    for (final event in _events) {
      if (event.start == null) continue;

      final start = event.start!;
      final end = event.end ?? start.add(const Duration(hours: 1));

      // Normalize to dates (midnight)
      DateTime currentDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);

      // If event ends at midnight exactly (e.g. 00:00), it technically belongs to previous day logic-wise for "spans"
      // but standard is inclusive start, exclusive end for duration.
      // However, if an event is 10:00 -> 11:00, start day == end day.
      // If 10:00 -> Next Day 10:00, it covers two days.

      // Iterate through each day the event touches
      while (currentDay.isBefore(endDay) || _isSameDay(currentDay, endDay)) {
        // Special case: if end is exactly midnight and it is not the start time (i.e. not a 0-duration event at midnight),
        // we might not want to include that day depending on interpretation.
        // But for "overlap", if it ends at 00:00 of Day 2, it does not overlap Day 2's 00:00-23:59.
        // For all-day events, we treat the end date as inclusive if it's the last day.
        if (currentDay == endDay &&
            event.allDay != true &&
            end.hour == 0 &&
            end.minute == 0 &&
            end.second == 0 &&
            end.millisecond == 0 &&
            currentDay != start) {
          break;
        }

        if (_eventsMap[currentDay] == null) {
          _eventsMap[currentDay] = [];
        }
        _eventsMap[currentDay]!.add(event);

        currentDay = DateTime(
          currentDay.year,
          currentDay.month,
          currentDay.day + 1,
        );
      }
    }
  }

  /// Get all events for a specific day (device calendar events)
  List<dynamic> getEventsForDay(DateTime day) {
    // Normalize day to midnight
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final events = _eventsMap[normalizedDay] ?? [];
    if (_showGoogleCalendar) {
      return events;
    }
    return [];
  }
}

bool _isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) {
    return false;
  }

  return a.year == b.year && a.month == b.month && a.day == b.day;
}
