// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_field.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomFieldTypeAdapter extends TypeAdapter<CustomFieldType> {
  @override
  final int typeId = 4;

  @override
  CustomFieldType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CustomFieldType.contact;
      case 1:
        return CustomFieldType.location;
      case 2:
        return CustomFieldType.url;
      case 3:
        return CustomFieldType.text;
      default:
        return CustomFieldType.text;
    }
  }

  @override
  void write(BinaryWriter writer, CustomFieldType obj) {
    switch (obj) {
      case CustomFieldType.contact:
        writer.writeByte(0);
        break;
      case CustomFieldType.location:
        writer.writeByte(1);
        break;
      case CustomFieldType.url:
        writer.writeByte(2);
        break;
      case CustomFieldType.text:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomFieldTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskCustomFieldAdapter extends TypeAdapter<TaskCustomField> {
  @override
  final int typeId = 5;

  @override
  TaskCustomField read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskCustomField(
      id: fields[0] as String?,
      type: fields[1] as CustomFieldType? ?? CustomFieldType.text,
      label: (fields[2] as String?) ?? '',
      value: (fields[3] as String?) ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, TaskCustomField obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.value);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCustomFieldAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
