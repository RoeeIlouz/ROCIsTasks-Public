import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/retry_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/sync_status_service.dart';
import 'package:rocis_tasks/core/services/offline_write_queue_service.dart';
import 'package:firebase_performance/firebase_performance.dart';

enum SyncEventType { added, modified, removed }

class TaskSyncEvent {
  final SyncEventType type;
  final Task task;

  /// The task was permanently deleted (tombstoned) in the cloud.
  final bool isPurged;
  TaskSyncEvent(this.type, this.task, {this.isPurged = false});
}

/// Cloud-side state of a task used to decide whether to upload a local copy.
typedef CloudTaskState = ({
  DateTime? editedAt,
  bool isPurged,
  bool missingQueryFields,
});

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
          'isPrivate': category.isPrivate,
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
      await OfflineWriteQueueService().enqueue(
        type: OfflineOperationType.createCategory,
        entityId: category.id,
        payload: {
          'id': category.id,
          'name': category.name,
          'colorValue': category.colorValue,
          'iconCode': category.iconCode,
          'isPrivate': category.isPrivate,
        },
      );
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
        'isPrivate': category.isPrivate,
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
      await OfflineWriteQueueService().enqueue(
        type: OfflineOperationType.updateCategory,
        entityId: category.id,
        payload: {
          'name': category.name,
          'colorValue': category.colorValue,
          'iconCode': category.iconCode,
          'isPrivate': category.isPrivate,
        },
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
      await OfflineWriteQueueService().enqueue(
        type: OfflineOperationType.deleteCategory,
        entityId: id,
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
          isPrivate: data['isPrivate'] ?? false,
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
        final data = task.toFirestoreMap();
        data['updatedAt'] = FieldValue.serverTimestamp();
        // Merge (not overwrite) so a write can never clear `isPurged`.
        await collection.doc(task.id).set(data, SetOptions(merge: true));
      });
      _syncStatus.setSuccess();
    } catch (e) {
      AppLogger.error('Firestore addTask failed', error: e, tag: 'Firestore');
      _syncStatus.setError('Failed to sync task. Changes saved locally.');
      await OfflineWriteQueueService().enqueue(
        type: OfflineOperationType.createTask,
        entityId: task.id,
        payload: task.toFirestoreMap(),
      );
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
      final data = task.toFirestoreMap();
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
      await OfflineWriteQueueService().enqueue(
        type: OfflineOperationType.updateTask,
        entityId: task.id,
        payload: task.toFirestoreMap(),
      );
    } finally {
      await trace.stop();
    }
  }

  static const _maxWhereInIds = 30;

  /// Reads the edit time and purge state of each of [taskIds] that exists in
  /// the cloud, straight from the server (never the local cache). Missing ids
  /// are absent from the result. Throws when the server is unreachable.
  Future<Map<String, CloudTaskState>> fetchTaskStates(
    List<String> taskIds,
  ) async {
    final collection = _tasksCollection;
    if (collection == null || !_shouldSync || taskIds.isEmpty) return {};

    final chunks = [
      for (var i = 0; i < taskIds.length; i += _maxWhereInIds)
        taskIds.sublist(i, (i + _maxWhereInIds).clamp(0, taskIds.length)),
    ];
    final snapshots = await Future.wait(
      chunks.map(
        (ids) => collection
            .where(FieldPath.documentId, whereIn: ids)
            .get(const GetOptions(source: Source.server)),
      ),
    );
    return {
      for (final snapshot in snapshots)
        for (final doc in snapshot.docs)
          doc.id: (
            editedAt: Task.cloudModifiedAt(doc.data()),
            isPurged: isPurgedData(doc.data()),
            // The active-task listener filters on these with isEqualTo, which
            // never matches a missing or null field, so such docs are
            // invisible to every other device until rewritten.
            missingQueryFields:
                doc.data()['isCompleted'] is! bool ||
                doc.data()['isDeleted'] is! bool,
          ),
    };
  }

  static const _maxBatchWrites = 500;

  /// Uploads every local category and task using chunked write batches:
  /// one round trip per 500 documents instead of one throttled write each.
  Future<void> uploadAll({
    required List<Category> categories,
    required List<Task> tasks,
  }) async {
    final tasksCol = _tasksCollection;
    final catsCol = _categoriesCollection;
    if (tasksCol == null || catsCol == null || !_shouldSync) return;
    if (categories.isEmpty && tasks.isEmpty) return;

    final writes = <void Function(WriteBatch)>[
      for (final category in categories)
        (batch) => batch.set(catsCol.doc(category.id), {
          'id': category.id,
          'name': category.name,
          'colorValue': category.colorValue,
          'iconCode': category.iconCode,
          'isPrivate': category.isPrivate,
        }),
      for (final task in tasks)
        (batch) => batch.set(tasksCol.doc(task.id), {
          ...task.toFirestoreMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
    ];

    _syncStatus.setSyncing();
    try {
      final commits = <Future<void>>[];
      for (var i = 0; i < writes.length; i += _maxBatchWrites) {
        final batch = _firestore.batch();
        final end = (i + _maxBatchWrites).clamp(0, writes.length);
        for (final write in writes.sublist(i, end)) {
          write(batch);
        }
        commits.add(batch.commit());
      }
      await Future.wait(commits);
      _syncStatus.setSuccess();
    } catch (e) {
      AppLogger.error('Firestore uploadAll failed', error: e, tag: 'Firestore');
      _syncStatus.setError('Failed to sync tasks. Changes saved locally.');
      rethrow;
    }
  }

  static bool isPurgedData(Map<String, dynamic>? data) =>
      data?['isPurged'] == true;

  /// A permanently deleted task. Stripped of content, but kept (rather than
  /// deleting the document) so devices that were offline or still hold a copy
  /// learn about the deletion and can't recreate the task by writing it back.
  /// Satisfies the task schema in firestore.rules.
  static Map<String, dynamic> tombstoneData(String id) => {
    'id': id,
    'title': 'deleted',
    'description': '',
    'priority': TaskPriority.medium.index,
    'isCompleted': true,
    'isDeleted': true,
    'isPinned': false,
    'isPurged': true,
    'modifiedAt': DateTime.now(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Permanently deletes a task by replacing it with a tombstone.
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
      await collection.doc(id).set(tombstoneData(id));
      _syncStatus.setSuccess();
    } catch (e) {
      AppLogger.error(
        'Firestore deleteTask failed',
        error: e,
        tag: 'Firestore',
      );
      _syncStatus.setError('Failed to sync task deletion. Will retry later.');
      await OfflineWriteQueueService().enqueue(
        type: OfflineOperationType.deleteTask,
        entityId: id,
      );
    } finally {
      await trace.stop();
    }
  }

  /// Drains any pending offline mutations with exponential backoff
  Future<void> processOfflineQueue() async {
    final queueService = OfflineWriteQueueService();
    if (!queueService.hasPendingWrites || !_shouldSync) return;

    await queueService.drainQueue(
      executor: (op) async {
        final tasksCol = _tasksCollection;
        final catsCol = _categoriesCollection;

        switch (op.type) {
          case OfflineOperationType.createTask:
          case OfflineOperationType.updateTask:
            if (tasksCol == null || op.payload == null) return false;
            final data = Map<String, dynamic>.from(op.payload!);
            data['updatedAt'] = FieldValue.serverTimestamp();
            await tasksCol.doc(op.entityId).set(data, SetOptions(merge: true));
            return true;

          case OfflineOperationType.deleteTask:
            if (tasksCol == null) return false;
            await tasksCol.doc(op.entityId).set(tombstoneData(op.entityId));
            return true;

          case OfflineOperationType.createCategory:
          case OfflineOperationType.updateCategory:
            if (catsCol == null || op.payload == null) return false;
            await catsCol
                .doc(op.entityId)
                .set(op.payload!, SetOptions(merge: true));
            return true;

          case OfflineOperationType.deleteCategory:
            if (catsCol == null) return false;
            await catsCol.doc(op.entityId).delete();
            return true;
        }
      },
    );
  }

  Future<(Task? task, bool isMissing)> fetchTaskById(String id) async {
    final collection = _tasksCollection;
    if (collection == null || !_shouldSync) return (null, false);

    try {
      final doc = await collection.doc(id).get();
      final data = doc.data();
      if (!doc.exists || data == null || isPurgedData(data)) {
        return (null, true);
      }
      return (Task.fromMap(data), false);
    } catch (e) {
      AppLogger.error(
        'Firestore fetchTaskById failed',
        error: e,
        tag: 'Firestore',
      );
      return (null, false);
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
            final data = change.doc.data()!;
            final task = Task.fromMap(data);
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
            return TaskSyncEvent(type, task, isPurged: isPurgedData(data));
          }).toList();
        });
  }

  /// Ids of permanently deleted tasks, so a device that was offline when a
  /// task was deleted elsewhere drops its stale local copy on reconnect.
  Stream<List<String>> getPurgedTaskIdsStream() {
    final collection = _tasksCollection;
    if (collection == null) return const Stream.empty();
    return collection
        .where('isPurged', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
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

    final trace = FirebasePerformance.instance.newTrace(
      'firestore_get_completed_tasks',
    );
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
      return snapshot.docs
          .where((doc) => !isPurgedData(doc.data()))
          .map((doc) => Task.fromMap(doc.data()))
          .toList();
    } catch (e) {
      AppLogger.error(
        'Failed to fetch completed tasks',
        error: e,
        tag: 'Firestore',
      );
      return [];
    } finally {
      await trace.stop();
    }
  }
}
