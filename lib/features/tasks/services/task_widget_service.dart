import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:home_widget/home_widget.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';

/// Service responsible for preparing and updating Task Widget data
class TaskWidgetService {
  /// Standardized task data structure for widget consumption
  static Map<String, dynamic> _serializeTaskForWidget(Task task, Category? category) {
    try {
      return {
        'id': task.id,
        'title': task.title.isNotEmpty ? task.title : 'Untitled Task',
        'priority': task.priority.name,
        'category_color': category != null
            ? _formatColorForWidget(category.colorValue)
            : '',
        'dueDate': task.dueDate != null
            ? _formatDateForDisplay(task.dueDate!)
            : '',
        'dueDateIso': task.dueDate?.toIso8601String() ?? '',
        'isCompleted': task.isCompleted,
      };
    } catch (e) {
      debugPrint('Error serializing task ${task.id} for widget: $e');
      // Return fallback data structure
      return {
        'id': task.id,
        'title': 'Error loading task',
        'priority': 'medium',
        'category_color': '',
        'dueDate': '',
        'dueDateIso': '',
        'isCompleted': false,
      };
    }
  }

  /// Filter tasks to get only pending (incomplete and not deleted) tasks
  static List<Task> filterPendingTasks(List<Task> allTasks) {
    try {
      return allTasks.where((task) {
        return !task.isCompleted && !(task.isDeleted ?? false);
      }).toList();
    } catch (e) {
      debugPrint('Error filtering pending tasks: $e');
      return [];
    }
  }

  /// Sort tasks by due date (tasks with due dates first, then by date)
  static void sortTasksByDueDate(List<Task> tasks) {
    try {
      tasks.sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    } catch (e) {
      debugPrint('Error sorting tasks by due date: $e');
    }
  }

  /// Update Task Widget with current pending tasks data
  static Future<void> updateTaskWidget(
    List<Task> allTasks,
    Category? Function(String?) getCategoryById,
  ) async {
    try {
      debugPrint('TaskWidgetService: Starting widget update');
      
      // Filter to get only pending tasks
      final pendingTasks = filterPendingTasks(allTasks);
      debugPrint('TaskWidgetService: Found ${pendingTasks.length} pending tasks');

      // Sort by due date
      sortTasksByDueDate(pendingTasks);

      // Serialize tasks for widget consumption
      final tasksJson = <Map<String, dynamic>>[];
      for (final task in pendingTasks) {
        try {
          final category = getCategoryById(task.categoryId);
          final serializedTask = _serializeTaskForWidget(task, category);
          tasksJson.add(serializedTask);
        } catch (e) {
          debugPrint('Error processing task ${task.id}: $e');
          // Continue with other tasks instead of failing completely
        }
      }

      // Save widget data with error handling
      try {
        final jsonString = jsonEncode(tasksJson);
        debugPrint('TaskWidgetService: Saving ${tasksJson.length} tasks, payload size: ${jsonString.length}');
        await HomeWidget.saveWidgetData<String>('pending_tasks_list', jsonString);
      } catch (e) {
        debugPrint('Error serializing tasks for widget: $e');
        // Provide fallback empty data to prevent widget crashes
        await HomeWidget.saveWidgetData<String>('pending_tasks_list', '[]');
      }

      // Update the widget
      await HomeWidget.updateWidget(
        name: 'TaskWidgetProvider',
        iOSName: 'TaskWidget',
      );

      debugPrint('TaskWidgetService: Widget update completed successfully');
    } catch (e) {
      debugPrint('TaskWidgetService: Critical error during widget update: $e');
      // Ensure widget has some data even if update fails
      try {
        await HomeWidget.saveWidgetData<String>('pending_tasks_list', '[]');
        await HomeWidget.updateWidget(
          name: 'TaskWidgetProvider',
          iOSName: 'TaskWidget',
        );
      } catch (fallbackError) {
        debugPrint('TaskWidgetService: Fallback update also failed: $fallbackError');
      }
    }
  }

  /// Format color value as hex string with # prefix for consistent parsing
  static String _formatColorForWidget(int colorValue) {
    try {
      return '#${colorValue.toRadixString(16).padLeft(8, '0')}';
    } catch (e) {
      debugPrint('Error formatting color $colorValue: $e');
      return ''; // Return empty string as fallback
    }
  }

  /// Format date for consistent display across widgets (YYYY-MM-DD format)
  static String _formatDateForDisplay(DateTime date) {
    try {
      return '${date.year.toString().padLeft(4, '0')}-'
             '${date.month.toString().padLeft(2, '0')}-'
             '${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('Error formatting date $date: $e');
      return ''; // Return empty string as fallback
    }
  }
}