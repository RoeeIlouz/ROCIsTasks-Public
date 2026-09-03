import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';

void main() {
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
}
