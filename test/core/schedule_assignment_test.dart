import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/models/schedule_assignment.dart';
import 'package:rocis_tasks/core/services/schedule_firestore_service.dart';

/// What `documents.list` returns for an assignment that Schedule saved with a
/// lecture link and two attachments.
Map<String, dynamic> _restFields() => {
  'id': {'stringValue': 'a1'},
  'courseId': {'stringValue': 'c1'},
  'title': {'stringValue': 'Problem set 4'},
  'description': {'stringValue': 'Questions 1-5'},
  'dueDate': {'stringValue': '2026-12-01T00:00:00.000'},
  'isCompleted': {'integerValue': '0'},
  'priority': {'integerValue': '2'},
  'lectureEventId': {'stringValue': 'e9'},
  'lectureDate': {'stringValue': '2026-11-03T00:00:00.000'},
  'attachments': {
    'arrayValue': {
      'values': [
        {
          'mapValue': {
            'fields': {
              'id': {'stringValue': 'f1'},
              'name': {'stringValue': 'board.jpg'},
              'mime': {'stringValue': 'image/jpeg'},
              'size': {'integerValue': '654321'},
              'gz': {'booleanValue': false},
            },
          },
        },
        {
          'mapValue': {
            'fields': {
              'id': {'stringValue': 'f2'},
              'name': {'stringValue': 'notes.txt'},
              'mime': {'stringValue': 'text/plain'},
              'size': {'integerValue': '1200'},
              'gz': {'booleanValue': true},
            },
          },
        },
      ],
    },
  },
};

void main() {
  group('decodeFirestoreFields', () {
    test('decodes arrays of maps instead of dropping them', () {
      final decoded = ScheduleFirestoreService.decodeFirestoreFields(
        _restFields(),
      );
      final attachments = decoded['attachments'] as List;
      expect(attachments, hasLength(2));
      expect((attachments.first as Map)['name'], 'board.jpg');
      expect((attachments.last as Map)['gz'], true);
    });

    test('keeps bytes as the base64 string', () {
      final decoded = ScheduleFirestoreService.decodeFirestoreFields({
        'data': {'bytesValue': 'AAEC'},
      });
      expect(decoded['data'], 'AAEC');
    });

    test('still decodes arrays of primitives as before', () {
      final decoded = ScheduleFirestoreService.decodeFirestoreFields({
        'daysOfWeek': {
          'arrayValue': {
            'values': [
              {'integerValue': '1'},
              {'integerValue': '3'},
            ],
          },
        },
      });
      expect(decoded['daysOfWeek'], ['1', '3']);
    });
  });

  group('ScheduleAssignment.fromMap', () {
    test('builds from a REST document with lecture link and files', () {
      final decoded = ScheduleFirestoreService.decodeFirestoreFields(
        _restFields(),
      );
      final a = ScheduleAssignment.fromMap(
        decoded,
        course: {'name': 'Algorithms', 'code': 'CS201', 'color': 0xFF112233},
      );

      expect(a.title, 'Problem set 4');
      expect(a.courseName, 'Algorithms');
      expect(a.color, const Color(0xFF112233));
      expect(a.priority, 2);
      expect(a.isCompleted, isFalse);
      expect(a.dueDate, DateTime(2026, 12, 1));
      expect(a.hasLecture, isTrue);
      expect(a.lectureEventId, 'e9');
      expect(a.lectureDate, DateTime(2026, 11, 3));
      expect(a.attachments.map((f) => f.name), ['board.jpg', 'notes.txt']);
      expect(a.attachments.first.isImage, isTrue);
      expect(a.attachments.last.gzipped, isTrue);
    });

    test('survives a cache round trip', () {
      final decoded = ScheduleFirestoreService.decodeFirestoreFields(
        _restFields(),
      );
      final a = ScheduleAssignment.fromMap(
        decoded,
        course: {'name': 'Algorithms', 'color': 0xFF112233},
      );
      final back = ScheduleAssignment.fromMap(a.toMap());

      expect(back.courseName, 'Algorithms');
      expect(back.color, const Color(0xFF112233));
      expect(back.lectureEventId, 'e9');
      expect(back.attachments, hasLength(2));
    });

    test('reads an old document with no lecture or files', () {
      final a = ScheduleAssignment.fromMap({
        'id': 'old',
        'courseId': 'c',
        'title': 'Old',
        'dueDate': '2026-01-01T00:00:00.000',
        'isCompleted': 1,
        'priority': 1,
      });
      expect(a.hasLecture, isFalse);
      expect(a.attachments, isEmpty);
      expect(a.isCompleted, isTrue);
    });

    test('ignores a lecture id without a date', () {
      final a = ScheduleAssignment.fromMap({
        'id': 'x',
        'title': 't',
        'dueDate': '2026-01-01T00:00:00.000',
        'lectureEventId': 'e1',
      });
      expect(a.lectureEventId, isNull);
    });
  });

  group('isOverdue', () {
    final a = ScheduleAssignment.fromMap({
      'id': 'x',
      'title': 't',
      'dueDate': '2026-11-05T23:00:00.000',
      'isCompleted': 0,
    });

    test('is not overdue later on the due day', () {
      expect(a.isOverdue(DateTime(2026, 11, 5, 23, 59)), isFalse);
    });

    test('is overdue the next day', () {
      expect(a.isOverdue(DateTime(2026, 11, 6, 0, 1)), isTrue);
    });

    test('a completed assignment is never overdue', () {
      final done = ScheduleAssignment.fromMap({
        'id': 'x',
        'title': 't',
        'dueDate': '2020-01-01T00:00:00.000',
        'isCompleted': 1,
      });
      expect(done.isOverdue(DateTime(2026, 11, 6)), isFalse);
    });
  });
}
