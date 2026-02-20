import 'dart:convert';
import 'package:rocis_tasks/features/tasks/data/datasources/local_task_source.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

class BackupService {
  final LocalTaskSource _localSource = LocalTaskSource();

  /// Export all local tasks and categories to a JSON string
  Future<String> exportData() async {
    try {
      final tasks = _localSource.getTasks();
      final categories = _localSource.getCategories();

      final data = {
        'version': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
      };

      return jsonEncode(data);
    } catch (e, s) {
      AppLogger.error('Export failed', error: e, stack: s, tag: 'Backup');
      rethrow;
    }
  }

  /// Import tasks and categories from a JSON string
  Future<void> importData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Basic version check
      final version = data['version'] as int?;
      if (version == null) throw Exception('Invalid backup format');

      final tasksData = data['tasks'] as List?;
      final categoriesData = data['categories'] as List?;

      // Import Categories first to ensure foreign keys (categoryId) are valid
      if (categoriesData != null) {
        for (var catMap in categoriesData) {
          final cat = Category.fromMap(catMap as Map<String, dynamic>);
          await _localSource.addCategory(cat);
        }
      }

      if (tasksData != null) {
        for (var taskMap in tasksData) {
          final task = Task.fromMap(taskMap as Map<String, dynamic>);
          await _localSource.addTask(task);
        }
      }

      AppLogger.info('Backup imported successfully', tag: 'Backup');
    } catch (e, s) {
      AppLogger.error('Import failed', error: e, stack: s, tag: 'Backup');
      rethrow;
    }
  }
}
