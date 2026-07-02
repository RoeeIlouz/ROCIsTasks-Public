import 'package:flutter/foundation.dart' hide Category;
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart'
    as cat;

/// Conflict resolution strategies
enum ConflictStrategy {
  localWins, // Local changes take precedence
  remoteWins, // Remote changes take precedence
  lastWriteWins, // Most recent timestamp wins
  merge, // Attempt to merge changes
  userChoice, // Ask user to resolve
}

/// Service for handling data conflicts during sync
class ConflictResolutionService {
  /// Resolve task conflicts
  static Task resolveTaskConflict(
    Task localTask,
    Task remoteTask, {
    ConflictStrategy strategy = ConflictStrategy.lastWriteWins,
  }) {
    switch (strategy) {
      case ConflictStrategy.localWins:
        return localTask;

      case ConflictStrategy.remoteWins:
        return remoteTask;

      case ConflictStrategy.lastWriteWins:
        // Compare timestamps (assuming we add lastModified field)
        // For now, use a simple heuristic based on completion status
        if (localTask.isCompleted != remoteTask.isCompleted) {
          // Prefer the completed version
          return localTask.isCompleted ? localTask : remoteTask;
        }
        return localTask; // Default to local if no clear winner

      case ConflictStrategy.merge:
        return _mergeTaskChanges(localTask, remoteTask);

      case ConflictStrategy.userChoice:
        // This would trigger a UI dialog in practice
        debugPrint('User choice needed for task conflict: ${localTask.id}');
        return localTask; // Default to local for now
    }
  }

  /// Merge task changes intelligently
  static Task _mergeTaskChanges(Task localTask, Task remoteTask) {
    // Create a merged task with intelligent field selection
    return Task(
      id: localTask.id,
      title: _selectBestValue(
        localTask.title,
        remoteTask.title,
        (a, b) => a.length > b.length, // Prefer longer title
      ),
      description: _selectBestValue(
        localTask.description,
        remoteTask.description,
        (a, b) => a.length > b.length, // Prefer longer description
      ),
      isCompleted:
          localTask.isCompleted || remoteTask.isCompleted, // Prefer completed
      dueDate: _selectBestValue(
        localTask.dueDate,
        remoteTask.dueDate,
        (a, b) => a?.isAfter(b ?? DateTime(1970)) ?? false, // Prefer later date
      ),
      priority: _selectHigherPriority(localTask.priority, remoteTask.priority),
      categoryId:
          localTask.categoryId ?? remoteTask.categoryId, // Prefer non-null
      categoryIds: localTask.categoryIds.isNotEmpty
          ? localTask.categoryIds
          : remoteTask.categoryIds,
      isPinned: localTask.isPinned ?? remoteTask.isPinned ?? false,
      isDeleted: localTask.isDeleted ?? remoteTask.isDeleted ?? false,
      syncWithGoogleTasks:
          localTask.syncWithGoogleTasks || remoteTask.syncWithGoogleTasks,
      googleTaskId: localTask.googleTaskId ?? remoteTask.googleTaskId,
      googleTaskListId:
          localTask.googleTaskListId ?? remoteTask.googleTaskListId,
    );
  }

  /// Select the best value based on a comparison function
  static T _selectBestValue<T>(
    T localValue,
    T remoteValue,
    bool Function(T, T) comparator,
  ) {
    try {
      return comparator(localValue, remoteValue) ? localValue : remoteValue;
    } catch (e) {
      return localValue; // Default to local on error
    }
  }

  /// Select higher priority
  static TaskPriority _selectHigherPriority(
    TaskPriority local,
    TaskPriority remote,
  ) {
    // Higher index = higher priority
    return local.index > remote.index ? local : remote;
  }

  /// Resolve category conflicts
  static cat.Category resolveCategoryConflict(
    cat.Category localCategory,
    cat.Category remoteCategory, {
    ConflictStrategy strategy = ConflictStrategy.lastWriteWins,
  }) {
    switch (strategy) {
      case ConflictStrategy.localWins:
        return localCategory;

      case ConflictStrategy.remoteWins:
        return remoteCategory;

      case ConflictStrategy.lastWriteWins:
      case ConflictStrategy.merge:
        // For categories, merge by preferring non-default values
        return cat.Category(
          id: localCategory.id,
          name: localCategory.name.isNotEmpty
              ? localCategory.name
              : remoteCategory.name,
          colorValue: localCategory.colorValue != 0
              ? localCategory.colorValue
              : remoteCategory.colorValue,
          iconCode: localCategory.iconCode != 0
              ? localCategory.iconCode
              : remoteCategory.iconCode,
        );

      case ConflictStrategy.userChoice:
        debugPrint(
          'User choice needed for category conflict: ${localCategory.id}',
        );
        return localCategory;
    }
  }

  /// Check if two tasks have conflicts
  static bool hasTaskConflict(Task task1, Task task2) {
    return task1.id == task2.id &&
        (task1.title != task2.title ||
            task1.description != task2.description ||
            task1.isCompleted != task2.isCompleted ||
            task1.dueDate != task2.dueDate ||
            task1.priority != task2.priority ||
            task1.categoryId != task2.categoryId ||
            !listEquals(task1.categoryIds, task2.categoryIds) ||
            task1.isPinned != task2.isPinned ||
            task1.isDeleted != task2.isDeleted ||
            task1.syncWithGoogleTasks != task2.syncWithGoogleTasks);
  }

  /// Check if two categories have conflicts
  static bool hasCategoryConflict(cat.Category cat1, cat.Category cat2) {
    return cat1.id == cat2.id &&
        (cat1.name != cat2.name ||
            cat1.colorValue != cat2.colorValue ||
            cat1.iconCode != cat2.iconCode);
  }

  /// Generate conflict summary for logging
  static Map<String, dynamic> getConflictSummary(
    dynamic localItem,
    dynamic remoteItem,
  ) {
    if (localItem is Task && remoteItem is Task) {
      return {
        'type': 'task',
        'id': localItem.id,
        'conflicts': {
          'title': localItem.title != remoteItem.title,
          'description': localItem.description != remoteItem.description,
          'isCompleted': localItem.isCompleted != remoteItem.isCompleted,
          'dueDate': localItem.dueDate != remoteItem.dueDate,
          'priority': localItem.priority != remoteItem.priority,
          'categoryId': localItem.categoryId != remoteItem.categoryId,
          'categoryIds': !listEquals(
            localItem.categoryIds,
            remoteItem.categoryIds,
          ),
          'isPinned': localItem.isPinned != remoteItem.isPinned,
          'isDeleted': localItem.isDeleted != remoteItem.isDeleted,
          'syncWithGoogleTasks':
              localItem.syncWithGoogleTasks != remoteItem.syncWithGoogleTasks,
        },
      };
    } else if (localItem is cat.Category && remoteItem is cat.Category) {
      return {
        'type': 'category',
        'id': localItem.id,
        'conflicts': {
          'name': localItem.name != remoteItem.name,
          'colorValue': localItem.colorValue != remoteItem.colorValue,
          'iconCode': localItem.iconCode != remoteItem.iconCode,
        },
      };
    }

    return {'type': 'unknown', 'error': 'Unsupported item type'};
  }
}
