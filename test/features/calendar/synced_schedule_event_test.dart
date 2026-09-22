import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';

void main() {
  group('SyncedScheduleEvent', () {
    test('constructs from map with timestamp dates and courseMap', () {
      final now = DateTime(2026, 9, 12, 10, 0);
      final later = DateTime(2026, 9, 12, 12, 0);

      final event = SyncedScheduleEvent.fromMap(
        {
          'id': 'event_1',
          'title': 'Calculus Lecture',
          'courseId': 'course_101',
          'location': 'Auditorium 3',
          'type': 1,
          'startTime': Timestamp.fromDate(now),
          'endTime': Timestamp.fromDate(later),
          'recurring': true,
          'daysOfWeek': [0, 2, 4], // Sun, Tue, Thu in schedule app format
          'notes': 'Bring textbook',
        },
        courseMap: {
          'name': 'Calculus 1',
          'code': 'MATH101',
          'color': 0xFF1E88E5,
        },
      );

      expect(event.id, 'event_1');
      expect(event.title, 'Calculus Lecture');
      expect(event.courseId, 'course_101');
      expect(event.courseName, 'Calculus 1');
      expect(event.courseCode, 'MATH101');
      expect(event.color, const Color(0xFF1E88E5));
      expect(event.recurring, isTrue);
      expect(event.daysOfWeek, [0, 2, 4]);
      expect(event.startTime, now);
      expect(event.endTime, later);
    });

    test(
      'parses comma-separated daysOfWeek and string timestamps gracefully',
      () {
        final event = SyncedScheduleEvent.fromMap({
          'id': 'event_2',
          'title': 'Physics Lab',
          'startTime': '2026-09-12T14:00:00.000',
          'endTime': '2026-09-12T16:00:00.000',
          'recurring': 1,
          'daysOfWeek': '1, 3, 5',
        });

        expect(event.recurring, isTrue);
        expect(event.daysOfWeek, [1, 3, 5]);
        expect(event.color, const Color(0xFF3F51B5)); // Default fallback
      },
    );

    test(
      'occursOnDay accurately detects recurrence with Sunday=0 convention',
      () {
        // Start on Sunday Sept 6, 2026
        final start = DateTime(2026, 9, 6, 9, 0);
        final event = SyncedScheduleEvent(
          id: 'rec_1',
          title: 'Weekly Seminar',
          courseId: 'c1',
          courseName: 'Seminar',
          courseCode: 'SEM',
          location: 'Room 10',
          typeIndex: 0,
          startTime: start,
          endTime: start.add(const Duration(hours: 2)),
          recurring: true,
          daysOfWeek: const [0, 1], // Sunday (0) and Monday (1)
          color: const Color(0xFF3F51B5),
          notes: '',
        );

        // Sunday Sept 13, 2026 (weekday is Sunday -> 0 in schedule convention)
        final sunday = DateTime(2026, 9, 13);
        expect(sunday.weekday, DateTime.sunday);
        expect(event.occursOnDay(sunday), isTrue);

        // Monday Sept 14, 2026 (weekday is Monday -> 1 in schedule convention)
        final monday = DateTime(2026, 9, 14);
        expect(event.occursOnDay(monday), isTrue);

        // Tuesday Sept 15, 2026 (weekday is Tuesday -> 2, not in daysOfWeek)
        final tuesday = DateTime(2026, 9, 15);
        expect(event.occursOnDay(tuesday), isFalse);

        // Sunday before Sept 6 -> Recurring classes repeat on daysOfWeek across months
        final pastSunday = DateTime(2026, 8, 30);
        expect(event.occursOnDay(pastSunday), isTrue);
      },
    );

    test('occursOnDay works for non-recurring single-instance events', () {
      final eventDate = DateTime(2026, 9, 12, 15, 30);
      final event = SyncedScheduleEvent(
        id: 'single_1',
        title: 'Midterm Exam',
        courseId: 'c1',
        courseName: 'Math',
        courseCode: 'MTH',
        location: 'Hall A',
        typeIndex: 2,
        startTime: eventDate,
        endTime: eventDate.add(const Duration(hours: 3)),
        recurring: false,
        daysOfWeek: const [],
        color: const Color(0xFFE53935),
        notes: '',
      );

      expect(event.occursOnDay(DateTime(2026, 9, 12, 8, 0)), isTrue);
      expect(event.occursOnDay(DateTime(2026, 9, 13)), isFalse);
    });

    test('serializes toMap and reconstructs via fromMap accurately', () {
      final start = DateTime(2026, 9, 1, 10, 0);
      final event = SyncedScheduleEvent(
        id: 'roundtrip_1',
        title: 'Data Structures',
        courseId: 'CS201',
        courseName: 'Data Structures',
        courseCode: 'CS201',
        location: 'Lab 4',
        typeIndex: 1,
        startTime: start,
        endTime: start.add(const Duration(hours: 2)),
        recurring: true,
        daysOfWeek: const [1, 3], // Mon, Wed
        color: const Color(0xFF4CAF50),
        notes: 'Room key required',
      );

      final map = event.toMap();
      final restored = SyncedScheduleEvent.fromMap(map);

      expect(restored.id, event.id);
      expect(restored.title, event.title);
      expect(restored.courseId, event.courseId);
      expect(restored.courseName, event.courseName);
      expect(restored.location, event.location);
      expect(restored.typeIndex, event.typeIndex);
      expect(restored.recurring, isTrue);
      expect(restored.daysOfWeek, [1, 3]);
      expect(restored.color.toARGB32(), event.color.toARGB32());
    });

    test(
      'recurring event recurs across upcoming and previous months without cutoff',
      () {
        final start = DateTime(2026, 9, 15, 10, 0); // Created mid-September
        final event = SyncedScheduleEvent(
          id: 'rec_months',
          title: 'Operating Systems',
          courseId: 'CS301',
          courseName: 'OS',
          courseCode: 'CS301',
          location: 'Room 101',
          typeIndex: 0,
          startTime: start,
          endTime: start.add(const Duration(hours: 2)),
          recurring: true,
          daysOfWeek: const [2], // Tuesday (2 in schedule format)
          color: const Color(0xFF2196F3),
          notes: '',
        );

        // Tuesday in previous month (August 25, 2026) -> should occur!
        final augustTuesday = DateTime(2026, 8, 25);
        expect(augustTuesday.weekday, DateTime.tuesday);
        expect(event.occursOnDay(augustTuesday), isTrue);

        // Tuesday in upcoming month (October 20, 2026) -> should occur!
        final octoberTuesday = DateTime(2026, 10, 20);
        expect(octoberTuesday.weekday, DateTime.tuesday);
        expect(event.occursOnDay(octoberTuesday), isTrue);

        // Wednesday in October -> should not occur
        final octoberWednesday = DateTime(2026, 10, 21);
        expect(event.occursOnDay(octoberWednesday), isFalse);
      },
    );

    test('parses single integer or num daysOfWeek and string recurring', () {
      final event1 = SyncedScheduleEvent.fromMap({
        'id': 'num_day',
        'title': 'Single Day Course',
        'daysOfWeek': 2, // Tuesday as int
        'recurring': '1', // string recurring
        'startTime': '2026-09-22T10:00:00.000',
        'endTime': '2026-09-22T12:00:00.000',
      });

      expect(event1.recurring, isTrue);
      expect(event1.daysOfWeek, [2]);

      final event2 = SyncedScheduleEvent.fromMap({
        'id': 'str_recurring_bool',
        'title': 'True String Recurring',
        'daysOfWeek': [1, 3],
        'recurring': 'true',
        'startTime': '2026-09-22T10:00:00.000',
        'endTime': '2026-09-22T12:00:00.000',
      });

      expect(event2.recurring, isTrue);
      expect(event2.daysOfWeek, [1, 3]);
    });

    test('decodeFirestoreFields decodes REST field maps accurately', () {
      final restFields = {
        'id': {'stringValue': 'event_xyz'},
        'title': {'stringValue': 'Physics'},
        'type': {'integerValue': '2'},
        'recurring': {'integerValue': '1'},
        'daysOfWeek': {'stringValue': '2'},
        'color': {'nullValue': null},
        'credits': {'doubleValue': 3.5},
        'active': {'booleanValue': true},
        'tags': {
          'arrayValue': {
            'values': [
              {'stringValue': 'lab'},
              {'stringValue': 'mandatory'},
            ],
          },
        },
      };

      final decoded = ScheduleFirestoreService.decodeFirestoreFields(restFields);
      expect(decoded['id'], 'event_xyz');
      expect(decoded['title'], 'Physics');
      expect(decoded['type'], 2);
      expect(decoded['recurring'], 1);
      expect(decoded['daysOfWeek'], '2');
      expect(decoded['color'], isNull);
      expect(decoded['credits'], 3.5);
      expect(decoded['active'], isTrue);
      expect(decoded['tags'], ['lab', 'mandatory']);
    });
  });

  group('FullCalendarFilters', () {
    test('serializes and deserializes showRocisSchedule correctly', () {
      const filters = FullCalendarFilters(
        showTasks: true,
        showGoogleCalendar: false,
        showRocisSchedule: true,
        selectedCalendarIds: ['cal_1'],
      );

      final map = filters.toMap();
      expect(map['showRocisSchedule'], isTrue);

      final restored = FullCalendarFilters.fromMap(map);
      expect(restored.showRocisSchedule, isTrue);
      expect(restored.showTasks, isTrue);
      expect(restored.showGoogleCalendar, isFalse);
      expect(restored.selectedCalendarIds, ['cal_1']);

      final toggled = restored.copyWith(showRocisSchedule: false);
      expect(toggled.showRocisSchedule, isFalse);
    });
  });
}
