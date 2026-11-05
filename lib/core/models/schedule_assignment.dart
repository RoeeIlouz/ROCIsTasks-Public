import 'package:flutter/material.dart';

/// A file attached to a ROCIs Schedule assignment. Only the description lives
/// here; the bytes are fetched on demand because they can be hundreds of KB.
class ScheduleAttachment {
  final String id;
  final String name;
  final String mime;

  /// Size of the stored (compressed) bytes.
  final int size;

  /// True when the stored bytes are gzip-compressed and need inflating.
  final bool gzipped;

  const ScheduleAttachment({
    required this.id,
    required this.name,
    required this.mime,
    required this.size,
    this.gzipped = false,
  });

  bool get isImage => mime.startsWith('image/');

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'mime': mime,
    'size': size,
    'gz': gzipped,
  };

  factory ScheduleAttachment.fromMap(Map<dynamic, dynamic> map) {
    return ScheduleAttachment(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      mime: map['mime']?.toString() ?? 'application/octet-stream',
      size: (map['size'] as num?)?.toInt() ?? 0,
      gzipped: map['gz'] == true || map['gz'] == 1,
    );
  }
}

/// An assignment from ROCIs Schedule, with its course resolved and the
/// lecture it was given in.
class ScheduleAssignment {
  final String id;
  final String courseId;
  final String courseName;
  final String courseCode;
  final Color color;
  final String title;
  final String description;
  final DateTime dueDate;
  final bool isCompleted;

  /// 0 = low, 1 = medium, 2 = high.
  final int priority;

  /// The lecture (a schedule event id) this was given in, and that session's
  /// date. Both are set together or neither is.
  final String? lectureEventId;
  final DateTime? lectureDate;

  final List<ScheduleAttachment> attachments;

  const ScheduleAssignment({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.color,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.isCompleted,
    required this.priority,
    this.lectureEventId,
    this.lectureDate,
    this.attachments = const [],
  });

  bool get hasLecture => lectureEventId != null && lectureDate != null;

  /// Overdue means the due day has passed, not merely the due time.
  bool isOverdue(DateTime now) {
    if (isCompleted) return false;
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(dueDate.year, dueDate.month, dueDate.day).isBefore(today);
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'courseId': courseId,
    'courseName': courseName,
    'courseCode': courseCode,
    'courseColor': color.toARGB32(),
    'title': title,
    'description': description,
    'dueDate': dueDate.toIso8601String(),
    'isCompleted': isCompleted ? 1 : 0,
    'priority': priority,
    'lectureEventId': lectureEventId,
    'lectureDate': lectureDate?.toIso8601String(),
    'attachments': attachments.map((a) => a.toMap()).toList(),
  };

  /// Builds from a Firestore document map or from [toMap] output. [course] is
  /// the matching course document and wins over the copied course fields.
  factory ScheduleAssignment.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? course,
  }) {
    DateTime? parseDate(dynamic v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

    Color? parseColor(dynamic raw) {
      if (raw == null) return null;
      if (raw is num) return Color(raw.toInt());
      final parsed = int.tryParse(raw.toString());
      return parsed == null ? null : Color(parsed);
    }

    final lectureEventId = map['lectureEventId']?.toString();
    final lectureDate = parseDate(map['lectureDate']);
    final linked =
        lectureEventId != null &&
        lectureEventId.isNotEmpty &&
        lectureDate != null;

    final rawAttachments = map['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments
              .whereType<Map>()
              .map(ScheduleAttachment.fromMap)
              .where((a) => a.id.isNotEmpty)
              .toList()
        : <ScheduleAttachment>[];

    final rawCompleted = map['isCompleted'];
    final completed =
        rawCompleted == 1 || rawCompleted == true || rawCompleted == '1';

    return ScheduleAssignment(
      id: map['id']?.toString() ?? '',
      courseId: map['courseId']?.toString() ?? '',
      courseName:
          course?['name']?.toString() ?? map['courseName']?.toString() ?? '',
      courseCode:
          course?['code']?.toString() ?? map['courseCode']?.toString() ?? '',
      color:
          parseColor(course?['color']) ??
          parseColor(map['courseColor']) ??
          const Color(0xFF3F51B5),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      dueDate: parseDate(map['dueDate']) ?? DateTime.now(),
      isCompleted: completed,
      priority: (map['priority'] as num?)?.toInt() ?? 1,
      lectureEventId: linked ? lectureEventId : null,
      lectureDate: linked ? lectureDate : null,
      attachments: attachments,
    );
  }
}
