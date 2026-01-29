import 'package:flutter/material.dart';
import 'dart:async';
import 'package:device_calendar/device_calendar.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/core/models/schedule_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';

/// Wrapper class to represent schedule events from ROCIs-Schedule
class ScheduleEventWrapper {
  final ScheduleEventData event;

  ScheduleEventWrapper(this.event);

  String get title => event.title;
  DateTime get start => event.startTime;
  DateTime get end => event.endTime;
  String get location => event.location;
  String get notes => event.notes;
  String get eventType => event.eventTypeName;
  Color? get color => event.courseColor;
}

/// Wrapper class to represent assignments from ROCIs-Schedule
class AssignmentWrapper {
  final AssignmentData assignment;

  AssignmentWrapper(this.assignment);

  String get title => assignment.title;
  DateTime get dueDate => assignment.dueDate;
  String get description => assignment.description;
  String get priority => assignment.priorityName;
  Color? get color => assignment.courseColor;
}

class CalendarProvider extends ChangeNotifier {
  final CalendarService _calendarService;
  final ScheduleFirestoreService _scheduleService;
  final FullCalendarWidgetService _widgetService;
  Map<DateTime, List<dynamic>> _eventsMap = {};
  List<Event> _events = [];
  List<ScheduleEventWrapper> _scheduleEvents = [];
  List<AssignmentWrapper> _assignments = [];
  bool _showTasks = true;
  bool _showGoogleCalendar = true;
  bool _showRocisSchedule = true;
  bool _isLoading = false;
  String? _userId;
  List<Calendar> _availableCalendars = [];
  Set<String> _selectedCalendarIds = {};

  StreamSubscription<List<ScheduleEventData>>? _scheduleEventsSubscription;
  StreamSubscription<List<AssignmentData>>? _assignmentsSubscription;

  CalendarProvider(
    this._calendarService,
    this._scheduleService,
    this._widgetService,
  );

  @override
  void dispose() {
    _scheduleEventsSubscription?.cancel();
    _assignmentsSubscription?.cancel();
    super.dispose();
  }

  List<Event> get events => _events;
  List<ScheduleEventWrapper> get scheduleEvents => _scheduleEvents;
  List<AssignmentWrapper> get assignments => _assignments;
  bool get showTasks => _showTasks;
  bool get showGoogleCalendar => _showGoogleCalendar;
  bool get showRocisSchedule => _showRocisSchedule;
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

