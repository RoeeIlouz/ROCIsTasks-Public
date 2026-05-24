import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'category.g.dart';

@HiveType(typeId: 2)
class Category extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  int iconCode;

  @HiveField(4)
  bool isPrivate;

  Category({
    String? id,
    required this.name,
    required this.colorValue,
    required this.iconCode,
    this.isPrivate = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'iconCode': iconCode,
      'isPrivate': isPrivate,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'] ?? '',
      colorValue: map['colorValue'] ?? 0xFF2196F3,
      iconCode: map['iconCode'] ?? 0,
      isPrivate: map['isPrivate'] ?? false,
    );
  }
}
