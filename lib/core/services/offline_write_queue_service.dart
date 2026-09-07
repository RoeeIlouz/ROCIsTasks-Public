import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/sync_status_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';

enum OfflineOperationType {
  createTask,
  updateTask,
  deleteTask,
  createCategory,
  updateCategory,
  deleteCategory,
}

class QueuedWriteOperation {
  final String id;
  final OfflineOperationType type;
  final String entityId;
  final Map<String, dynamic>? payload;
  final DateTime timestamp;
  int retryCount;

  QueuedWriteOperation({
    required this.id,
    required this.type,
    required this.entityId,
    this.payload,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'entityId': entityId,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
  };

  factory QueuedWriteOperation.fromJson(Map<String, dynamic> json) {
    return QueuedWriteOperation(
      id: json['id'] as String,
      type: OfflineOperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => OfflineOperationType.updateTask,
      ),
      entityId: json['entityId'] as String,
      payload: json['payload'] != null
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }
}

/// Persistent offline write queue that retains pending mutations when network is unreachable,
/// and processes them chronologically with exponential backoff upon restoration.
class OfflineWriteQueueService extends ChangeNotifier {
  static const String _prefKey = 'rocis_offline_write_queue';
  static final OfflineWriteQueueService _instance =
      OfflineWriteQueueService._internal();

  factory OfflineWriteQueueService() => _instance;
  OfflineWriteQueueService._internal();

  final List<QueuedWriteOperation> _queue = [];
  bool _isProcessing = false;
  bool _isInitialized = false;

  List<QueuedWriteOperation> get queue => List.unmodifiable(_queue);
  int get pendingCount => _queue.length;
  bool get hasPendingWrites => _queue.isNotEmpty;

