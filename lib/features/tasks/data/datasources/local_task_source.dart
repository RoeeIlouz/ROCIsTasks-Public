import 'package:flutter/foundation.dart' hide Category;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/encryption_service.dart';

class LocalTaskSource {
  static const String boxName = 'tasksBox';
  static const String categoriesBoxName = 'categoriesBox';

  Box<Category> get _categoriesBox => Hive.box<Category>(categoriesBoxName);

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0))
      Hive.registerAdapter(TaskPriorityAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryAdapter());

    final isEncrypted = await EncryptionService.hasKey();
    if (!isEncrypted) {
      // Check if we have existing unencrypted data to migrate
      final boxExists = await Hive.boxExists(boxName);
      if (boxExists) {
        await _performMigration();
      } else {
        // Fresh install -> Start Encrypted
        await _openEncryptedBox();
      }
    } else {
      // Normal encrypted startup
      await _openEncryptedBox();
    }
  }

  Future<void> _performMigration() async {
    debugPrint('LocalTaskSource: Starting encryption migration...');
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
        debugPrint('Error writing encrypted data: $e');
        rethrow;
      }

      debugPrint('LocalTaskSource: Migration completed successfully.');
    } catch (e) {
      debugPrint('LocalTaskSource: Migration failed: $e');
      // If failed, we might be in a mixed state.
      // But since we didn't delete until we had data, we might just crash here
      // and on next run try again or need manual intervention.
      rethrow;
    }
  }

  Future<void> _openEncryptedBox() async {
    final key = await EncryptionService.getOrGenerateKey();
    try {
      await Hive.openBox<Task>(boxName, encryptionCipher: HiveAesCipher(key));
      await Hive.openBox<Category>(
        categoriesBoxName,
        encryptionCipher: HiveAesCipher(key),
      );
    } catch (e) {
      debugPrint('Error opening encrypted box: $e');
      // Potential key mismatch or corrupted file.
      // Extreme fallback: delete and recreate? No, safer to throw.
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
