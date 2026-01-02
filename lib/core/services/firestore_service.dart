import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/encryption_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  void setUserId(String? userId) {
    _userId = userId;
  }

  CollectionReference<Map<String, dynamic>>? get _tasksCollection {
    if (_userId == null) return null;
    return _firestore.collection('users').doc(_userId).collection('tasks');
  }

  CollectionReference<Map<String, dynamic>>? get _categoriesCollection {
    if (_userId == null) return null;
    return _firestore.collection('users').doc(_userId).collection('categories');
  }

  Future<void> addCategory(Category category) async {
    final collection = _categoriesCollection;
    if (collection == null) return;

    try {
      await collection.doc(category.id).set({
        'id': category.id,
        'name': category.name,
        'colorValue': category.colorValue,
        'iconCode': category.iconCode,
      });
    } catch (e) {
      debugPrint('Error adding category to Firestore: $e');
    }
  }

  Future<void> updateCategory(Category category) async {
    final collection = _categoriesCollection;
    if (collection == null) return;

    try {
      await collection.doc(category.id).update({
        'name': category.name,
        'colorValue': category.colorValue,
        'iconCode': category.iconCode,
      });
    } catch (e) {
      debugPrint('Error updating category in Firestore: $e');
    }
  }

  Future<void> deleteCategory(String id) async {
    final collection = _categoriesCollection;
    if (collection == null) return;

    try {
      await collection.doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting category from Firestore: $e');
    }
  }

  Stream<List<Category>> getCategoriesStream() {
    final collection = _categoriesCollection;
    if (collection == null) return const Stream.empty();

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Category(
          id: data['id'],
          name: data['name'],
          colorValue: data['colorValue'],
          iconCode: data['iconCode'],
        );
      }).toList();
    });
  }

  Future<void> addTask(Task task) async {
    final collection = _tasksCollection;
    if (collection == null) return;

    try {
      await collection.doc(task.id).set({
        'id': task.id,
        'title': EncryptionService.encrypt(task.title),
        'description': EncryptionService.encrypt(task.description),
        'isCompleted': task.isCompleted,
        'dueDate': task.dueDate?.toIso8601String(),
        'priority': task.priority.index,
        'categoryId': task.categoryId,
        'isDeleted': task.isDeleted ?? false,
        'isPinned': task.isPinned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding task to Firestore: $e');
    }
  }

  Future<void> updateTask(Task task) async {
    final collection = _tasksCollection;
    if (collection == null) return;

    try {
      await collection.doc(task.id).update({
        'title': EncryptionService.encrypt(task.title),
        'description': EncryptionService.encrypt(task.description),
        'isCompleted': task.isCompleted,
        'dueDate': task.dueDate?.toIso8601String(),
        'priority': task.priority.index,
        'categoryId': task.categoryId,
        'isDeleted': task.isDeleted ?? false,
        'isPinned': task.isPinned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating task in Firestore: $e');
    }
  }

  Future<void> deleteTask(String id) async {
    final collection = _tasksCollection;
    if (collection == null) return;

    try {
      await collection.doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting task from Firestore: $e');
    }
  }

  Stream<List<Task>> getTasksStream() {
    final collection = _tasksCollection;
    if (collection == null) return const Stream.empty();

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Task(
          id: data['id'],
          title: EncryptionService.decrypt(data['title'] ?? ''),
          description: EncryptionService.decrypt(data['description'] ?? ''),
          isCompleted: data['isCompleted'] ?? false,
          dueDate: data['dueDate'] != null
              ? DateTime.tryParse(data['dueDate'])
              : null,
          priority: TaskPriority.values[data['priority'] ?? 0],
          categoryId: data['categoryId'],
          isDeleted: data['isDeleted'] ?? false,
          isPinned: data['isPinned'] ?? false,
        );
      }).toList();
    });
  }
}