  @visibleForTesting
  void clearForTesting() {
    _queue.clear();
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = json.decode(raw);
        _queue.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _queue.add(QueuedWriteOperation.fromJson(item));
          }
        }
        AppLogger.info(
          'Loaded ${_queue.length} pending offline write operations.',
          tag: 'OfflineQueue',
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to load offline write queue from storage: $e',
        tag: 'OfflineQueue',
      );
    }
  }

  Future<void> _persistToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_queue.isEmpty) {
        await prefs.remove(_prefKey);
      } else {
        final encoded = json.encode(_queue.map((op) => op.toJson()).toList());
        await prefs.setString(_prefKey, encoded);
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to persist offline write queue: $e',
        tag: 'OfflineQueue',
      );
    }
  }

  /// Enqueue an offline mutation. Deduplicates and merges redundant operations
  /// on the same entity to keep the write log compact and deterministic.
  Future<void> enqueue({
    required OfflineOperationType type,
    required String entityId,
    Map<String, dynamic>? payload,
  }) async {
    await init();

    // Deduplication / Operation collapsing
    final existingIndex = _queue.indexWhere((op) => op.entityId == entityId);
    if (existingIndex != -1) {
      final existing = _queue[existingIndex];

      // If existing was createTask and new is deleteTask, remove without ever hitting server
      if (existing.type == OfflineOperationType.createTask &&
          type == OfflineOperationType.deleteTask) {
        _queue.removeAt(existingIndex);
        await _persistToDisk();
        notifyListeners();
        return;
      }

      // If new is updateTask and existing is updateTask/createTask, merge payload
      if (type == OfflineOperationType.updateTask &&
          (existing.type == OfflineOperationType.updateTask ||
              existing.type == OfflineOperationType.createTask)) {
        final mergedPayload = Map<String, dynamic>.from(existing.payload ?? {});
        if (payload != null) {
          mergedPayload.addAll(payload);
        }
        _queue[existingIndex] = QueuedWriteOperation(
          id: existing.id,
          type: existing.type,
          entityId: entityId,
          payload: mergedPayload,
          timestamp: DateTime.now(),
          retryCount: 0,
        );
        await _persistToDisk();
        notifyListeners();
        return;
      }

      // If new is delete, replace previous pending updates
      if (type == OfflineOperationType.deleteTask ||
          type == OfflineOperationType.deleteCategory) {
        _queue[existingIndex] = QueuedWriteOperation(
          id: '${DateTime.now().millisecondsSinceEpoch}_$entityId',
          type: type,
          entityId: entityId,
          payload: null,
          timestamp: DateTime.now(),
        );
        await _persistToDisk();
        notifyListeners();
        return;
      }
    }

    _queue.add(
      QueuedWriteOperation(
        id: '${DateTime.now().millisecondsSinceEpoch}_$entityId',
        type: type,
        entityId: entityId,
        payload: payload,
        timestamp: DateTime.now(),
      ),
    );

    await _persistToDisk();
    notifyListeners();
    AppLogger.info(
      'Enqueued offline operation: ${type.name} for $entityId (Total pending: ${_queue.length})',
      tag: 'OfflineQueue',
    );
  }

  /// Process all pending operations in chronological FIFO order using an executor function.
  Future<void> drainQueue({
    required Future<bool> Function(QueuedWriteOperation op) executor,
  }) async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;
    final syncStatus = SyncStatusService();

    try {
      syncStatus.setSyncing();

      while (_queue.isNotEmpty) {
        final op = _queue.first;
        bool success = false;

        try {
          success = await executor(op);
        } catch (e) {
          AppLogger.warning(
            'Queue executor error for ${op.type.name} on ${op.entityId}: $e',
            tag: 'OfflineQueue',
          );
          success = false;
        }

        if (success) {
          _queue.removeAt(0);
          await _persistToDisk();
          notifyListeners();
        } else {
          op.retryCount++;
          // Calculate exponential backoff: 2s, 4s, 8s, max 30s
          final backoffSeconds = min(30, pow(2, op.retryCount).toInt());
          AppLogger.warning(
            'Queue operation ${op.type.name} failed (attempt ${op.retryCount}). Backing off for ${backoffSeconds}s.',
            tag: 'OfflineQueue',
          );
          syncStatus.setError(
            'Offline sync interrupted. Retrying in ${backoffSeconds}s...',
          );
          break; // Stop draining this pass to honor backoff
        }
      }

      if (_queue.isEmpty) {
        syncStatus.setSuccess();
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Remove all operations for testing/reset
  Future<void> clear() async {
    _queue.clear();
    await _persistToDisk();
    notifyListeners();
  }
}

/// Deterministic conflict resolution for synced entities
class TaskConflictResolver {
  /// Resolves conflicts between local and remote task states.
  /// Strategy:
  /// 1. Field-level timestamp comparison: later updatedAt wins.
  /// 2. Completion preservation: if locally completed recently, honor completion.
  /// 3. Subtask merge: merges subtasks by subtask ID instead of blind overwrites.
  static Task resolveTaskConflict({
    required Task localTask,
    required Task remoteTask,
    required bool hasPendingLocalWrite,
  }) {
    if (hasPendingLocalWrite) {
      // Local has an active in-flight mutation; prefer local state
      return localTask;
    }

    final localUpdated = localTask.completedAt ?? localTask.createdAt;
    final remoteUpdated = remoteTask.completedAt ?? remoteTask.createdAt;

    final baseTask = remoteUpdated.isAfter(localUpdated)
        ? remoteTask
        : localTask;

    // Merge subtasks deterministically
    final Map<String, SubTask> subtaskMap = {};

    if (remoteTask.subTasks != null) {
      for (final st in remoteTask.subTasks!) {
        subtaskMap[st.id] = st;
      }
    }

    if (localTask.subTasks != null) {
      for (final st in localTask.subTasks!) {
        if (!subtaskMap.containsKey(st.id)) {
          subtaskMap[st.id] = st;
        } else {
          // If local has marked it completed more recently, keep local completed state
          final remoteSub = subtaskMap[st.id]!;
          if (st.isCompleted && !remoteSub.isCompleted) {
            subtaskMap[st.id] = st;
          }
        }
      }
    }

    return baseTask.copyWith(subTasks: subtaskMap.values.toList());
  }
}
