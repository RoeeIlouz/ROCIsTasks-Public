import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/core/services/widget_data_service.dart';

void main() {
  const fallback = Color(0xFF0284C7);

  group('ROCIs Schedule Google calendar', () {
    test('is recognised by name, ignoring case and spaces', () {
      expect(
        CalendarService.isRocisScheduleCalendarName('ROCIs Schedule'),
        isTrue,
      );
      expect(
        CalendarService.isRocisScheduleCalendarName(' rocis schedule '),
        isTrue,
      );
      expect(CalendarService.isRocisScheduleCalendarName('Work'), isFalse);
      expect(CalendarService.isRocisScheduleCalendarName(null), isFalse);
    });

    test('splits "Course · Label" titles', () {
      final split = CalendarService.splitExportedTitle('Calculus 1 · Lecture');
      expect(split.course, 'Calculus 1');
      expect(split.label, 'Lecture');

      final plain = CalendarService.splitExportedTitle('Dentist');
      expect(plain.course, '');
      expect(plain.label, 'Dentist');
    });
  });

  group('exportedScheduleEventFromGoogle', () {
    test('maps an exported class to a schedule event', () {
      final event = CalendarService.exportedScheduleEventFromGoogle({
        'id': 'rs6576656e745f31_20261026T080000Z',
        'summary': 'Calculus 1 · Lecture',
        'description': 'Course: Calculus 1 (MATH101)\nType: Lecture',
        'location': 'Auditorium 3',
        'colorId': '9',
        'start': {'dateTime': '2026-10-26T10:00:00+02:00'},
        'end': {'dateTime': '2026-10-26T12:00:00+02:00'},
        'extendedProperties': {
          'private': {'rocisEventId': 'event_1', 'rocisHash': 'abc'},
        },
      }, fallbackColor: fallback)!;

      expect(event.id, 'event_1');
      expect(event.courseName, 'Calculus 1');
      expect(event.title, 'Lecture');
      expect(event.courseCode, 'MATH101');
      expect(event.location, 'Auditorium 3');
      expect(event.color, const Color(0xFF3F51B5));
      expect(event.recurring, isFalse);
      expect(
        event.endTime.difference(event.startTime),
        const Duration(hours: 2),
      );
      expect(event.occursOnDay(event.startTime), isTrue);
    });

    test('falls back to the schedule colour and skips cancelled events', () {
      final event = CalendarService.exportedScheduleEventFromGoogle({
        'id': 'x',
        'summary': 'Physics Lab',
        'start': {'dateTime': '2026-10-27T14:00:00Z'},
      }, fallbackColor: fallback)!;
      expect(event.color, fallback);
      expect(event.id, 'x');
      expect(
        event.endTime.difference(event.startTime),
        const Duration(hours: 1),
      );

      expect(
        CalendarService.exportedScheduleEventFromGoogle({
          'status': 'cancelled',
          'start': {'dateTime': '2026-10-27T14:00:00Z'},
        }, fallbackColor: fallback),
        isNull,
      );
    });
  });

  group('WidgetDataService.scheduleOccurrences', () {
    SyncedScheduleEvent event({required bool recurring}) => SyncedScheduleEvent(
      id: 'c1',
      title: 'Lecture',
      courseId: 'course',
      courseName: 'Calculus',
      courseCode: 'MATH',
      location: '',
      typeIndex: 0,
      startTime: DateTime(2026, 10, 25, 10),
      endTime: DateTime(2026, 10, 25, 12),
      recurring: recurring,
      daysOfWeek: const [0, 2], // Sunday, Tuesday
      color: fallback,
      notes: '',
      semesterStartDate: DateTime(2026, 10, 25),
      semesterEndDate: DateTime(2027, 2, 5),
    );

    test('expands a weekly class to its class times in range', () {
      final occurrences = WidgetDataService.scheduleOccurrences(
        [event(recurring: true)],
        DateTime(2026, 10, 25, 9),
        DateTime(2026, 11, 1),
      );
      expect(occurrences.map((o) => o.start), [
        DateTime(2026, 10, 25, 10),
        DateTime(2026, 10, 27, 10),
      ]);
      expect(occurrences.first.end, DateTime(2026, 10, 25, 12));
    });

    test('keeps a one-off event only inside the range', () {
      final oneOff = event(recurring: false);
      expect(
        WidgetDataService.scheduleOccurrences(
          [oneOff],
          DateTime(2026, 10, 25),
          DateTime(2026, 10, 26),
        ),
        hasLength(1),
      );
      expect(
        WidgetDataService.scheduleOccurrences(
          [oneOff],
          DateTime(2026, 10, 26),
          DateTime(2026, 10, 30),
        ),
        isEmpty,
      );
    });
  });
}
