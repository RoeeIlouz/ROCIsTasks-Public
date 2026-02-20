import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/connectivity_service.dart';
import 'package:rocis_tasks/core/services/retry_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/sync_status_service.dart';
import 'package:firebase_performance/firebase_performance.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityService _connectivityService = ConnectivityService();
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
    _userId = userId;
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

  Stream<List<Task>> getTasksStream() {
    final collection = _tasksCollection;
    if (collection == null) return const Stream.empty();

    final trace = FirebasePerformance.instance.newTrace(
      'firestore_get_tasks_initial',
    );
    bool firstEvent = true;
    trace.start();

    return collection.snapshots().map((snapshot) {
      if (firstEvent) {
        trace.stop();
        firstEvent = false;
      }
      return snapshot.docs.map((doc) {
        return Task.fromMap(doc.data());
      }).toList();
    });
  }
}
