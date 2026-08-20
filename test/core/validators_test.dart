import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/validation/validators.dart';

void main() {
  group('Validators', () {
    group('validateTaskTitle', () {
      test('should return error for null value', () {
        expect(
          Validators.validateTaskTitle(null, null),
          'Task title is required',
        );
      });

      test('should return error for empty string', () {
        expect(
          Validators.validateTaskTitle('', null),
          'Task title is required',
        );
      });

      test('should return error for whitespace only string', () {
        expect(
          Validators.validateTaskTitle('   ', null),
          'Task title is required',
        );
      });

      test('should return error for title longer than 100 characters', () {
        final longTitle = 'A' * 101;
        expect(
          Validators.validateTaskTitle(longTitle, null),
          'Task title must be less than 100 characters',
        );
      });

      test('should return null for valid title', () {
        expect(Validators.validateTaskTitle('Valid Task Title', null), isNull);
      });
    });

    group('validateCategoryName', () {
      test('should return error for null value', () {
        expect(
          Validators.validateCategoryName(null, null),
          'Category name is required',
        );
      });

      test('should return error for empty string', () {
        expect(
          Validators.validateCategoryName('', null),
          'Category name is required',
        );
      });

      test('should return error for whitespace only string', () {
        expect(
          Validators.validateCategoryName('   ', null),
          'Category name is required',
        );
      });

      test('should return error for name longer than 30 characters', () {
        final longName = 'A' * 31;
        expect(
          Validators.validateCategoryName(longName, null),
          'Category name must be less than 30 characters',
        );
      });

      test('should return null for valid category name', () {
        expect(Validators.validateCategoryName('Work', null), isNull);
      });
    });
  });
}
