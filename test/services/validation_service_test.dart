import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/validation_service.dart';

void main() {
  group('ValidationService', () {
    group('validateTaskTitle', () {
      test('should return null for valid title', () {
        expect(ValidationService.validateTaskTitle('Valid title'), isNull);
      });

      test('should return error for empty title', () {
        expect(ValidationService.validateTaskTitle(''), isNotNull);
        expect(ValidationService.validateTaskTitle(null), isNotNull);
        expect(ValidationService.validateTaskTitle('   '), isNotNull);
      });

      test('should return error for title too long', () {
        final longTitle = 'a' * 101; // Exceeds max length
        expect(ValidationService.validateTaskTitle(longTitle), isNotNull);
      });
    });

    group('validateTaskDescription', () {
      test('should return null for valid description', () {
        expect(ValidationService.validateTaskDescription('Valid description'), isNull);
        expect(ValidationService.validateTaskDescription(null), isNull);
        expect(ValidationService.validateTaskDescription(''), isNull);
      });

      test('should return error for description too long', () {
        final longDescription = 'a' * 501; // Exceeds max length
        expect(ValidationService.validateTaskDescription(longDescription), isNotNull);
      });
    });

    group('validateCategoryName', () {
      test('should return null for valid category name', () {
        expect(ValidationService.validateCategoryName('Work'), isNull);
      });

      test('should return error for empty category name', () {
        expect(ValidationService.validateCategoryName(''), isNotNull);
        expect(ValidationService.validateCategoryName(null), isNotNull);
        expect(ValidationService.validateCategoryName('   '), isNotNull);
      });
    });

    group('validateDueDate', () {
      test('should return null for null date', () {
        expect(ValidationService.validateDueDate(null), isNull);
      });

      test('should return null for future date', () {
        final futureDate = DateTime.now().add(const Duration(days: 1));
        expect(ValidationService.validateDueDate(futureDate), isNull);
      });

      test('should return error for past date', () {
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        expect(ValidationService.validateDueDate(pastDate), isNotNull);
      });
    });

    group('sanitizeText', () {
      test('should trim whitespace', () {
        expect(ValidationService.sanitizeText('  hello  '), equals('hello'));
      });

      test('should replace multiple spaces with single space', () {
        expect(ValidationService.sanitizeText('hello    world'), equals('hello world'));
      });
    });

    group('containsHarmfulContent', () {
      test('should detect script tags', () {
        expect(ValidationService.containsHarmfulContent('<script>alert("xss")</script>'), isTrue);
      });

      test('should detect javascript protocol', () {
        expect(ValidationService.containsHarmfulContent('javascript:alert("xss")'), isTrue);
      });

      test('should return false for safe content', () {
        expect(ValidationService.containsHarmfulContent('This is safe content'), isFalse);
      });
    });
  });
}