import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:rocis_tasks/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class MockCalendarService extends Mock implements CalendarService {}

class MockFullCalendarWidgetService extends Mock
    implements FullCalendarWidgetService {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    registerFallbackValue(const FullCalendarFilters());
  });

  group('CalendarProvider RFC 5545 & Event Day Span Logic', () {
    late MockCalendarService mockCalendarService;
    late MockFullCalendarWidgetService mockWidgetService;
    late CalendarProvider calendarProvider;

    setUp(() {
      mockCalendarService = MockCalendarService();
      mockWidgetService = MockFullCalendarWidgetService();

      when(
        () => mockCalendarService.getAvailableCalendars(),
      ).thenAnswer((_) async => []);
      when(() => mockWidgetService.saveFilters(any())).thenAnswer((_) async {});
      when(
        () => mockWidgetService.updateFullCalendarWidget(
          userId: any(named: 'userId'),
          userEmail: any(named: 'userEmail'),
          monthOffset: any(named: 'monthOffset'),
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) async {});

      calendarProvider = CalendarProvider(
        mockCalendarService,
        mockWidgetService,
      );
    });

    test(
      'single-day all-day event with exclusive midnight end date displays ONLY on start day',
      () async {
        final sep7 = DateTime(2026, 9, 7, 0, 0, 0);
        final sep8 = DateTime(2026, 9, 8, 0, 0, 0);

        final event = Event(
          'google_primary',
          eventId: 'all_day_1',
          title: 'Labor Day',
          start: tz.TZDateTime.from(sep7, tz.local),
          end: tz.TZDateTime.from(sep8, tz.local),
          allDay: true,
        );

        when(
          () => mockCalendarService.getEvents(
            calendarIds: any(named: 'calendarIds'),
          ),
        ).thenAnswer((_) async => [event]);

        await calendarProvider.loadEvents();

        final eventsDay1 = calendarProvider.getEventsForDay(
          DateTime(2026, 9, 7),
        );
        final eventsDay2 = calendarProvider.getEventsForDay(
          DateTime(2026, 9, 8),
        );

        expect(eventsDay1.length, 1);
        expect(eventsDay1.first.title, 'Labor Day');
        expect(
          eventsDay2.isEmpty,
          isTrue,
          reason: 'RFC 5545 exclusive end date must not display on next day',
        );
      },
    );

    test(
      'multi-day all-day event with exclusive midnight end date covers exactly the specified days',
      () async {
        final sep7 = DateTime(2026, 9, 7, 0, 0, 0);
        final sep9 = DateTime(2026, 9, 9, 0, 0, 0);

        final event = Event(
          'google_primary',
          eventId: 'hackathon_span',
          title: 'Hackathon',
          start: tz.TZDateTime.from(sep7, tz.local),
          end: tz.TZDateTime.from(sep9, tz.local),
          allDay: true,
        );

        when(
          () => mockCalendarService.getEvents(
            calendarIds: any(named: 'calendarIds'),
          ),
        ).thenAnswer((_) async => [event]);

        await calendarProvider.loadEvents();

        final eventsDay1 = calendarProvider.getEventsForDay(
          DateTime(2026, 9, 7),
        );
        final eventsDay2 = calendarProvider.getEventsForDay(
          DateTime(2026, 9, 8),
        );
        final eventsDay3 = calendarProvider.getEventsForDay(
          DateTime(2026, 9, 9),
        );

        expect(eventsDay1.length, 1);
        expect(eventsDay2.length, 1);
        expect(
          eventsDay3.isEmpty,
          isTrue,
          reason: 'Exclusive end date boundary should not include Day 3',
        );
      },
    );

    test(
      'timed evening event ending at midnight does not spill over to next day',
      () async {
        final start = DateTime(2026, 9, 7, 20, 0, 0);
        final end = DateTime(2026, 9, 8, 0, 0, 0);

        final event = Event(
          'google_primary',
          eventId: 'evening_concert',
          title: 'Symphony Concert',
          start: tz.TZDateTime.from(start, tz.local),
          end: tz.TZDateTime.from(end, tz.local),
          allDay: false,
        );

        when(
          () => mockCalendarService.getEvents(
            calendarIds: any(named: 'calendarIds'),
          ),
        ).thenAnswer((_) async => [event]);

        await calendarProvider.loadEvents();

        final eventsSep7 = calendarProvider.getEventsForDay(
          DateTime(2026, 9, 7),
        );
        final eventsSep8 = calendarProvider.getEventsForDay(
          DateTime(2026, 9, 8),
        );

        expect(eventsSep7.length, 1);
        expect(eventsSep8.isEmpty, isTrue);
      },
    );

    test('ROCIs Schedule synergy is gated behind Pro (isPremium)', () {
      final mockSubService = MockSubscriptionService();
      when(() => mockSubService.isPremium).thenReturn(false);

      final proGatedProvider = CalendarProvider(
        mockCalendarService,
        mockWidgetService,
        subscriptionService: mockSubService,
      );

      expect(proGatedProvider.isPremium, isFalse);
      expect(
        proGatedProvider.getScheduleEventsForDay(DateTime(2026, 9, 7)),
        isEmpty,
      );

      // When upgraded to Pro
      when(() => mockSubService.isPremium).thenReturn(true);
      expect(proGatedProvider.isPremium, isTrue);
    });
  });
}
