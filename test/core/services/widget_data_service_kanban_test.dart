import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rocis_tasks/core/services/calendar_service.dart';
import 'package:rocis_tasks/core/services/widget_data_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';

class MockCalendarService extends Mock implements CalendarService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCalendarService mockCalendarService;
  late WidgetDataService widgetDataService;
  final savedWidgetData = <String, dynamic>{};

  setUp(() {
    mockCalendarService = MockCalendarService();
    widgetDataService = WidgetDataService(mockCalendarService);
    savedWidgetData.clear();

    // Mock HomeWidget platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'saveWidgetData') {
          final id = methodCall.arguments['id'] as String;
          final data = methodCall.arguments['data'];
          savedWidgetData[id] = data;
          return true;
        } else if (methodCall.method == 'updateWidget') {
          return true;
        }
        return null;
      },
    );
  });

  final workCategory = Category(
    id: 'cat_work',
    name: 'Work',
    colorValue: 0xFF2196F3,
    iconCode: 0,
  );

  test('updateKanbanWidget separates tasks correctly into To Do, In Focus, and Done', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 14, 0);
    final yesterday = today.subtract(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    final tasks = [
      Task(
        id: 'task_todo',
        title: 'Future Task',
        priority: TaskPriority.low,
        dueDate: nextWeek,
        categoryId: 'cat_work',
      ),
      Task(
        id: 'task_today',
        title: 'Due Today Task',
        priority: TaskPriority.medium,
        dueDate: today,
        categoryId: 'cat_work',
      ),
      Task(
        id: 'task_overdue',
        title: 'Overdue Task',
        priority: TaskPriority.low,
        dueDate: yesterday,
      ),
      Task(
        id: 'task_high_priority',
        title: 'High Priority Future Task',
        priority: TaskPriority.high,
        dueDate: nextWeek,
      ),
      Task(
        id: 'task_done',
        title: 'Completed Task',
        priority: TaskPriority.low,
        isCompleted: true,
      ),
      Task(
        id: 'task_deleted',
        title: 'Deleted Task',
        isDeleted: true,
      ),
    ];

    Category? getCategory(String? id) => id == 'cat_work' ? workCategory : null;

    await widgetDataService.updateKanbanWidget(tasks, getCategory);

    expect(savedWidgetData.containsKey('kanban_data'), isTrue);
    final rawJson = savedWidgetData['kanban_data'] as String;
    final data = jsonDecode(rawJson) as Map<String, dynamic>;

    final todoList = data['column_todo'] as List;
    final inFocusList = data['column_infocus'] as List;
    final doneList = data['column_done'] as List;

    // 1. Future low priority task should be in To Do
    expect(todoList.any((item) => item['id'] == 'task_todo'), isTrue);
    expect(todoList.length, 1);

    // 2. Today, Overdue, and High Priority tasks should be in In Focus
    expect(inFocusList.any((item) => item['id'] == 'task_today'), isTrue);
    expect(inFocusList.any((item) => item['id'] == 'task_overdue'), isTrue);
    expect(inFocusList.any((item) => item['id'] == 'task_high_priority'), isTrue);
    expect(inFocusList.length, 3);

    // 3. Completed task should be in Done
    expect(doneList.any((item) => item['id'] == 'task_done'), isTrue);
    expect(doneList.length, 1);

    // 4. Deleted task should NOT be in any column
    expect(todoList.any((item) => item['id'] == 'task_deleted'), isFalse);
    expect(inFocusList.any((item) => item['id'] == 'task_deleted'), isFalse);
    expect(doneList.any((item) => item['id'] == 'task_deleted'), isFalse);
  });
}
