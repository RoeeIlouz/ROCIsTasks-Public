import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/engagement_service.dart';
import 'package:rocis_tasks/core/services/widget_category_colors.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';

Task _done(DateTime at, {bool deleted = false}) =>
    Task(title: 'x', isCompleted: true, completedAt: at, isDeleted: deleted);

void main() {
  final now = DateTime(2026, 10, 20, 15);

  group('EngagementService.streak', () {
    test('counts consecutive days ending today', () {
      final tasks = [
        _done(DateTime(2026, 10, 20, 9)),
        _done(DateTime(2026, 10, 19, 22)),
        _done(DateTime(2026, 10, 18, 8)),
        _done(DateTime(2026, 10, 16, 8)), // gap on the 17th
      ];
      expect(EngagementService.streak(tasks, now), 3);
    });

    test('keeps yesterday\'s streak alive before anything is done today', () {
      final tasks = [
        _done(DateTime(2026, 10, 19, 9)),
        _done(DateTime(2026, 10, 18, 9)),
      ];
      expect(EngagementService.streak(tasks, now), 2);
    });

    test('ignores open and deleted tasks', () {
      final tasks = [
        Task(title: 'open'),
        _done(DateTime(2026, 10, 20, 9), deleted: true),
      ];
      expect(EngagementService.streak(tasks, now), 0);
    });

    test('crosses a month boundary', () {
      final tasks = [
        _done(DateTime(2026, 11, 1, 9)),
        _done(DateTime(2026, 10, 31, 9)),
      ];
      expect(EngagementService.streak(tasks, DateTime(2026, 11, 1, 20)), 2);
    });
  });

  test('completedThisWeek counts the last 7 days', () {
    final tasks = [
      _done(DateTime(2026, 10, 20, 9)),
      _done(DateTime(2026, 10, 14, 0, 1)),
      _done(DateTime(2026, 10, 13, 23)),
    ];
    expect(EngagementService.completedThisWeek(tasks, now), 2);
  });

  group('widgetCategoryColors', () {
    final work = Category(name: 'Work', colorValue: 0xFF3B82F6, iconCode: 0);
    final health = Category(
      name: 'Health',
      colorValue: 0xFF10B981,
      iconCode: 0,
    );
    Category? lookup(String? id) => {work.id: work, health.id: health}[id];

    test('lists every known category color in order', () {
      final task = Task(title: 't', categoryIds: [health.id, 'gone', work.id]);
      expect(widgetCategoryColors(task, lookup), ['#ff10b981', '#ff3b82f6']);
    });

    test('falls back to the legacy single categoryId', () {
      final task = Task(title: 't', categoryId: work.id);
      expect(widgetCategoryColors(task, lookup), ['#ff3b82f6']);
    });
  });
}
