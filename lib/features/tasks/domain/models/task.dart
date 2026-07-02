import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
enum TaskPriority {
  @HiveField(0)
  low,
  @HiveField(1)
  medium,
  @HiveField(2)
  high,
}

@HiveType(typeId: 1)
class Task extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  bool isCompleted;

  @HiveField(4)
  DateTime? dueDate;

  @HiveField(5)
  TaskPriority priority;

  @HiveField(6)
  String? categoryId;

  @HiveField(19)
  List<String> categoryIds;

  @HiveField(7)
  bool? isDeleted;

  @HiveField(8)
  bool? isPinned;

  @HiveField(9)
  List<SubTask>? subTasks;

  @HiveField(10)
  String? recurrenceRule; // iCal format (e.g. "FREQ=DAILY;INTERVAL=1")

  @HiveField(11)
  DateTime? completedAt;

  @HiveField(12)
  DateTime createdAt;

  @HiveField(13)
  bool requireSubTasksBeforeReminders;

  @HiveField(14)
  bool syncWithGoogleTasks;

  @HiveField(15)
  String? googleTaskId;

  @HiveField(16)
  String? googleTaskListId;

  @HiveField(17)
  List<String> attachmentPaths;

  @HiveField(18)
  bool skipReminders;

  Task({
    String? id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.categoryId,
    List<String>? categoryIds,
    this.isDeleted = false,
    this.isPinned = false,
    this.subTasks,
    this.recurrenceRule,
    this.completedAt,
    DateTime? createdAt,
    this.requireSubTasksBeforeReminders = false,
    this.syncWithGoogleTasks = false,
    this.googleTaskId,
    this.googleTaskListId,
    List<String>? attachmentPaths,
    this.skipReminders = false,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       attachmentPaths = attachmentPaths ?? <String>[],
       categoryIds = categoryIds ?? <String>[];

  Task copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    TaskPriority? priority,
    String? categoryId,
    List<String>? categoryIds,
    bool? isDeleted,
    bool? isPinned,
    List<SubTask>? subTasks,
    String? recurrenceRule,
    DateTime? completedAt,
    DateTime? createdAt,
    bool? requireSubTasksBeforeReminders,
    bool? syncWithGoogleTasks,
    String? googleTaskId,
    String? googleTaskListId,
    List<String>? attachmentPaths,
    bool? skipReminders,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
      categoryIds: categoryIds ?? this.categoryIds,
      isDeleted: isDeleted ?? this.isDeleted,
      isPinned: isPinned ?? this.isPinned,
      subTasks: subTasks ?? this.subTasks,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      requireSubTasksBeforeReminders:
          requireSubTasksBeforeReminders ?? this.requireSubTasksBeforeReminders,
      syncWithGoogleTasks:
          syncWithGoogleTasks ?? this.syncWithGoogleTasks,
      googleTaskId: googleTaskId ?? this.googleTaskId,
      googleTaskListId: googleTaskListId ?? this.googleTaskListId,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      skipReminders: skipReminders ?? this.skipReminders,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority.index,
      'categoryId': categoryId,
      'categoryIds': categoryIds,
      'isDeleted': isDeleted,
      'isPinned': isPinned,
      'subTasks': subTasks?.map((st) => st.toMap()).toList(),
      'recurrenceRule': recurrenceRule,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'requireSubTasksBeforeReminders': requireSubTasksBeforeReminders,
      'syncWithGoogleTasks': syncWithGoogleTasks,
      'googleTaskId': googleTaskId,
      'googleTaskListId': googleTaskListId,
      'attachmentPaths': attachmentPaths,
      'skipReminders': skipReminders,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'dueDate': dueDate,
      'priority': priority.index,
      'categoryId': categoryId,
      'categoryIds': categoryIds,
      'isDeleted': isDeleted ?? false,
      'isPinned': isPinned ?? false,
      'subTasks': subTasks?.map((st) => st.toMap()).toList(),
      'recurrenceRule': recurrenceRule,
      'completedAt': completedAt,
      'createdAt': createdAt,
      'requireSubTasksBeforeReminders': requireSubTasksBeforeReminders,
      'syncWithGoogleTasks': syncWithGoogleTasks,
      'googleTaskId': googleTaskId,
      'googleTaskListId': googleTaskListId,
      'skipReminders': skipReminders,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      dueDate: _parseDate(map['dueDate']),
      priority: TaskPriority.values[map['priority'] ?? 1],
      categoryId: map['categoryId'],
      categoryIds: (map['categoryIds'] as List?)?.whereType<String>().toList() ?? 
          (map['categoryId'] != null ? [map['categoryId'] as String] : []),
      isDeleted: map['isDeleted'] ?? false,
      isPinned: map['isPinned'] ?? false,
      subTasks: (map['subTasks'] as List?)
          ?.map((st) => SubTask.fromMap(st as Map<String, dynamic>))
          .toList(),
      recurrenceRule: map['recurrenceRule'],
      completedAt: _parseDate(map['completedAt']),
      createdAt: _parseDate(map['createdAt']),
      requireSubTasksBeforeReminders:
          map['requireSubTasksBeforeReminders'] ?? false,
      syncWithGoogleTasks: map['syncWithGoogleTasks'] ?? map['syncWithGoogleCalendar'] ?? false,
      googleTaskId: map['googleTaskId'] ?? map['calendarEventId'],
      googleTaskListId: map['googleTaskListId'] ?? map['calendarId'],
      attachmentPaths:
          (map['attachmentPaths'] as List?)?.whereType<String>().toList(),
      skipReminders: map['skipReminders'] ?? false,
    );
  }
}
