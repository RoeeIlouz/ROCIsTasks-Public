import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'custom_field.g.dart';

@HiveType(typeId: 4)
enum CustomFieldType {
  @HiveField(0)
  contact,
  @HiveField(1)
  location,
  @HiveField(2)
  url,
  @HiveField(3)
  text,
}

@HiveType(typeId: 5)
class TaskCustomField extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  CustomFieldType type;

  @HiveField(2)
  String label;

  @HiveField(3)
  String value;

  TaskCustomField({
    String? id,
    required this.type,
    required this.label,
    required this.value,
  }) : id = id ?? const Uuid().v4();

  TaskCustomField copyWith({
    String? id,
    CustomFieldType? type,
    String? label,
    String? value,
  }) {
    return TaskCustomField(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'label': label,
      'value': value,
    };
  }

  factory TaskCustomField.fromMap(Map<String, dynamic> map) {
    int typeIndex = 3;
    if (map['type'] is int) {
      typeIndex = map['type'] as int;
    } else if (map['type'] is String) {
      typeIndex = CustomFieldType.values.indexWhere(
        (e) => e.name.toLowerCase() == (map['type'] as String).toLowerCase(),
      );
      if (typeIndex < 0) typeIndex = 3;
    }
    if (typeIndex < 0 || typeIndex >= CustomFieldType.values.length) {
      typeIndex = 3;
    }

    return TaskCustomField(
      id: map['id'] as String?,
      type: CustomFieldType.values[typeIndex],
      label: (map['label'] as String?) ?? '',
      value: (map['value'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCustomField &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          label == other.label &&
          value == other.value;

  @override
  int get hashCode => Object.hash(id, type, label, value);
}
