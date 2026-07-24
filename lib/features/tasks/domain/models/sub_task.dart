import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'sub_task.g.dart';

@HiveType(typeId: 3)
class SubTask extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isCompleted;

  @HiveField(3)
  String? quantity;

  SubTask({
    String? id,
    required this.title,
    this.isCompleted = false,
    this.quantity,
  }) : id = id ?? const Uuid().v4();

  SubTask copyWith({String? title, bool? isCompleted, String? quantity}) {
    return SubTask(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'quantity': quantity,
    };
  }

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id'],
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      quantity: map['quantity'] as String?,
    );
  }
}
