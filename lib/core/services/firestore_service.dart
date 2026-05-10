import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/retry_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/sync_status_service.dart';
import 'package:firebase_performance/firebase_performance.dart';

enum SyncEventType { added, modified, removed }

class TaskSyncEvent {
  final SyncEventType type;
  final Task task;
  TaskSyncEvent(this.type, this.task);
}

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SyncStatusService _syncStatus = SyncStatusService();
  String? _userId;

  // Throttling for writes
  DateTime _lastWriteTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minWriteInterval = Duration(milliseconds: 500);

  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  void setUserId(String? userId) {
    if (_userId != userId) {
      _userId = userId;
      resetCompletedTasksCursor();
    }
  }

  /// Ensure at least [_minWriteInterval] between write operations
  Future<void> _throttle() async {
    final now = DateTime.now();
    final intervalSinceLastWrite = now.difference(_lastWriteTime);
    if (intervalSinceLastWrite < _minWriteInterval) {
      await Future.delayed(_minWriteInterval - intervalSinceLastWrite);
    }
    _lastWriteTime = DateTime.now();
  }

  /// Check if we should attempt Firestore operations
  bool get _shouldSync => _userId != null;

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

    await _throttle();
    _syncStatus.setSyncing();
    final trace = FirebasePerformance.instance.newTrace(
      'firestore_add_category',
    );
    await trace.start();
    try {
      await RetryService.retryFirestoreOperation(() async {
        await collection.doc(category.id).set({
          'id': category.id,
          'name': category.name,
          'colorValue': category.colorValue,
          'iconCode': category.iconCode,
        });
      });
      _syncStatus.setSuccess();
    } catch (e) {
      AppLogger.error(
        'Firestore addCategory failed after retries',
        error: e,
        tag: 'Firestore',
      );
      _syncStatus.setError('Failed to sync category. Changes saved locally.');
    } finally {
      await trace.stop();
    }
  }

  Future<void> updateCategory(Category category) async {
    final collection = _categoriesCollection;
    if (collection == null || !_shouldSync) return;

    await _throttle();
    _syncStatus.setSyncing();
    final trace = FirebasePerformance.instance.newTrace(
      'firestore_update_category',
    );
    await trace.start();
    try {
      await collection.doc(category.id).set({
        'name': category.name,
        'colorValue': category.colorValue,
        'iconCode': category.iconCode,
      }, SetOptions(merge: true));
      _syncStatus.setSuccess();
    } catch (e) {
      AppLogger.error(
        'Firestore updateCategory failed',
        error: e,
        tag: 'Firestore',
      );
      _syncStatus.setError(
        'Failed to sync category update. Changes saved locally.',
      );
    } finally {
      await trace.stop();
    }
  }

  Future<void> deleteCategory(String id) async {
    final collection = _categoriesCollection;
    if (collection == null || !_shouldSync) return;

    await _throttle();
    _syncStatus.setSyncing();
    final trace = FirebasePerformance.instance.newTrace(
      'firestore_delete_category',
    );
    await trace.start();
    try {
      await collection.doc(id).delete();
      _syncStatus.setSuccess();
    } catch (e) {
      AppLogger.error(
        'Firestore deleteCategory failed',
        error: e,
        tag: 'Firestore',
      );
      _syncStatus.setError(
        'Failed to sync category deletion. Will retry later.',
      );
    } finally {
      await trace.stop();
    }
  }

  Stream<List<Category>> getCategoriesStream() {
    final collection = _categoriesCollection;
    if (collection == null) return const Stream.empty();

    final trace = FirebasePerformance.instance.newTrace(
      'firestore_get_categories_initial',
    );
    bool firstEvent = true;
    trace.start();

    return collection.snapshots().map((snapshot) {
      if (firstEvent) {
        trace.stop();
        firstEvent = false;
      }
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

    await _throttle();
    _syncStatus.setSyncing();
    final trace = FirebasePerformance.instance.newTrace('firestore_add_task');
    await trace.start();
    try {
      await RetryService.retryFirestoreOperation(() async {
        final data = task.toMap();
        data['updatedAt'] = FieldValue.serverTimestamp();
        await collection.doc(task.id).set(data);
      });
      _syncStatus.setSuccess();
    } catch (e) {
      AppLogger.error('Firestore addTask failed', error: e, tag: 'Firestore');
      _syncStatus.setError('Failed to sync task. Changes saved locally.');
    } finally {
      await trace.stop();
    }
  }

  Future<void> updateTask(Task task) async {
    final collection = _tasksCollection;
    if (collection == null || !_shouldSync) return;

    await _throttle();
    _syncStatus.setSyncing();
    final trace = FirebasePerformance.instance.newTrace(
      'firestore_update_task',
    );
    await trace.start();
    try {
      final data = task.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await collection.doc(task.id).set(data, SetOptions(merge: true));
      _syncStatus.setSuccess();
    } catch (e) {
      AppLogger.error(
        'Firestore updateTask failed',
        error: e,
        tag: 'Firestore',
      );
      _syncStatus.setError(
        'Failed to sync task update. Changes saved locally.',
      );
    } finally {
      await trace.stop();
    }
  }

  Future<void> deleteTask(String id) async {
    final collection = _tasksCollection;
    if (collection == null || !_shouldSync) return;

    await _throttle();
    _syncStatus.setSyncing();
    final trace = FirebasePerformance.instance.newTrace(
      'firestore_delete_task',
    );
    await trace.start();
    try {
      await collection.doc(id).delete();
      _syncStatus.setSuccess();
    } catch (e) {
      AppLogger.error(
        'Firestore deleteTask failed',
        error: e,
        tag: 'Firestore',
      );
      _syncStatus.setError('Failed to sync task deletion. Will retry later.');
    } finally {
      await trace.stop();
    }
  }

  Stream<List<TaskSyncEvent>> getActiveTasksStream() {
    final collection = _tasksCollection;
    if (collection == null) return const Stream.empty();

    final trace = FirebasePerformance.instance.newTrace(
      'firestore_get_active_tasks_initial',
    );
    bool firstEvent = true;
    trace.start();

    // Only stream tasks that are NOT completed and NOT deleted.
    // When a task is completed or deleted on another device, it will drop out of this query
    // and trigger a 'removed' DocumentChange event.
    return collection
        .where('isCompleted', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      if (firstEvent) {
        trace.stop();
        firstEvent = false;
      }
      
      return snapshot.docChanges.map((change) {
        final task = Task.fromMap(change.doc.data()!);
        SyncEventType type;
        switch (change.type) {
          case DocumentChangeType.added:
            type = SyncEventType.added;
            break;
          case DocumentChangeType.modified:
            type = SyncEventType.modified;
            break;
          case DocumentChangeType.removed:
            type = SyncEventType.removed;
            break;
        }
        return TaskSyncEvent(type, task);
      }).toList();
    });
  }

  DocumentSnapshot? _lastCompletedTaskDoc;
  bool _hasMoreCompletedTasks = true;

  void resetCompletedTasksCursor() {
    _lastCompletedTaskDoc = null;
    _hasMoreCompletedTasks = true;
  }

  /// Fetches the next paginated batch of completed tasks for lazy loading
  Future<List<Task>> getNextCompletedTasksBatch({int limit = 20}) async {
    final collection = _tasksCollection;
    if (collection == null || !_hasMoreCompletedTasks) return [];

    var query = collection
        .where('isCompleted', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .orderBy('updatedAt', descending: true)
        .limit(limit);

    if (_lastCompletedTaskDoc != null) {
      query = query.startAfterDocument(_lastCompletedTaskDoc!);
    }

    final trace = FirebasePerformance.instance.newTrace('firestore_get_completed_tasks');
    await trace.start();
    try {
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        _hasMoreCompletedTasks = false;
        return [];
      }
      
      if (snapshot.docs.length < limit) {
        _hasMoreCompletedTasks = false;
      }
      
      _lastCompletedTaskDoc = snapshot.docs.last;
      return snapshot.docs.map((doc) => Task.fromMap(doc.data())).toList();
    } catch (e) {
      AppLogger.error('Failed to fetch completed tasks', error: e, tag: 'Firestore');
      return [];
    } finally {
      await trace.stop();
    }
  }
}
