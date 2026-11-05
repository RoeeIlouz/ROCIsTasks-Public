import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/models/schedule_assignment.dart';
import 'package:rocis_tasks/core/services/widget_data_service.dart';

ScheduleAssignment _assignment({
  String course = 'Algorithms',
  String title = 'HW 3',
}) => ScheduleAssignment(
  id: 'a1',
  courseId: 'c1',
  courseName: course,
  courseCode: 'CS101',
  color: const Color(0xFF3F51B5),
  title: title,
  description: '',
  dueDate: DateTime(2026, 11, 8, 23, 59),
  isCompleted: false,
  priority: 1,
);

void main() {
  group('WidgetDataService.assignmentTitle', () {
    test('prefixes the course like class titles', () {
      expect(
        WidgetDataService.assignmentTitle(_assignment(), 'No Title'),
        'Algorithms: HW 3',
      );
    });

    test('falls back to the title when there is no course', () {
      expect(
        WidgetDataService.assignmentTitle(_assignment(course: ''), 'No Title'),
        'HW 3',
      );
    });

    test('uses the fallback when nothing is named', () {
      expect(
        WidgetDataService.assignmentTitle(
          _assignment(course: '', title: ' '),
          'No Title',
        ),
        'No Title',
      );
    });
  });
}
