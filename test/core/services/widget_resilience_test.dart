import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/widget_data_service.dart';
import 'package:rocis_tasks/features/home/services/full_calendar_widget_service.dart';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/services/task_widget_service.dart';

class MockCalendarService extends Mock implements CalendarService {}

class MockLocalTaskSource extends Mock implements LocalTaskSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final savedWidgetData = <String, dynamic>{};

  setUp(() async {
    await initializeDateFormatting('en', null);
    savedWidgetData.clear();
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'saveWidgetData') {
            final id = methodCall.arguments['id'] as String;
            final data = methodCall.arguments['data'];
            savedWidgetData[id] = data;
            return true;
          } else if (methodCall.method == 'getWidgetData') {
            final id = methodCall.arguments['id'] as String;
            return savedWidgetData[id];
          } else if (methodCall.method == 'updateWidget') {
            return true;
          }
          return null;
        });
  });

  group('Widget Resilience & Empty Wipe Prevention Tests', () {
    test(
      'WidgetDataService does not overwrite today_agenda_data when agenda is empty but previously populated',
      () async {
        final mockCalendarService = MockCalendarService();
        when(
          () => mockCalendarService.getEvents(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            calendarIds: any(named: 'calendarIds'),
          ),
        ).thenAnswer((_) async => []);

        final service = WidgetDataService(mockCalendarService);

        // Pre-populate with previous data
        savedWidgetData['today_agenda_data'] = jsonEncode([
          {'id': '1', 'title': 'Important Task', 'date': '2026-09-11'},
        ]);

        // Trigger update with empty tasks and empty events (transient failure / idle)
        await service.updateTodayAgendaWidget([], (id) => null);

        // Verify that existing data was NOT overwritten with '[]'
        final storedData = savedWidgetData['today_agenda_data'] as String;
        expect(storedData, contains('Important Task'));
        expect(storedData, isNot(equals('[]')));
      },
    );

    test(
      'WidgetDataService does not overwrite kanban_data when tasks are empty but previously populated',
      () async {
        final mockCalendarService = MockCalendarService();
        final service = WidgetDataService(mockCalendarService);

        // Pre-populate with previous kanban data
        savedWidgetData['kanban_data'] = jsonEncode({
          'column_todo': [
            {'id': '1', 'title': 'Task 1'},
          ],
          'column_infocus': [],
          'column_done': [],
        });

        // Trigger update with empty tasks (e.g. Hive box lock contention during idle)
        await service.updateKanbanWidget([], (id) => null);

        // Verify that existing data was NOT overwritten with '{}'
        final storedData = savedWidgetData['kanban_data'] as String;
        expect(storedData, contains('Task 1'));
        expect(storedData, isNot(equals('{}')));
      },
    );

    test(
      'TaskWidgetService does not overwrite pending_tasks_list when allTasks is empty and previous tasks exist',
      () async {
        // Pre-populate with previous tasks
        savedWidgetData['pending_tasks_list'] = jsonEncode([
          {'id': '1', 'title': 'Existing Task'},
        ]);

        // Call updateTaskWidget with empty list
        await TaskWidgetService.updateTaskWidget([], (id) => null);

        // Verify that pending_tasks_list is still preserved
        final storedData = savedWidgetData['pending_tasks_list'] as String;
        expect(storedData, contains('Existing Task'));
        expect(storedData, isNot(equals('[]')));
      },
    );

    test(
      'FullCalendarWidgetService preserves existing full_calendar_grid_data on empty summaries',
      () async {
        final mockCalendar = MockCalendarService();
        final mockTaskSource = MockLocalTaskSource();

        when(
          () => mockCalendar.getEvents(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            calendarIds: any(named: 'calendarIds'),
          ),
        ).thenAnswer((_) async => []);

        when(mockTaskSource.getTasks).thenReturn([]);
        when(mockTaskSource.getCategories).thenReturn([]);

        final fullCalendar = FullCalendarWidgetService(
          mockCalendar,
          mockTaskSource,
        );

        // Pre-populate grid data with 1 summary
        final initialGrid = [
          {
            'isWeekNumber': false,
            'date': '2026-09-11',
            'day': 11,
            'summaries': [
              {'text': 'Meeting', 'type': 'google'},
            ],
          },
        ];
        savedWidgetData['full_calendar_grid_data'] = jsonEncode(initialGrid);

        // Run update
        await fullCalendar.updateFullCalendarWidget();

        // Ensure that existing grid with summaries was NOT replaced by an empty grid
        final storedData = savedWidgetData['full_calendar_grid_data'] as String;
        expect(storedData, contains('Meeting'));
      },
    );

    test(
      'CalendarService restores cached events when live query produces 0 events',
      () async {
        // Pre-seed cached_calendar_events_v2 in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final seededEvents = [
          {
            'calendarId': 'google_1',
            'eventId': 'event_1',
            'title': 'Offline Doctor Appointment',
            'description': 'Checkup',
            'start': '2026-09-11T10:00:00.000',
            'end': '2026-09-11T11:00:00.000',
            'allDay': false,
          },
        ];
        await prefs.setString(
          'cached_calendar_events_v2',
          jsonEncode(seededEvents),
        );

        final calendarService = CalendarService();

        // Query events for the range (device_calendar will return empty in unit test environment)
        final events = await calendarService.getEvents(
          startDate: DateTime(2026, 9, 11, 0, 0),
          endDate: DateTime(2026, 9, 11, 23, 59),
        );

        // Verify that offline cached events were recovered
        expect(events, isNotEmpty);
        expect(events.first.title, equals('Offline Doctor Appointment'));
      },
    );
  });
}
