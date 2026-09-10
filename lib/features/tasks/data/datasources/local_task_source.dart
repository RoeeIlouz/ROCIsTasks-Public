import 'package:flutter/foundation.dart' hide Category;
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

class LocalTaskSource {
  static const String boxName = 'tasksBox';
  static const String categoriesBoxName = 'categoriesBox';
  static const String _keyCachedCategories = 'cached_categories_list';

  String _tasksBoxName = boxName;
  String _categoriesBoxName = categoriesBoxName;

  Box<Category> get _categoriesBox => Hive.box<Category>(_categoriesBoxName);

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskPriorityAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SubTaskAdapter());
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(CustomFieldTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(TaskCustomFieldAdapter());
    }

    // Open boxes normally (unencrypted).
    await _openBoxes();
  }

  Future<void> _openBoxes() async {
    try {
      if (!Hive.isBoxOpen(_tasksBoxName)) {
        await Hive.openBox<Task>(_tasksBoxName);
      }
      if (!Hive.isBoxOpen(_categoriesBoxName)) {
        await Hive.openBox<Category>(_categoriesBoxName);
      }
      // Proactively keep categories snapshot up to date for background isolates
      unawaited(_cacheCategoriesSnapshot());
    } catch (e) {
      AppLogger.warning(
        'Failed to open Hive boxes, attempting recovery...',
        tag: 'LocalTaskSource',
      );
      _tasksBoxName = '${boxName}_recovered';
      _categoriesBoxName = '${categoriesBoxName}_recovered';
      if (!Hive.isBoxOpen(_tasksBoxName)) {
        await Hive.openBox<Task>(_tasksBoxName);
      }
      if (!Hive.isBoxOpen(_categoriesBoxName)) {
        await Hive.openBox<Category>(_categoriesBoxName);
      }
      // Populate recovered boxes from SharedPreferences fallback cache
      await _populateRecoveredBoxesFromCache();
    }
  }

  Future<void> _cacheCategoriesSnapshot() async {
    try {
      if (_categoriesBox.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final list = _categoriesBox.values.map((c) => c.toMap()).toList();
        await prefs.setString(_keyCachedCategories, jsonEncode(list));
      }
    } catch (_) {}
  }

  Future<void> _populateRecoveredBoxesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Recover Categories
      final catJson = prefs.getString(_keyCachedCategories);
      if (catJson != null && catJson.isNotEmpty && _categoriesBox.isEmpty) {
        final list = jsonDecode(catJson) as List<dynamic>;
        for (final item in list) {
          final cat = Category.fromMap(item as Map<String, dynamic>);
          await _categoriesBox.put(cat.id, cat);
        }
        AppLogger.info(
          'Recovered ${_categoriesBox.length} categories from cache into recovered box',
          tag: 'LocalTaskSource',
        );
      }

      // 2. Recover Tasks
      final tasksJson = prefs.getString('pending_tasks_list');
      if (tasksJson != null &&
          tasksJson.isNotEmpty &&
          tasksJson != '[]' &&
          _box.isEmpty) {
        final list = jsonDecode(tasksJson) as List<dynamic>;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final priorityStr = map['priority'] as String? ?? 'medium';
          final priority = TaskPriority.values.firstWhere(
            (p) => p.name == priorityStr,
            orElse: () => TaskPriority.medium,
          );
          DateTime? dueDate;
          final iso = map['dueDateIso'] as String?;
          if (iso != null && iso.isNotEmpty) {
            dueDate = DateTime.tryParse(iso);
          } else {
            final dateStr = map['dueDate'] as String?;
            if (dateStr != null && dateStr.isNotEmpty) {
              dueDate = DateTime.tryParse(dateStr);
            }
          }
          final task = Task(
            id: map['id'] as String? ?? '',
            title: map['title'] as String? ?? '',
            priority: priority,
            dueDate: dueDate,
            categoryId: map['categoryId'] as String?,
            isCompleted: map['isCompleted'] == true,
            isPinned: map['isPinned'] == true,
          );
          await _box.put(task.id, task);
        }
        AppLogger.info(
          'Recovered ${_box.length} tasks from cache into recovered box',
          tag: 'LocalTaskSource',
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to populate recovered boxes from cache: $e',
        tag: 'LocalTaskSource',
      );
    }
  }

  Box<Task> get _box => Hive.box<Task>(_tasksBoxName);

  List<Task> getTasks() {
    return _box.values.toList();
  }

  ValueListenable<Box<Task>> listenToTasks() {
    return _box.listenable();
  }

  Future<void> addTask(Task task) async {
    await _box.put(task.id, task);
  }

  Future<void> updateTask(Task task) async {
    await task.save();
  }

  Future<void> deleteTask(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _categoriesBox.clear();
  }

  // Category Methods
  List<Category> getCategories() {
    return _categoriesBox.values.toList();
  }

  Future<void> addCategory(Category category) async {
    await _categoriesBox.put(category.id, category);
    unawaited(_cacheCategoriesSnapshot());
  }

  Future<void> updateCategory(Category category) async {
    await category.save();
    unawaited(_cacheCategoriesSnapshot());
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesBox.delete(id);
    unawaited(_cacheCategoriesSnapshot());
  }

  /// Safely compacts Hive boxes to reduce disk usage and eliminate fragmented tombstones.
  Future<void> compactBoxes() async {
    try {
      if (Hive.isBoxOpen(_tasksBoxName)) {
        await _box.compact();
      }
      if (Hive.isBoxOpen(_categoriesBoxName)) {
        await _categoriesBox.compact();
      }
      AppLogger.info(
        'Hive boxes compacted successfully.',
        tag: 'LocalTaskSource',
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to compact Hive boxes: $e',
        tag: 'LocalTaskSource',
      );
    }
  }
}
