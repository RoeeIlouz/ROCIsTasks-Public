import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

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

  @HiveField(7)
  bool? isDeleted;

  @HiveField(8)
  bool? isPinned;

  @HiveField(9)
  List<SubTask>? subTasks;

  @HiveField(10)
  String? recurrenceRule; // iCal format (e.g. "FREQ=DAILY;INTERVAL=1")

  Task({
    String? id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.categoryId,
    this.isDeleted = false,
    this.isPinned = false,
    this.subTasks,
    this.recurrenceRule,
  }) : id = id ?? const Uuid().v4();

  Task copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    TaskPriority? priority,
    String? categoryId,
    bool? isDeleted,
    bool? isPinned,
    List<SubTask>? subTasks,
    String? recurrenceRule,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
      isDeleted: isDeleted ?? this.isDeleted,
      isPinned: isPinned ?? this.isPinned,
      subTasks: subTasks ?? this.subTasks,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
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
      'isDeleted': isDeleted,
      'isPinned': isPinned,
      'subTasks': subTasks?.map((st) => st.toMap()).toList(),
      'recurrenceRule': recurrenceRule,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      dueDate: map['dueDate'] != null
          ? DateTime.tryParse(map['dueDate'])
          : null,
      priority: TaskPriority.values[map['priority'] ?? 1],
      categoryId: map['categoryId'],
      isDeleted: map['isDeleted'] ?? false,
      isPinned: map['isPinned'] ?? false,
      subTasks: (map['subTasks'] as List?)
          ?.map((st) => SubTask.fromMap(st as Map<String, dynamic>))
          .toList(),
      recurrenceRule: map['recurrenceRule'],
    );
  }
}
