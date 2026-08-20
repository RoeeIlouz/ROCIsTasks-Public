import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/widget_data_service.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';

class MockCalendarService extends CalendarService {
  @override
  Future<void> init() async {}

  @override
  Future<List<Event>> getEvents({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? calendarIds,
  }) async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  final Map<String, dynamic> savedWidgetData = {};

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'saveWidgetData') {
        final key = methodCall.arguments['id'] as String;
        final data = methodCall.arguments['data'];
        savedWidgetData[key] = data;
        return true;
      } else if (methodCall.method == 'getWidgetData') {
        final key = methodCall.arguments['id'] as String;
        return savedWidgetData[key];
      } else if (methodCall.method == 'updateWidget') {
        return true;
      }
      return null;
    });
  });

  group('WidgetDataService New Widgets Tests', () {
    late WidgetDataService service;
    late MockCalendarService mockCalendar;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockCalendar = MockCalendarService();
      service = WidgetDataService(mockCalendar);
    });

    test('updateTodayAgendaWidget handles empty tasks gracefully', () async {
      await expectLater(
        service.updateTodayAgendaWidget([], (id) => null),
        completes,
      );
      expect(savedWidgetData.containsKey('today_agenda_data'), isTrue);
    });

    test('updateMonthAgendaWidget handles tasks without errors', () async {
      final tasks = [
        Task(
          id: '1',
          title: 'Test Task 1',
          dueDate: DateTime.now(),
          priority: TaskPriority.high,
        ),
      ];

      await expectLater(
        service.updateMonthAgendaWidget(tasks, (id) => null),
        completes,
      );
      expect(savedWidgetData.containsKey('month_agenda_grid_data'), isTrue);
    });

    test('updateTimelineAgendaWidget formats grouped timeline items', () async {
      final tasks = [
        Task(
          id: '1',
          title: 'Today Task',
          dueDate: DateTime.now(),
          priority: TaskPriority.medium,
        ),
        Task(
          id: '2',
          title: 'Tomorrow Task',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          priority: TaskPriority.high,
        ),
      ];

      await expectLater(
        service.updateTimelineAgendaWidget(tasks, (id) => null),
        completes,
      );
      expect(savedWidgetData.containsKey('timeline_agenda_data'), isTrue);
    });

    test('updateQuickActionWidget accurately counts pending & completed tasks', () async {
      final tasks = [
        Task(
          id: '1',
          title: 'Pending Task',
          isCompleted: false,
        ),
        Task(
          id: '2',
          title: 'Completed Task',
          isCompleted: true,
        ),
      ];

      await expectLater(
        service.updateQuickActionWidget(tasks),
        completes,
      );
      expect(savedWidgetData['quick_action_pending_count'], equals(1));
      expect(savedWidgetData['quick_action_completed_count'], equals(1));
    });

    test('updateUpNextWidget picks earliest upcoming task', () async {
      final now = DateTime.now();
      final tasks = [
        Task(
          id: '1',
          title: 'Soon Task',
          categoryId: 'cat1',
          dueDate: now.add(const Duration(hours: 2)),
          isCompleted: false,
        ),
        Task(
          id: '2',
          title: 'Later Task',
          dueDate: now.add(const Duration(days: 2)),
          isCompleted: false,
        ),
      ];

      final category = Category(
        id: 'cat1',
        name: 'Work',
        colorValue: 0xFF4285F4,
        iconCode: 0xe000,
      );

      await expectLater(
        service.updateUpNextWidget(tasks, (id) => id == 'cat1' ? category : null),
        completes,
      );
      expect(savedWidgetData['up_next_title'], equals('Soon Task'));
      expect(savedWidgetData['up_next_subtitle'], equals('Work'));
    });

    test('updateAllWidgets completes all widget sync processes', () async {
      final tasks = [
        Task(
          id: '1',
          title: 'Daily Meeting',
          dueDate: DateTime.now(),
          priority: TaskPriority.high,
        ),
      ];

      await expectLater(
        service.updateAllWidgets(tasks, (id) => null),
        completes,
      );
    });
  });
}
