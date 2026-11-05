import 'package:device_calendar/device_calendar.dart';
import 'package:rocis_tasks/core/models/schedule_assignment.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';

/// Minutes after midnight that order one calendar item within its day, or -1
/// for items with no clock time (all-day events, tasks without a due date),
/// which come first. Only the time of day counts: a weekly class stores the
/// date of its first week, not the date being viewed.
int calendarItemMinutes(dynamic item) {
  DateTime? at;
  var allDay = false;
  if (item is Task) {
    at = item.dueDate;
  } else if (item is Event) {
    at = item.start;
    allDay = item.allDay == true;
  } else if (item is SyncedScheduleEvent) {
    at = item.startTime;
  } else if (item is ScheduleAssignment) {
    at = item.dueDate;
  }
  if (allDay || at == null) return -1;
  return at.hour * 60 + at.minute;
}

/// A new list ordered by time of day (all-day first). Items starting at the
/// same time keep their incoming order, so tasks stay ahead of events.
List<dynamic> sortCalendarItems(Iterable<dynamic> items) {
  final indexed = items.toList().asMap().entries.toList()
    ..sort((a, b) {
      final byTime = calendarItemMinutes(
        a.value,
      ).compareTo(calendarItemMinutes(b.value));
      return byTime != 0 ? byTime : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}
