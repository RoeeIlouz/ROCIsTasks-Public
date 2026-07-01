// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 1;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String,
      isCompleted: fields[3] as bool,
      dueDate: fields[4] as DateTime?,
      priority: fields[5] as TaskPriority,
      categoryId: fields[6] as String?,
      categoryIds: (fields[19] as List?)?.cast<String>(),
      isDeleted: fields[7] as bool?,
      isPinned: fields[8] as bool?,
      subTasks: (fields[9] as List?)?.cast<SubTask>(),
      recurrenceRule: fields[10] as String?,
      completedAt: fields[11] as DateTime?,
      createdAt: fields[12] as DateTime?,
      requireSubTasksBeforeReminders: fields[13] as bool,
      syncWithGoogleCalendar: fields[14] as bool,
      calendarEventId: fields[15] as String?,
      calendarId: fields[16] as String?,
      attachmentPaths: (fields[17] as List?)?.cast<String>(),
      skipReminders: fields[18] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.isCompleted)
      ..writeByte(4)
      ..write(obj.dueDate)
      ..writeByte(5)
      ..write(obj.priority)
      ..writeByte(6)
      ..write(obj.categoryId)
      ..writeByte(19)
      ..write(obj.categoryIds)
      ..writeByte(7)
      ..write(obj.isDeleted)
      ..writeByte(8)
      ..write(obj.isPinned)
      ..writeByte(9)
      ..write(obj.subTasks)
      ..writeByte(10)
      ..write(obj.recurrenceRule)
      ..writeByte(11)
      ..write(obj.completedAt)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.requireSubTasksBeforeReminders)
      ..writeByte(14)
      ..write(obj.syncWithGoogleCalendar)
      ..writeByte(15)
      ..write(obj.calendarEventId)
      ..writeByte(16)
      ..write(obj.calendarId)
      ..writeByte(17)
      ..write(obj.attachmentPaths)
      ..writeByte(18)
      ..write(obj.skipReminders);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskPriorityAdapter extends TypeAdapter<TaskPriority> {
  @override
  final int typeId = 0;

  @override
  TaskPriority read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskPriority.low;
      case 1:
        return TaskPriority.medium;
      case 2:
        return TaskPriority.high;
      default:
        return TaskPriority.low;
    }
  }

  @override
  void write(BinaryWriter writer, TaskPriority obj) {
    switch (obj) {
      case TaskPriority.low:
        writer.writeByte(0);
        break;
      case TaskPriority.medium:
        writer.writeByte(1);
        break;
      case TaskPriority.high:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskPriorityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
