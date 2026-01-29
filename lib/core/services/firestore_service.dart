import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/encryption_service.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';
import 'package:rocis_tasks/core/services/retry_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityService _connectivityService = ConnectivityService();
  String? _userId;

  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Check if we should attempt Firestore operations
  bool get _shouldSync => _userId != null && _connectivityService.isOnline;

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
    if (collection == null || !_shouldSync) return;

    try {
      await RetryService.retryFirestoreOperation(() async {
        await collection.doc(category.id).set({
          'id': category.id,
          'name': category.name,
          'colorValue': category.colorValue,
          'iconCode': category.iconCode,
        });
      });
    } catch (e) {
      // Log error but don't throw - local data is source of truth
      AppLogger.error('Firestore addCategory failed after retries', error: e, tag: 'Firestore');
    }
  }

  Future<void> updateCategory(Category category) async {
    final collection = _categoriesCollection;
    if (collection == null || !_shouldSync) return;

    try {
      await collection.doc(category.id).update({
        'name': category.name,
        'colorValue': category.colorValue,
        'iconCode': category.iconCode,
      });
    } catch (e) {
      AppLogger.warning('Firestore updateCategory skipped (offline or error)', error: e, tag: 'Firestore');
    }
  }

  Future<void> deleteCategory(String id) async {
    final collection = _categoriesCollection;
    if (collection == null || !_shouldSync) return;

    try {
      await collection.doc(id).delete();
    } catch (e) {
      AppLogger.warning('Firestore deleteCategory skipped (offline or error)', error: e, tag: 'Firestore');
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
    if (collection == null || !_shouldSync) return;

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
      AppLogger.warning('Firestore addTask skipped (offline or error)', error: e, tag: 'Firestore');
    }
  }

  Future<void> updateTask(Task task) async {
    final collection = _tasksCollection;
    if (collection == null || !_shouldSync) return;

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
      AppLogger.warning('Firestore updateTask skipped (offline or error)', error: e, tag: 'Firestore');
    }
  }

  Future<void> deleteTask(String id) async {
    final collection = _tasksCollection;
    if (collection == null || !_shouldSync) return;

    try {
      await collection.doc(id).delete();
    } catch (e) {
      AppLogger.warning('Firestore deleteTask skipped (offline or error)', error: e, tag: 'Firestore');
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