  /// Set the user email for cross-app schedule data lookup
  /// This is used to find the user's data in the ROCIs-Schedule Firestore
  void setUserEmail(String? email) {
    _scheduleService.setUserEmail(email);
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
    final nextShowRocisSchedule =
        prefs.getBool('full_calendar_show_rocis') ?? true;
    final savedCalendarIds = prefs.getStringList('full_calendar_selected_ids');

    final hasChanges =
        nextShowTasks != _showTasks ||
        nextShowGoogleCalendar != _showGoogleCalendar ||
        nextShowRocisSchedule != _showRocisSchedule ||
        savedCalendarIds != null;

    _showTasks = nextShowTasks;
    _showGoogleCalendar = nextShowGoogleCalendar;
    _showRocisSchedule = nextShowRocisSchedule;
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
    bool? showRocisSchedule,
  }) async {
    final nextShowTasks = showTasks ?? _showTasks;
    final nextShowGoogleCalendar = showGoogleCalendar ?? _showGoogleCalendar;
    final nextShowRocisSchedule = showRocisSchedule ?? _showRocisSchedule;

    final hasChanges =
        nextShowTasks != _showTasks ||
        nextShowGoogleCalendar != _showGoogleCalendar ||
        nextShowRocisSchedule != _showRocisSchedule;

    _showTasks = nextShowTasks;
    _showGoogleCalendar = nextShowGoogleCalendar;
    _showRocisSchedule = nextShowRocisSchedule;

    if (hasChanges) {
      notifyListeners();
      _updateWidgetFilters();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('full_calendar_show_tasks', _showTasks);
    await prefs.setBool('full_calendar_show_google', _showGoogleCalendar);
    await prefs.setBool('full_calendar_show_rocis', _showRocisSchedule);
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
      showRocisSchedule: _showRocisSchedule,
      selectedCalendarIds: _selectedCalendarIds.toList(),
    );
    await _widgetService.saveFilters(filters);
    await _widgetService.updateFullCalendarWidget(userId: _userId);
  }

  Future<void> loadEvents() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch available calendars first to populate the list
      _availableCalendars = await _calendarService.getAvailableCalendars();

      // If no calendars are selected yet, default to all of them
      if (_selectedCalendarIds.isEmpty && _availableCalendars.isNotEmpty) {
        _selectedCalendarIds = _availableCalendars
            .where((c) => c.id != null)
            .map((c) => c.id!)
            .toSet();
      }

      // Load device calendar events
      _events = await _calendarService.getEvents(
        calendarIds: _selectedCalendarIds.toList(),
      );

      // Load ROCIs-Schedule events if user is authenticated
      await _loadScheduleData();

      _processEventsToMap();
    } catch (e) {
      debugPrint('Error loading events in provider: $e');
      _events = [];
      _scheduleEvents = [];
      _assignments = [];
      _eventsMap = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load schedule data from ROCIs-Schedule Firestore
  Future<void> _loadScheduleData() async {
    _scheduleEventsSubscription?.cancel();
    _assignmentsSubscription?.cancel();

    if (_userId == null ||
        !_scheduleService.isReady ||
        !_scheduleService.isAuthenticated) {
      debugPrint(
        'CalendarProvider: Skipping schedule data load (userId=$_userId, isReady=${_scheduleService.isReady}, isAuthenticated=${_scheduleService.isAuthenticated})',
      );
      _scheduleEvents = [];
      _assignments = [];
      return;
    }

    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - 1, 1);
      final endDate = DateTime(now.year, now.month + 2, 0);

      debugPrint(
        'CalendarProvider: Subscribing to schedule data for user $_userId',
      );

      final eventsCompleter = Completer<void>();
      final assignmentsCompleter = Completer<void>();

      // Subscribe to schedule events
      _scheduleEventsSubscription = _scheduleService
          .getScheduleEventsStream(_userId!, startDate, endDate)
          .listen(
            (events) {
              _scheduleEvents = events
                  .map((e) => ScheduleEventWrapper(e))
                  .toList();
              debugPrint(
                'CalendarProvider: Received ${_scheduleEvents.length} schedule events from stream',
              );
              _processEventsToMap();
              notifyListeners();
              if (!eventsCompleter.isCompleted) eventsCompleter.complete();
            },
            onError: (e) {
              debugPrint(
                'CalendarProvider: Error in schedule events stream: $e',
              );
              if (!eventsCompleter.isCompleted) eventsCompleter.complete();
            },
          );

      // Subscribe to assignments
      _assignmentsSubscription = _scheduleService
          .getAssignmentsStream(_userId!, startDate, endDate)
          .listen(
            (assignmentData) {
              _assignments = assignmentData
                  .map((a) => AssignmentWrapper(a))
                  .toList();
              debugPrint(
                'CalendarProvider: Received ${_assignments.length} assignments from stream',
              );
              _processEventsToMap();
              notifyListeners();
              if (!assignmentsCompleter.isCompleted) {
                assignmentsCompleter.complete();
              }
            },
            onError: (e) {
              debugPrint('CalendarProvider: Error in assignments stream: $e');
              if (!assignmentsCompleter.isCompleted) {
                assignmentsCompleter.complete();
              }
            },
          );

      // Wait for initial data or timeout
      await Future.wait([
        eventsCompleter.future,
        assignmentsCompleter.future,
      ]).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
            'CalendarProvider: Timeout waiting for initial schedule data',
          );
          return [];
        },
      );
    } catch (e) {
      debugPrint(
        'CalendarProvider: Error setting up schedule data streams: $e',
      );
      _scheduleEvents = [];
      _assignments = [];
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
        if (currentDay == endDay &&
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

        currentDay = currentDay.add(const Duration(days: 1));
      }
    }

    // Process ROCIs-Schedule events
    for (final scheduleEvent in _scheduleEvents) {
      final normalizedDay = DateTime(
        scheduleEvent.start.year,
        scheduleEvent.start.month,
        scheduleEvent.start.day,
      );
      if (_eventsMap[normalizedDay] == null) {
        _eventsMap[normalizedDay] = [];
      }
      _eventsMap[normalizedDay]!.add(scheduleEvent);
    }

    // Process ROCIs-Schedule assignments
    for (final assignment in _assignments) {
      final normalizedDay = DateTime(
        assignment.dueDate.year,
        assignment.dueDate.month,
        assignment.dueDate.day,
      );
      if (_eventsMap[normalizedDay] == null) {
        _eventsMap[normalizedDay] = [];
      }
      _eventsMap[normalizedDay]!.add(assignment);
    }
  }

  /// Get all events for a specific day (device calendar events, schedule events, and assignments)
  List<dynamic> getEventsForDay(DateTime day) {
    // Normalize day to midnight
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final events = _eventsMap[normalizedDay] ?? [];
    if (_showGoogleCalendar && _showRocisSchedule) {
      return events;
    }
    return events.where((event) {
      if (event is Event) {
        return _showGoogleCalendar;
      }
      if (event is ScheduleEventWrapper || event is AssignmentWrapper) {
        return _showRocisSchedule;
      }
      return true;
    }).toList();
  }
}

bool _isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) {
    return false;
  }

  return a.year == b.year && a.month == b.month && a.day == b.day;
}
