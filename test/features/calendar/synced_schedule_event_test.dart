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

        // Sunday before start date (Sept 6) -> Should not occur
        final pastSunday = DateTime(2026, 8, 30);
        expect(event.occursOnDay(pastSunday), isFalse);
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
