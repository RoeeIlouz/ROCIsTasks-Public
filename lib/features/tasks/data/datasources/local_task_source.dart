import 'package:flutter/foundation.dart' hide Category;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

class LocalTaskSource {
  static const String boxName = 'tasksBox';
  static const String categoriesBoxName = 'categoriesBox';

  Box<Category> get _categoriesBox => Hive.box<Category>(categoriesBoxName);

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
      await Hive.openBox<Task>(boxName);
      await Hive.openBox<Category>(categoriesBoxName);
    } catch (e) {
      // If opening fails (e.g. corrupted file or unexpected encryption), clear and restart
      AppLogger.warning(
        'Failed to open Hive boxes, clearing and restarting...',
        tag: 'LocalTaskSource',
      );
      await Hive.deleteBoxFromDisk(boxName);
      await Hive.deleteBoxFromDisk(categoriesBoxName);
      await Hive.openBox<Task>(boxName);
      await Hive.openBox<Category>(categoriesBoxName);
    }
  }

  Box<Task> get _box => Hive.box<Task>(boxName);

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
