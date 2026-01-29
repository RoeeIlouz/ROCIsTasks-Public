// Data models for ROCIs-Schedule integration
// These models represent schedule data fetched from the rocis-schedule Firestore

import 'package:flutter/material.dart';

/// Event types matching ROCIs-Schedule EventType enum
enum ScheduleEventType {
  classType, // 0 - Regular class
  exam, // 1 - Exam
  lab, // 2 - Lab session
  study, // 3 - Study time
  other, // 4 - Other event
}

/// Represents a course from ROCIs-Schedule
class CourseData {
  final String id;
  final String name;
  final String code;
  final String instructor;
  final Color color;
  final int credits;

  CourseData({
    required this.id,
    required this.name,
    required this.code,
    required this.instructor,
    required this.color,
    required this.credits,
  });

  factory CourseData.fromMap(Map<String, dynamic> map) {
    return CourseData(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      instructor: map['instructor'] ?? '',
      color: Color(map['color'] ?? 0xFF4285F4),
      credits: map['credits'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'instructor': instructor,
      'color': color.toARGB32(),
      'credits': credits,
    };
  }
}

/// Represents a schedule event from ROCIs-Schedule
class ScheduleEventData {
  final String id;
  final String title;
  final String courseId;
  final ScheduleEventType type;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final List<int> daysOfWeek; // 0=Sunday, 1=Monday, etc.
  final bool recurring;
  final String notes;
  final Color? courseColor; // Populated from course lookup

  ScheduleEventData({
    required this.id,
    required this.title,
    required this.courseId,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.location = '',
    this.daysOfWeek = const [],
    this.recurring = false,
    this.notes = '',
    this.courseColor,
  });

  factory ScheduleEventData.fromMap(Map<String, dynamic> map, {Color? courseColor}) {
    // Parse daysOfWeek from comma-separated string or list
    List<int> parseDaysOfWeek(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.cast<int>();
      if (value is String && value.isNotEmpty) {
        return value.split(',').where((e) => e.isNotEmpty).map(int.parse).toList();
      }
      return [];
    }

    return ScheduleEventData(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      courseId: map['courseId'] ?? '',
      type: ScheduleEventType.values[map['type'] ?? 0],
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      location: map['location'] ?? '',
      daysOfWeek: parseDaysOfWeek(map['daysOfWeek']),
      recurring: map['recurring'] == 1 || map['recurring'] == true,
      notes: map['notes'] ?? '',
      courseColor: courseColor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'courseId': courseId,
      'type': type.index,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'daysOfWeek': daysOfWeek.join(','),
      'recurring': recurring ? 1 : 0,
      'notes': notes,
    };
  }

  /// Create a copy with modified fields
  ScheduleEventData copyWith({
    String? id,
    String? title,
    String? courseId,
    ScheduleEventType? type,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    List<int>? daysOfWeek,
    bool? recurring,
    String? notes,
    Color? courseColor,
  }) {
    return ScheduleEventData(
      id: id ?? this.id,
      title: title ?? this.title,
      courseId: courseId ?? this.courseId,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      recurring: recurring ?? this.recurring,
      notes: notes ?? this.notes,
      courseColor: courseColor ?? this.courseColor,
    );
  }

  /// Get human-readable event type name
  String get eventTypeName {
    switch (type) {
      case ScheduleEventType.classType:
        return 'Class';
      case ScheduleEventType.exam:
        return 'Exam';
      case ScheduleEventType.lab:
        return 'Lab';
      case ScheduleEventType.study:
        return 'Study';
      case ScheduleEventType.other:
        return 'Event';
    }
  }
}

/// Represents an assignment from ROCIs-Schedule
class AssignmentData {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final DateTime dueDate;
  final bool isCompleted;
  final int priority; // 0=low, 1=medium, 2=high
  final Color? courseColor; // Populated from course lookup

  AssignmentData({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.isCompleted,
    required this.priority,
    this.courseColor,
  });

  factory AssignmentData.fromMap(Map<String, dynamic> map, {Color? courseColor}) {
    return AssignmentData(
      id: map['id'] ?? '',
      courseId: map['courseId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dueDate: DateTime.parse(map['dueDate']),
      isCompleted: map['isCompleted'] == 1 || map['isCompleted'] == true,
      priority: map['priority'] ?? 1,
      courseColor: courseColor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'priority': priority,
    };
  }

  /// Get priority name
  String get priorityName {
    switch (priority) {
      case 0:
        return 'Low';
      case 1:
        return 'Medium';
      case 2:
        return 'High';
      default:
        return 'Medium';
    }
  }
}
