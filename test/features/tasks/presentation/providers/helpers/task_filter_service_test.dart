import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/helpers/task_filter_service.dart';

void main() {
  group('TaskFilterService Tests', () {
    late TaskFilterService filterService;
    late List<Task> sampleTasks;
    late List<Category> sampleCategories;

    setUp(() {
      filterService = TaskFilterService();

      sampleCategories = [
        Category(
          id: 'cat_work',
          name: 'Work',
          colorValue: 0xFF0000FF,
          iconCode: 1,
        ),
        Category(
          id: 'cat_personal',
          name: 'Personal',
          colorValue: 0xFF00FF00,
          iconCode: 2,
          isPrivate: true,
        ),
      ];

      sampleTasks = [
        Task(
          id: 'task_1',
          title: 'Buy Milk',
          description: 'From corner store',
          priority: TaskPriority.low,
          categoryId: 'cat_personal',
          dueDate: DateTime.now().add(const Duration(hours: 2)),
          subTasks: [SubTask(id: 'st_1', title: 'Whole milk')],
        ),
        Task(
          id: 'task_2',
          title: 'Prepare Presentation',
          description: 'Q3 strategy slides',
          priority: TaskPriority.high,
          categoryId: 'cat_work',
          dueDate: DateTime.now().add(const Duration(days: 1)),
        ),
        Task(
          id: 'task_3',
          title: 'Tax Filing',
          description: 'Annual returns',
          priority: TaskPriority.medium,
          isCompleted: true,
          completedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
    });

    Category? mockGetCategoryById(String? id) {
      if (id == null) return null;
      try {
        return sampleCategories.firstWhere((c) => c.id == id);
      } catch (_) {
        return null;
      }
    }

    bool mockIsPrivateTask(Task task) {
      final cat = mockGetCategoryById(task.categoryId);
      return cat?.isPrivate ?? false;
    }

    test('Filter by free text matches title and description', () {
      filterService.setSearchQuery('Milk');
      final result = filterService.filterAndSortTasks(
        allTasks: sampleTasks,
        getCategoryById: mockGetCategoryById,
        isPrivateTask: mockIsPrivateTask,
        shouldMaskPrivateContent: false,
      );
      expect(result.length, equals(1));
      expect(result.first.id, equals('task_1'));
    });

    test('Symbol search parsing: @category filter', () {
      filterService.setSearchQuery('@Work');
      final result = filterService.filterAndSortTasks(
        allTasks: sampleTasks,
        getCategoryById: mockGetCategoryById,
        isPrivateTask: mockIsPrivateTask,
        shouldMaskPrivateContent: false,
      );
      expect(result.length, equals(1));
      expect(result.first.id, equals('task_2'));
    });

    test('Symbol search parsing: !priority filter', () {
      filterService.setSearchQuery('!high');
      final result = filterService.filterAndSortTasks(
        allTasks: sampleTasks,
        getCategoryById: mockGetCategoryById,
        isPrivateTask: mockIsPrivateTask,
        shouldMaskPrivateContent: false,
      );
      expect(result.length, equals(1));
      expect(result.first.id, equals('task_2'));
    });

    test('Symbol search parsing: &subtask filter', () {
      filterService.setSearchQuery('&Whole');
      final result = filterService.filterAndSortTasks(
        allTasks: sampleTasks,
        getCategoryById: mockGetCategoryById,
        isPrivateTask: mockIsPrivateTask,
        shouldMaskPrivateContent: false,
      );
      expect(result.length, equals(1));
      expect(result.first.id, equals('task_1'));
    });

    test('Symbol search parsing: *status filter (done vs pending)', () {
      filterService.setSearchQuery('*done');
      final result = filterService.filterAndSortTasks(
        allTasks: sampleTasks,
        getCategoryById: mockGetCategoryById,
        isPrivateTask: mockIsPrivateTask,
        shouldMaskPrivateContent: false,
      );
      expect(result.length, equals(1));
      expect(result.first.id, equals('task_3'));
    });

    test(
      'Sorting by dueDateTime sorts intraday tasks in exact chronological order',
      () {
        final now = DateTime.now();
        final baseDate = DateTime(now.year, now.month, now.day);
        final sameDayTasks = [
          Task(
            id: 'task_late',
            title: 'Late Task',
            priority: TaskPriority.high,
            dueDate: baseDate.add(const Duration(hours: 18)),
          ),
          Task(
            id: 'task_early',
            title: 'Early Task',
            priority: TaskPriority.low,
            dueDate: baseDate.add(const Duration(hours: 9)),
          ),
          Task(
            id: 'task_mid',
            title: 'Midday Task',
            priority: TaskPriority.medium,
            dueDate: baseDate.add(const Duration(hours: 13)),
          ),
        ];

        filterService.currentSortOption = TaskSortOption.dueDateTime;
        final result = filterService.filterAndSortTasks(
          allTasks: sameDayTasks,
          getCategoryById: mockGetCategoryById,
          isPrivateTask: mockIsPrivateTask,
          shouldMaskPrivateContent: false,
        );

        expect(
          result.map((t) => t.id).toList(),
          equals(['task_early', 'task_mid', 'task_late']),
        );
      },
    );
  });
}
