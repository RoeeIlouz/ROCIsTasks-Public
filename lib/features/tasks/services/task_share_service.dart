import 'dart:convert';
import 'package:archive/archive.dart' show GZipDecoder, GZipEncoder;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';

/// Result of parsing any QR code (offline or cloud).
class TaskShareData {
  final Task task;
  final String? suggestedCategoryName;
  final bool isCloud;
  final String? shareId;

  TaskShareData({
    required this.task,
    this.suggestedCategoryName,
    this.isCloud = false,
    this.shareId,
  });
}

class TaskShareService {
  /// Share links are verified App Links: they open the app, or the web app
  /// when it isn't installed. Both routes handle `/share`.
  static const String linkBase = 'https://tasks.rocisapps.com/share';

  /// Cloud prefix of QR codes made by 0.3.1; they still resolve.
  static const String legacyCloudScheme = 'rocis://task/cloud';
  static const int cloudTtlDays = 7;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  TaskShareService({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  // ---------------------------------------------------------------------------
  // 1. OFFLINE ENCODING & DECODING
  // ---------------------------------------------------------------------------

  /// Compresses a [task] into an offline QR payload string.
  /// Format: `https://tasks.rocisapps.com/share?d=<BASE64URL_GZIP_JSON>`
  String generateOfflinePayload(Task task, {String? categoryName}) {
    final Map<String, dynamic> compact = {
      'v': 1,
      't': task.title,
      if (task.description.trim().isNotEmpty) 'd': task.description.trim(),
      if (task.dueDate != null) 'due': task.dueDate!.toIso8601String(),
      if (task.priority != TaskPriority.medium) 'p': task.priority.index,
      if (categoryName != null && categoryName.trim().isNotEmpty)
        'c': categoryName.trim(),
      if (task.recurrenceRule != null && task.recurrenceRule!.isNotEmpty)
        'r': task.recurrenceRule,
      if (task.isGroceryList) 'g': 1,
      if (task.subTasks != null && task.subTasks!.isNotEmpty)
        'st': task.subTasks!
            .map(
              (s) => {
                't': s.title,
                if (s.quantity != null && s.quantity!.isNotEmpty)
                  'q': s.quantity,
              },
            )
            .toList(),
      if (task.customFields != null && task.customFields!.isNotEmpty)
        'cf': task.customFields!.map((f) => f.toMap()).toList(),
    };

    final jsonStr = jsonEncode(compact);
    final utf8Bytes = utf8.encode(jsonStr);
    final compressedBytes = GZipEncoder().encodeBytes(utf8Bytes);
    final base64Payload = base64Url.encode(compressedBytes);

    return '$linkBase?d=$base64Payload';
  }

  /// Decodes raw text from a QR code if it represents an offline task.
  /// Returns raw map or null if invalid.
  Map<String, dynamic>? decodeOfflinePayload(String raw) {
    try {
      String encodedData = raw.trim();

      // Extract parameter if formatted as URI
      if (encodedData.contains('d=')) {
        final uri = Uri.tryParse(encodedData);
        if (uri != null && uri.queryParameters.containsKey('d')) {
          encodedData = uri.queryParameters['d']!;
        } else {
          final idx = encodedData.indexOf('d=');
          encodedData = encodedData.substring(idx + 2);
          final ampIdx = encodedData.indexOf('&');
          if (ampIdx != -1) {
            encodedData = encodedData.substring(0, ampIdx);
          }
        }
      }

      // Base64Url decode -> GZip decompress -> UTF-8 decode -> JSON
      final compressedBytes = base64Url.decode(encodedData);
      final decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);
      final jsonStr = utf8.decode(decompressedBytes);
      final decoded = jsonDecode(jsonStr);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fallback: Check if it's plain uncompressed JSON
      try {
        final plainJson = jsonDecode(raw);
        if (plainJson is Map<String, dynamic>) {
          return plainJson;
        }
      } catch (_) {}
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. CLOUD SHARING (7-Day TTL)
  // ---------------------------------------------------------------------------

  /// Uploads a task snapshot to Firestore `/shared_tasks/{shareId}` with a 7-day TTL.
  /// Returns the share URI: `https://tasks.rocisapps.com/share?id={shareId}`.
  Future<String> uploadCloudTask(
    Task task, {
    String? categoryName,
    String? authorId,
  }) async {
    final docRef = _firestore.collection('shared_tasks').doc();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: cloudTtlDays));

    final Map<String, dynamic> docData = {
      'id': docRef.id,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'authorId': authorId ?? 'anonymous',
      'task': {
        'title': task.title,
        'description': task.description,
        'priority': task.priority.index,
        'dueDate': task.dueDate != null
            ? Timestamp.fromDate(task.dueDate!)
            : null,
        'recurrenceRule': task.recurrenceRule,
        'categoryName': categoryName,
        'isGroceryList': task.isGroceryList,
        'subTasks': task.subTasks
            ?.map((s) => {'title': s.title, 'quantity': s.quantity})
            .toList(),
        'customFields': task.customFields?.map((f) => f.toMap()).toList(),
      },
    };

    await docRef.set(docData);
    return '$linkBase?id=${docRef.id}';
  }

  /// Fetches a task snapshot from Firestore.
  /// Throws [StateError] if expired or not found.
  Future<Map<String, dynamic>?> fetchCloudTask(String shareId) async {
    final docSnap = await _firestore
        .collection('shared_tasks')
        .doc(shareId)
        .get();

    if (!docSnap.exists) {
      throw StateError('TASK_NOT_FOUND');
    }

    final data = docSnap.data();
    if (data == null) {
      throw StateError('TASK_NOT_FOUND');
    }

    // Check 7-day expiration
    final expiresAtRaw = data['expiresAt'];
    if (expiresAtRaw is Timestamp) {
      if (expiresAtRaw.toDate().isBefore(DateTime.now())) {
        throw StateError('TASK_EXPIRED');
      }
    }

    final taskData = data['task'];
    if (taskData is Map<String, dynamic>) {
      return taskData;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 3. UNIFIED RESOLVER & SANITIZATION
  // ---------------------------------------------------------------------------

  /// Resolves any scanned QR string (either offline or cloud).
  Future<TaskShareData> resolveQrString(
    String raw,
    List<Category> localCategories,
  ) async {
    final trimmed = raw.trim();

    // Check if it's a Cloud Link
    final cloudId = _extractCloudId(trimmed);
    if (cloudId != null) {
      final cloudTaskData = await fetchCloudTask(cloudId);
      if (cloudTaskData == null) {
        throw StateError('INVALID_TASK_DATA');
      }
      return _buildSanitizedTaskData(
        cloudTaskData,
        localCategories,
        isCloud: true,
        shareId: cloudId,
      );
    }

    // Attempt Offline decoding
    final offlineMap = decodeOfflinePayload(trimmed);
    if (offlineMap != null) {
      return _buildSanitizedTaskData(
        offlineMap,
        localCategories,
        isCloud: false,
      );
    }

    throw StateError('UNRECOGNIZED_QR_CODE');
  }

  /// Extracts the cloud share ID from known URI schemes or web URLs.
  String? _extractCloudId(String raw) {
    if (raw.startsWith(legacyCloudScheme) || raw.contains('id=')) {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.queryParameters.containsKey('id')) {
        return uri.queryParameters['id'];
      }
    }
    return null;
  }

  /// Sanitizes raw data map into a clean, safe [Task] with a new UUID and reset subtasks.
  TaskShareData _buildSanitizedTaskData(
    Map<String, dynamic> raw,
    List<Category> localCategories, {
    bool isCloud = false,
    String? shareId,
  }) {
    // Support both compact keys (t, d, p, due) and cloud keys (title, description, etc.)
    final title = (raw['t'] ?? raw['title'] ?? '').toString();
    final description = (raw['d'] ?? raw['description'] ?? '').toString();

    // Priority
    final priorityIndex = (raw['p'] ?? raw['priority'] ?? 1) as int;
    final priority =
        (priorityIndex >= 0 && priorityIndex < TaskPriority.values.length)
        ? TaskPriority.values[priorityIndex]
        : TaskPriority.medium;

    // Due date
    DateTime? dueDate;
    final rawDue = raw['due'] ?? raw['dueDate'];
    if (rawDue is Timestamp) {
      dueDate = rawDue.toDate();
    } else if (rawDue is String) {
      dueDate = DateTime.tryParse(rawDue);
    }

    // Recurrence
    final recurrence = (raw['r'] ?? raw['recurrenceRule']) as String?;

    // Grocery flag
    final isGrocery = (raw['g'] == 1) || (raw['isGroceryList'] == true);

    // Subtasks: Always reset isCompleted to FALSE
    List<SubTask>? subTasks;
    final rawSubTasks = raw['st'] ?? raw['subTasks'];
    if (rawSubTasks is List) {
      subTasks = rawSubTasks.map<SubTask>((item) {
        if (item is Map) {
          final stTitle = (item['t'] ?? item['title'] ?? '').toString();
          final qty = (item['q'] ?? item['quantity']) as String?;
          return SubTask(
            id: const Uuid().v4(),
            title: stTitle,
            isCompleted: false, // Reset per requirement
            quantity: qty,
          );
        } else {
          return SubTask(
            id: const Uuid().v4(),
            title: item.toString(),
            isCompleted: false,
          );
        }
      }).toList();
    }

    // Custom fields
    List<TaskCustomField>? customFields;
    final rawFields = raw['cf'] ?? raw['customFields'];
    if (rawFields is List) {
      customFields = rawFields
          .whereType<Map<String, dynamic>>()
          .map(TaskCustomField.fromMap)
          .toList();
    }

    // Category Resolution
    final categoryName = (raw['c'] ?? raw['categoryName']) as String?;
    String? matchedCategoryId;
    if (categoryName != null && categoryName.trim().isNotEmpty) {
      final match = localCategories.where(
        (c) => c.name.trim().toLowerCase() == categoryName.trim().toLowerCase(),
      );
      if (match.isNotEmpty) {
        matchedCategoryId = match.first.id;
      }
    }

    final sanitizedTask = Task(
      id: const Uuid().v4(), // Fresh ID
      title: title,
      description: description,
      isCompleted: false,
      priority: priority,
      dueDate: dueDate,
      recurrenceRule: recurrence,
      isGroceryList: isGrocery,
      categoryId: matchedCategoryId,
      categoryIds: matchedCategoryId != null ? [matchedCategoryId] : [],
      subTasks: subTasks,
      customFields: customFields,
      createdAt: DateTime.now(),
      // Explicitly clear device-specific sync IDs & local file paths
      syncWithGoogleTasks: false,
      googleTaskId: null,
      googleTaskListId: null,
      attachmentPaths: const [],
      isDeleted: false,
      isPinned: false,
    );

    return TaskShareData(
      task: sanitizedTask,
      suggestedCategoryName: matchedCategoryId == null ? categoryName : null,
      isCloud: isCloud,
      shareId: shareId,
    );
  }
}
