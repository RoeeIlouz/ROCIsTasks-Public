import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);
  group('CalendarService Sanitization', () {
    late CalendarService calendarService;

    setUp(() {
      calendarService = CalendarService();
    });

    test('filters out ghost calendars with no name and no accountName', () {
      final raw = [
        Calendar(id: '1', name: 'Work', accountName: 'user@gmail.com'),
        Calendar(id: '2', name: null, accountName: null),
        Calendar(id: '3', name: '', accountName: ''),
        Calendar(id: '4', name: '   ', accountName: '   '),
        Calendar(id: '5', name: 'Unnamed', accountName: null),
        Calendar(id: '6', name: 'Unnamed Calendar', accountName: ''),
      ];

      final sanitized = calendarService.sanitizeAndFilterCalendarsForTesting(
        raw,
      );

      expect(sanitized.length, 1);
      expect(sanitized.first.id, '1');
      expect(sanitized.first.name, 'Work');
    });

    test(
      'recovers display name from accountName when calendar name is Unnamed or empty',
      () {
        final raw = [
          Calendar(id: '10', name: null, accountName: 'user@company.com'),
          Calendar(
            id: '11',
            name: 'Unnamed',
            accountName: 'personal@gmail.com',
          ),
          Calendar(id: '12', name: '', accountName: 'holidays@google.com'),
        ];

        final sanitized = calendarService.sanitizeAndFilterCalendarsForTesting(
          raw,
        );

        expect(sanitized.length, 3);
        expect(sanitized[0].name, 'user@company.com');
        expect(sanitized[1].name, 'personal@gmail.com');
        expect(sanitized[2].name, 'holidays@google.com');
      },
    );

    test('deduplicates calendars with identical IDs', () {
      final raw = [
        Calendar(id: 'primary', name: 'Primary', accountName: 'user@gmail.com'),
        Calendar(
          id: 'primary',
          name: 'Primary Duplicate',
          accountName: 'user@gmail.com',
        ),
        Calendar(id: 'custom_1', name: 'Custom', accountName: 'user@gmail.com'),
      ];

      final sanitized = calendarService.sanitizeAndFilterCalendarsForTesting(
        raw,
      );

      expect(sanitized.length, 2);
      expect(sanitized[0].id, 'primary');
      expect(sanitized[1].id, 'custom_1');
    });
  });

  group('CalendarService Event Deduplication', () {
    late CalendarService calendarService;

    setUp(() {
      calendarService = CalendarService();
    });

    test('deduplicates events with matching eventId', () {
      final now = DateTime(2026, 9, 7, 10, 0);
      final events = [
        Event(
          'cal1',
          eventId: 'ev1',
          title: 'Design Review',
          start: tz.TZDateTime.from(now, tz.local),
          end: tz.TZDateTime.from(now.add(const Duration(hours: 1)), tz.local),
        ),
        Event(
          'cal1',
          eventId: 'ev1',
          title: 'Design Review (Duplicated)',
          start: tz.TZDateTime.from(now, tz.local),
          end: tz.TZDateTime.from(now.add(const Duration(hours: 1)), tz.local),
        ),
        Event(
          'cal1',
          eventId: 'ev2',
          title: 'Sprint Planning',
          start: tz.TZDateTime.from(now, tz.local),
          end: tz.TZDateTime.from(now.add(const Duration(hours: 1)), tz.local),
        ),
      ];

      final result = calendarService.deduplicateEventsForTesting(events);
      expect(result.length, 2);
      expect(result[0].eventId, 'ev1');
      expect(result[1].eventId, 'ev2');
    });

    test(
      'deduplicates cross-provider events by title, time, and allDay fingerprint',
      () {
        final start = DateTime(2026, 9, 7, 14, 0);
        final end = DateTime(2026, 9, 7, 15, 0);
        final events = [
          Event(
            'device_cal',
            eventId: 'local_123',
            title: 'Dentist Appointment',
            start: tz.TZDateTime.from(start, tz.local),
            end: tz.TZDateTime.from(end, tz.local),
          ),
          Event(
            'google_cal',
            eventId: 'google_abc',
            title: 'dentist appointment',
            start: tz.TZDateTime.from(start, tz.local),
            end: tz.TZDateTime.from(end, tz.local),
          ),
          Event(
            'google_cal',
            eventId: 'google_xyz',
            title: 'Chemistry Lab',
            start: tz.TZDateTime.from(start, tz.local),
            end: tz.TZDateTime.from(end, tz.local),
          ),
        ];

        final result = calendarService.deduplicateEventsForTesting(events);
        expect(result.length, 2);
        expect(result[0].title, 'Dentist Appointment');
        expect(result[1].title, 'Chemistry Lab');
      },
    );
  });
}
