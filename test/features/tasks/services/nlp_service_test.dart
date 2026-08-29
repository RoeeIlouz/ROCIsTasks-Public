import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/features/tasks/services/nlp_service.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';

void main() {
  group('NlpService', () {
    group('parse', () {
      test('should return empty result for empty string', () {
        final result = NlpService.parse('');
        expect(result.title, '');
        expect(result.dueDate, isNull);
        expect(result.hasTime, false);
      });

      test('should parse plain text without date', () {
        final result = NlpService.parse('Buy groceries');
        expect(result.title, 'Buy groceries');
        expect(result.dueDate, isNull);
        expect(result.hasTime, false);
      });

      test('should parse "today"', () {
        final result = NlpService.parse('Call dentist today');
        final now = DateTime.now();
        expect(result.title, 'Call dentist');
        expect(result.dueDate, isNotNull);
        expect(result.dueDate!.year, now.year);
        expect(result.dueDate!.month, now.month);
        expect(result.dueDate!.day, now.day);
      });

      test('should parse "tomorrow"', () {
        final result = NlpService.parse('Submit report tomorrow');
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(result.title, 'Submit report');
        expect(result.dueDate, isNotNull);
        expect(result.dueDate!.year, tomorrow.year);
        expect(result.dueDate!.month, tomorrow.month);
        expect(result.dueDate!.day, tomorrow.day);
      });

      test('should parse day of week "friday"', () {
        final result = NlpService.parse('Team meeting friday');
        final now = DateTime.now();
        expect(result.title, 'Team meeting');
        expect(result.dueDate, isNotNull);
        // Friday = weekday 5
        int targetDay = 5;
        int daysUntil = targetDay - now.weekday;
        if (daysUntil <= 0) daysUntil += 7;
        final expected = now.add(Duration(days: daysUntil));
        expect(result.dueDate!.day, expected.day);
      });

      test('should parse time "at 5pm"', () {
        final result = NlpService.parse('Review PR at 5pm');
        expect(result.title, 'Review PR');
        expect(result.hasTime, true);
        expect(result.dueDate, isNotNull);
        expect(result.dueDate!.hour, 17);
        expect(result.dueDate!.minute, 0);
      });

      test('should parse time "at 2:30pm"', () {
        final result = NlpService.parse('Standup at 2:30pm');
        expect(result.title, 'Standup');
        expect(result.hasTime, true);
        expect(result.dueDate!.hour, 14);
        expect(result.dueDate!.minute, 30);
      });

      test('should parse time "at 9am"', () {
        final result = NlpService.parse('Morning sync at 9am');
        expect(result.title, 'Morning sync');
        expect(result.hasTime, true);
        expect(result.dueDate!.hour, 9);
      });

      test('should parse 24-hour time "at 18:00"', () {
        final result = NlpService.parse('Dinner at 18:00');
        expect(result.title, 'Dinner');
        expect(result.hasTime, true);
        expect(result.dueDate!.hour, 18);
      });

      test('should parse combined date and time', () {
        final result = NlpService.parse('Meeting tomorrow at 3pm');
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(result.title, 'Meeting');
        expect(result.dueDate, isNotNull);
        expect(result.dueDate!.year, tomorrow.year);
        expect(result.dueDate!.day, tomorrow.day);
        expect(result.dueDate!.hour, 15);
        expect(result.hasTime, true);
      });

      test('should trim extra whitespace from title', () {
        final result = NlpService.parse('  Buy milk  ');
        expect(result.title, 'Buy milk');
      });

      test('should handle "noon" as 12pm', () {
        final result = NlpService.parse('Lunch at 12pm');
        expect(result.title, 'Lunch');
        expect(result.dueDate!.hour, 12);
      });

      test('should handle "midnight" as 0am', () {
        final result = NlpService.parse('Deadline at 12am');
        expect(result.title, 'Deadline');
        expect(result.dueDate!.hour, 0);
      });

      test('should be case insensitive', () {
        final result = NlpService.parse('TASK TODAY');
        expect(result.title, 'TASK');
        expect(result.dueDate, isNotNull);
      });

      test(
        'should parse priority bangs (!high, !urgent, !medium, !low, !1)',
        () {
          expect(NlpService.parse('Fix bug !high').priority, TaskPriority.high);
          expect(NlpService.parse('Fix bug !high').title, 'Fix bug');

          expect(
            NlpService.parse('Deploy release !urgent').priority,
            TaskPriority.high,
          );
          expect(
            NlpService.parse('Update docs !medium').priority,
            TaskPriority.medium,
          );
          expect(
            NlpService.parse('Water plants !low').priority,
            TaskPriority.low,
          );
          expect(
            NlpService.parse('Write tests !1').priority,
            TaskPriority.high,
          );
        },
      );

      test('should parse p1, p2, p3 shortcut codes', () {
        expect(NlpService.parse('Call client p1').priority, TaskPriority.high);
        expect(
          NlpService.parse('Review spec p2').priority,
          TaskPriority.medium,
        );
        expect(NlpService.parse('Clean inbox p3').priority, TaskPriority.low);
      });

      test('should parse category hashtags without categories list', () {
        final result = NlpService.parse('Buy milk #shopping');
        expect(result.title, 'Buy milk');
        expect(result.categoryName, 'shopping');
        expect(result.categoryId, isNull);
      });

      test('should match category hashtag with available categories', () {
        final categories = [
          Category(
            id: 'cat-1',
            name: 'Work',
            colorValue: 0xFF4285F4,
            iconCode: 0,
          ),
          Category(
            id: 'cat-2',
            name: 'Personal',
            colorValue: 0xFF0F9D58,
            iconCode: 0,
          ),
        ];

        final result = NlpService.parse(
          'Deploy backend #work !high tomorrow at 4pm',
          categories: categories,
        );

        expect(result.title, 'Deploy backend');
        expect(result.categoryId, 'cat-1');
        expect(result.priority, TaskPriority.high);
        expect(result.dueDate, isNotNull);
        expect(result.hasTime, true);
      });

      test(
        'should parse relative dates ("tonight", "in 3 days", "next monday")',
        () {
          final tonightResult = NlpService.parse('Watch movie tonight');
          expect(tonightResult.title, 'Watch movie');
          expect(tonightResult.dueDate, isNotNull);
          expect(tonightResult.dueDate!.hour, 20);

          final inDaysResult = NlpService.parse('Doctor visit in 3 days');
          final in3Days = DateTime.now().add(const Duration(days: 3));
          expect(inDaysResult.title, 'Doctor visit');
          expect(inDaysResult.dueDate!.day, in3Days.day);
        },
      );
    });
  });
}
