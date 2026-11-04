import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/features/calendar/utils/calendar_item_order.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';

SyncedScheduleEvent lesson(String id, DateTime start) => SyncedScheduleEvent(
  id: id,
  title: id,
  courseId: 'c',
  courseName: 'c',
  courseCode: '',
  location: '',
  typeIndex: 0,
  startTime: start,
  endTime: start.add(const Duration(hours: 2)),
  recurring: false,
  daysOfWeek: const [],
  color: const Color(0xFF000000),
  notes: '',
);

void main() {
  test('items are ordered by time of day, all-day and undated first', () {
    final task = Task(
      id: 't',
      title: 't',
      dueDate: DateTime(2026, 11, 8, 10, 30),
    );
    final undated = Task(id: 'u', title: 'u');
    final late = lesson('late', DateTime(2026, 11, 8, 16));
    final early = lesson('early', DateTime(2026, 11, 8, 9));
    final allDay = Event('cal', title: 'holiday', allDay: true);

    final sorted = sortCalendarItems([late, task, allDay, undated, early]);

    expect(
      sorted.map((e) => e is Task ? e.id : (e is Event ? 'allday' : e.id)),
      ['allday', 'u', 'early', 't', 'late'],
    );
  });

  test('a weekly class is ordered by its time, not its first date', () {
    final fridayFirstWeek = lesson('weekly', DateTime(2026, 10, 25, 8));
    final today = lesson('today', DateTime(2026, 11, 8, 12));
    final sorted = sortCalendarItems([today, fridayFirstWeek]);
    expect((sorted.first as SyncedScheduleEvent).id, 'weekly');
  });

  test('equal times keep their incoming order', () {
    final a = lesson('a', DateTime(2026, 11, 8, 9));
    final b = lesson('b', DateTime(2026, 11, 8, 9));
    final sorted = sortCalendarItems([b, a]);
    expect(sorted.map((e) => (e as SyncedScheduleEvent).id), ['b', 'a']);
  });

  test('empty input gives an empty list', () {
    expect(sortCalendarItems(const []), isEmpty);
  });
}
