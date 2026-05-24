import 'package:flutter/foundation.dart' hide Category;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

class LocalTaskSource {
  static const String boxName = 'tasksBox';
  static const String categoriesBoxName = 'categoriesBox';

  String _tasksBoxName = boxName;
  String _categoriesBoxName = categoriesBoxName;

  Box<Category> get _categoriesBox => Hive.box<Category>(_categoriesBoxName);

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskPriorityAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryAdapter());

    // Open boxes normally (unencrypted).
    await _openBoxes();
  }

  Future<void> _openBoxes() async {
    try {
      await Hive.openBox<Task>(_tasksBoxName);
      await Hive.openBox<Category>(_categoriesBoxName);
    } catch (e) {
      AppLogger.warning(
        'Failed to open Hive boxes, attempting recovery...',
        tag: 'LocalTaskSource',
      );
      _tasksBoxName = '${boxName}_recovered';
      _categoriesBoxName = '${categoriesBoxName}_recovered';
      await Hive.openBox<Task>(_tasksBoxName);
      await Hive.openBox<Category>(_categoriesBoxName);
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
  }

  Future<void> updateCategory(Category category) async {
    await category.save();
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesBox.delete(id);
  }
}
