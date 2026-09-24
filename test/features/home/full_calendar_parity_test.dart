import 'dart:convert';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';

class MockCalendarService extends Mock implements CalendarService {}

class MockLocalTaskSource extends Mock implements LocalTaskSource {}

/// The FullCalendar widget must show the same events on the same days as the
/// in-app calendar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final saved = <String, dynamic>{};
  final key = DateFormat('yyyy-MM-dd');
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  late MockCalendarService calendar;
  late MockLocalTaskSource source;

  setUpAll(tz_data.initializeTimeZones);

  setUp(() async {
    await initializeDateFormatting('en', null);
    saved
      ..clear()
      ..['is_premium'] = true;
    SharedPreferences.setMockInitialValues({
      'full_calendar_show_schedule': false,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (
          call,
        ) async {
          final id = call.arguments?['id'] as String?;
          if (call.method == 'saveWidgetData') {
            saved[id!] = call.arguments['data'];
          }
          if (call.method == 'getWidgetData') return saved[id];
          return true;
        });

    calendar = MockCalendarService();
    source = MockLocalTaskSource();
    when(
      () => calendar.getAvailableCalendars(
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((_) async => [Calendar(id: 'cal1', name: 'Main')]);
    when(
      () =>
          calendar.getCalendarColors(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => <String, String>{});
    when(
      () => calendar.getEvents(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        calendarIds: any(named: 'calendarIds'),
      ),
    ).thenAnswer((_) async => []);
    when(source.getCategories).thenReturn([]);
    when(source.getTasks).thenReturn([]);
  });

  Future<Map<String, dynamic>> render() async {
    await FullCalendarWidgetService(
      calendar,
      source,
    ).updateFullCalendarWidget(forceRefresh: true);
    return jsonDecode(saved['full_calendar_events_by_date'] as String? ?? '{}')
        as Map<String, dynamic>;
  }

  test('all-day events stay on their own day', () async {
    final start = day(3);
    when(
      () => calendar.getEvents(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        calendarIds: any(named: 'calendarIds'),
      ),
    ).thenAnswer(
      (_) async => [
        Event(
          'cal1',
          eventId: 'holiday',
          title: 'Holiday',
          allDay: true,
          start: tz.TZDateTime.from(start, tz.local),
          end: tz.TZDateTime.from(day(4), tz.local),
        ),
      ],
    );

    final byDate = await render();

    expect(byDate.containsKey(key.format(start)), isTrue);
    expect(byDate.containsKey(key.format(day(4))), isFalse);
  });

  test(
    'recurring tasks show on their due date only, not every occurrence',
    () async {
      when(source.getTasks).thenReturn([
        Task(
          id: 'daily',
          title: 'Daily habit',
          dueDate: day(2),
          recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
        ),
      ]);

      final byDate = await render();

      expect(byDate.containsKey(key.format(day(2))), isTrue);
      expect(byDate.containsKey(key.format(day(3))), isFalse);
      expect(byDate.containsKey(key.format(day(4))), isFalse);
    },
  );

  test('private tasks stay off the home screen in private mode', () async {
    SharedPreferences.setMockInitialValues({
      'full_calendar_show_schedule': false,
      'private_mode_enabled_v1': true,
    });
    final secret = Category(
      name: 'Secret',
      colorValue: 0xFF000000,
      iconCode: 0,
      isPrivate: true,
    );
    when(source.getCategories).thenReturn([secret]);
    when(source.getTasks).thenReturn([
      Task(id: 'p', title: 'Private', dueDate: day(1), categoryId: secret.id),
      Task(id: 'o', title: 'Open', dueDate: day(1)),
    ]);

    final byDate = await render();
    final texts = (byDate[key.format(day(1))] as List)
        .map((s) => (s as Map)['text'])
        .toList();

    expect(texts, ['Open']);
  });
}
