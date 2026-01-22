// This is a basic Flutter widget test for ROCI's Tasks app.

import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/validation_service.dart';

void main() {
  group('ValidationService Tests', () {
    test('should validate task title correctly', () {
      expect(ValidationService.validateTaskTitle('Valid title'), isNull);
      expect(ValidationService.validateTaskTitle(''), isNotNull);
      expect(ValidationService.validateTaskTitle(null), isNotNull);
    });

    test('should validate task description correctly', () {
      expect(
        ValidationService.validateTaskDescription('Valid description'),
        isNull,
      );
      expect(ValidationService.validateTaskDescription(null), isNull);
    });

    test('should sanitize text correctly', () {
      expect(
        ValidationService.sanitizeText('  hello  world  '),
        equals('hello world'),
      );
    });

    test('should detect harmful content', () {
      expect(
        ValidationService.containsHarmfulContent(
          '<script>alert("xss")</script>',
        ),
        isTrue,
      );
      expect(ValidationService.containsHarmfulContent('Safe content'), isFalse);
    });
  });
}
