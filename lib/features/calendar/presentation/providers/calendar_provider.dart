import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';

class CalendarProvider extends ChangeNotifier {
  final CalendarService _calendarService;
  Map<DateTime, List<Event>> _eventsMap = {};
  List<Event> _events = [];
  bool _isLoading = false;

  CalendarProvider(this._calendarService);

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> loadEvents() async {
    _isLoading = true;
    notifyListeners();

    try {
      _events = await _calendarService.getEvents();
      _processEventsToMap();
    } catch (e) {
      debugPrint('Error loading events in provider: $e');
      _events = [];
      _eventsMap = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _processEventsToMap() {
    _eventsMap = {};
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
  }

  List<Event> getEventsForDay(DateTime day) {
    // Normalize day to midnight
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _eventsMap[normalizedDay] ?? [];
  }
}

bool _isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) {
    return false;
  }

  return a.year == b.year && a.month == b.month && a.day == b.day;
}
