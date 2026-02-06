import 'package:flutter/foundation.dart' hide Category;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/encryption_service.dart';
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

    // We no longer use Hive encryption per user request.
    // However, we need to handle existing encrypted data.
    await _openBoxes();
  }

  Future<void> _performMigration() async {
    // Starting encryption migration...
    try {
      // 1. Open Unencrypted
      final tempTaskBox = await Hive.openBox<Task>(boxName);
      final tempCatBox = await Hive.openBox<Category>(categoriesBoxName);

      final tasks = tempTaskBox.values.toList();
      final categories = tempCatBox.values.toList();

      await tempTaskBox.close();
      await tempCatBox.close();

      // 2. Generate Key (this marks "isEncrypted" as true effectively)
      final key = await EncryptionService.getOrGenerateKey();

      // 3. Delete old boxes (safe because we have data in memory)
      await Hive.deleteBoxFromDisk(boxName);
      await Hive.deleteBoxFromDisk(categoriesBoxName);

      // 4. Open Encrypted
      final encryptedTaskBox = await Hive.openBox<Task>(
        boxName,
        encryptionCipher: HiveAesCipher(key),
      );
      final encryptedCatBox = await Hive.openBox<Category>(
        categoriesBoxName,
        encryptionCipher: HiveAesCipher(key),
      );

      // 5. Write Data Back
      // IMPORTANT: We must create NEW instances, because the old ones are bound to the closed box.
      try {
        for (var task in tasks) {
          // Task has copyWith, which creates a new instance with the same ID
          final newTask = task.copyWith();
          await encryptedTaskBox.put(newTask.id, newTask);
        }

        for (var cat in categories) {
          // Category might not have copyWith, manually create new instance
          final newCat = Category(
            id: cat.id,
            name: cat.name,
            colorValue: cat.colorValue,
            iconCode: cat.iconCode,
          );
          await encryptedCatBox.put(newCat.id, newCat);
        }
      } catch (e) {
        // Error writing encrypted data
        rethrow;
      }

      // Migration completed successfully.
    } catch (e) {
      // Migration failed
      // If failed, we might be in a mixed state.
      // But since we didn't delete until we had data, we might just crash here
      // and on next run try again or need manual intervention.
      rethrow;
    }
  }

  Future<void> _openBoxes() async {
    try {
      // Attempt to open boxes normally (unencrypted)
      await Hive.openBox<Task>(boxName);
      await Hive.openBox<Category>(categoriesBoxName);
    } catch (e) {
      // If opening fails, it might be because the boxes are encrypted.
      // We attempt to migrate them to unencrypted boxes.
      AppLogger.warning(
        'Failed to open Hive boxes normally, attempting migration...',
        tag: 'LocalTaskSource',
      );
      try {
        await _performMigration();
      } catch (migrationError) {
        AppLogger.critical(
          'Migration failed, clearing boxes to allow app to start',
          error: migrationError,
          tag: 'LocalTaskSource',
        );
        // If migration fails, we must clear the boxes to allow the app to function.
        await Hive.deleteBoxFromDisk(boxName);
        await Hive.deleteBoxFromDisk(categoriesBoxName);
        await Hive.openBox<Task>(boxName);
        await Hive.openBox<Category>(categoriesBoxName);
      }
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
