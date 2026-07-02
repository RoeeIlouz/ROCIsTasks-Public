import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/conflict_resolution_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';

void main() {
  group('ConflictResolutionService', () {
    group('resolveTaskConflict', () {
      test('localWins should return local task', () {
        final local = Task(id: '1', title: 'Local');
        final remote = Task(id: '1', title: 'Remote');
        final result = ConflictResolutionService.resolveTaskConflict(
          local,
          remote,
          strategy: ConflictStrategy.localWins,
        );
        expect(result.title, 'Local');
      });

      test('remoteWins should return remote task', () {
        final local = Task(id: '1', title: 'Local');
        final remote = Task(id: '1', title: 'Remote');
        final result = ConflictResolutionService.resolveTaskConflict(
          local,
          remote,
          strategy: ConflictStrategy.remoteWins,
        );
        expect(result.title, 'Remote');
      });

      test('lastWriteWins prefers completed task', () {
        final local = Task(id: '1', title: 'T', isCompleted: true);
        final remote = Task(id: '1', title: 'T', isCompleted: false);
        final result = ConflictResolutionService.resolveTaskConflict(
          local,
          remote,
          strategy: ConflictStrategy.lastWriteWins,
        );
        expect(result.isCompleted, true);
      });

      test('lastWriteWins prefers remote completed over local', () {
        final local = Task(id: '1', title: 'T', isCompleted: false);
        final remote = Task(id: '1', title: 'T', isCompleted: true);
        final result = ConflictResolutionService.resolveTaskConflict(
          local,
          remote,
          strategy: ConflictStrategy.lastWriteWins,
        );
        expect(result.isCompleted, true);
      });

      test('lastWriteWins defaults to local when both same completion', () {
        final local = Task(id: '1', title: 'Local');
        final remote = Task(id: '1', title: 'Remote');
        final result = ConflictResolutionService.resolveTaskConflict(
          local,
          remote,
          strategy: ConflictStrategy.lastWriteWins,
        );
        expect(result.title, 'Local');
      });

      test('merge prefers longer title', () {
        final local = Task(id: '1', title: 'Short');
        final remote = Task(id: '1', title: 'A much longer title');
        final result = ConflictResolutionService.resolveTaskConflict(
          local,
          remote,
          strategy: ConflictStrategy.merge,
        );
        expect(result.title, 'A much longer title');
      });

      test('merge prefers completed if either is completed', () {
        final local = Task(id: '1', title: 'T', isCompleted: true);
        final remote = Task(id: '1', title: 'T', isCompleted: false);
        final result = ConflictResolutionService.resolveTaskConflict(
          local,
          remote,
          strategy: ConflictStrategy.merge,
        );
        expect(result.isCompleted, true);
      });

      test('merge prefers higher priority', () {
        final local = Task(id: '1', title: 'T', priority: TaskPriority.low);
        final remote = Task(id: '1', title: 'T', priority: TaskPriority.high);
        final result = ConflictResolutionService.resolveTaskConflict(
          local,
          remote,
          strategy: ConflictStrategy.merge,
        );
        expect(result.priority, TaskPriority.high);
      });

      test('merge prefers non-null categoryId', () {
        final local = Task(id: '1', title: 'T', categoryId: null);
        final remote = Task(id: '1', title: 'T', categoryId: 'cat-1');
        final result = ConflictResolutionService.resolveTaskConflict(
          local,
          remote,
          strategy: ConflictStrategy.merge,
        );
        expect(result.categoryId, 'cat-1');
      });
    });

    group('resolveCategoryConflict', () {
      test('localWins should return local', () {
        final local = Category(
          id: 'c1',
          name: 'Local',
          colorValue: 0,
          iconCode: 0,
        );
        final remote = Category(
          id: 'c1',
          name: 'Remote',
          colorValue: 0,
          iconCode: 0,
        );
        final result = ConflictResolutionService.resolveCategoryConflict(
          local,
          remote,
          strategy: ConflictStrategy.localWins,
        );
        expect(result.name, 'Local');
      });

      test('remoteWins should return remote', () {
        final local = Category(
          id: 'c1',
          name: 'Local',
          colorValue: 0,
          iconCode: 0,
        );
        final remote = Category(
          id: 'c1',
          name: 'Remote',
          colorValue: 0,
          iconCode: 0,
        );
        final result = ConflictResolutionService.resolveCategoryConflict(
          local,
          remote,
          strategy: ConflictStrategy.remoteWins,
        );
        expect(result.name, 'Remote');
      });

      test('merge prefers non-empty name', () {
        final local = Category(id: 'c1', name: '', colorValue: 0, iconCode: 0);
        final remote = Category(
          id: 'c1',
          name: 'Work',
          colorValue: 0,
          iconCode: 0,
        );
        final result = ConflictResolutionService.resolveCategoryConflict(
          local,
          remote,
          strategy: ConflictStrategy.merge,
        );
        expect(result.name, 'Work');
      });
    });

    group('hasTaskConflict', () {
      test('should detect title conflict', () {
        final t1 = Task(id: '1', title: 'A');
        final t2 = Task(id: '1', title: 'B');
        expect(ConflictResolutionService.hasTaskConflict(t1, t2), true);
      });

      test('should detect completion conflict', () {
        final t1 = Task(id: '1', title: 'A', isCompleted: true);
        final t2 = Task(id: '1', title: 'A', isCompleted: false);
        expect(ConflictResolutionService.hasTaskConflict(t1, t2), true);
      });

      test('should return false for identical tasks', () {
        final t1 = Task(id: '1', title: 'Same');
        final t2 = Task(id: '1', title: 'Same');
        expect(ConflictResolutionService.hasTaskConflict(t1, t2), false);
      });

      test('should return false for different IDs', () {
        final t1 = Task(id: '1', title: 'A');
        final t2 = Task(id: '2', title: 'A');
        expect(ConflictResolutionService.hasTaskConflict(t1, t2), false);
      });
    });

    group('hasCategoryConflict', () {
      test('should detect name conflict', () {
        final c1 = Category(id: '1', name: 'A', colorValue: 0, iconCode: 0);
        final c2 = Category(id: '1', name: 'B', colorValue: 0, iconCode: 0);
        expect(ConflictResolutionService.hasCategoryConflict(c1, c2), true);
      });

      test('should return false for identical categories', () {
        final c1 = Category(id: '1', name: 'X', colorValue: 1, iconCode: 2);
        final c2 = Category(id: '1', name: 'X', colorValue: 1, iconCode: 2);
        expect(ConflictResolutionService.hasCategoryConflict(c1, c2), false);
      });

      test('should return false for different IDs', () {
        final c1 = Category(id: '1', name: 'A', colorValue: 0, iconCode: 0);
        final c2 = Category(id: '2', name: 'A', colorValue: 0, iconCode: 0);
        expect(ConflictResolutionService.hasCategoryConflict(c1, c2), false);
      });
    });

    group('getConflictSummary', () {
      test('should generate task summary', () {
        final t1 = Task(id: '1', title: 'A', isCompleted: true);
        final t2 = Task(id: '1', title: 'B', isCompleted: false);
        final summary = ConflictResolutionService.getConflictSummary(t1, t2);
        expect(summary['type'], 'task');
        expect(summary['id'], '1');
        expect(summary['conflicts']['title'], true);
        expect(summary['conflicts']['isCompleted'], true);
      });

      test('should generate category summary', () {
        final c1 = Category(
          id: 'c1',
          name: 'A',
          colorValue: 1,
          iconCode: 2,
        );
        final c2 = Category(
          id: 'c1',
          name: 'B',
          colorValue: 3,
          iconCode: 4,
        );
        final summary = ConflictResolutionService.getConflictSummary(c1, c2);
        expect(summary['type'], 'category');
        expect(summary['conflicts']['name'], true);
      });

      test('should return unknown for unsupported types', () {
        final summary = ConflictResolutionService.getConflictSummary(
          'not a task',
          'not a category',
        );
        expect(summary['type'], 'unknown');
      });
    });
  });
}
