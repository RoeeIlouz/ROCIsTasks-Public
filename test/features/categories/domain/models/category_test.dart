import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';

void main() {
  group('Category Model', () {
    group('constructor', () {
      test('should create category with required fields', () {
        final cat = Category(
          name: 'Work',
          colorValue: 0xFF2196F3,
          iconCode: 0xe06f,
        );
        expect(cat.name, 'Work');
        expect(cat.colorValue, 0xFF2196F3);
        expect(cat.iconCode, 0xe06f);
        expect(cat.isPrivate, false);
        expect(cat.id, isNotEmpty);
      });

      test('should generate unique IDs', () {
        final c1 = Category(name: 'A', colorValue: 0, iconCode: 0);
        final c2 = Category(name: 'B', colorValue: 0, iconCode: 0);
        expect(c1.id, isNot(equals(c2.id)));
      });

      test('should accept custom ID', () {
        final cat = Category(
          id: 'cat-1',
          name: 'Personal',
          colorValue: 0xFFFF0000,
          iconCode: 1,
        );
        expect(cat.id, 'cat-1');
      });

      test('should default isPrivate to false', () {
        final cat = Category(name: 'X', colorValue: 0, iconCode: 0);
        expect(cat.isPrivate, false);
      });
    });

    group('toMap / fromMap', () {
      test('should roundtrip', () {
        final cat = Category(
          id: 'cat-rt',
          name: 'Health',
          colorValue: 0xFF4CAF50,
          iconCode: 0xe559,
          isPrivate: true,
        );
        final map = cat.toMap();
        final restored = Category.fromMap(map);

        expect(restored.id, 'cat-rt');
        expect(restored.name, 'Health');
        expect(restored.colorValue, 0xFF4CAF50);
        expect(restored.iconCode, 0xe559);
        expect(restored.isPrivate, true);
      });

      test('should default isPrivate to false', () {
        final map = {'id': 'x', 'name': 'Y', 'colorValue': 0, 'iconCode': 0};
        final cat = Category.fromMap(map);
        expect(cat.isPrivate, false);
      });

      test('should default name to empty', () {
        final map = {'id': 'x', 'colorValue': 0, 'iconCode': 0};
        final cat = Category.fromMap(map);
        expect(cat.name, '');
      });

      test('should default colorValue to 0xFF2196F3', () {
        final map = {'id': 'x', 'name': 'Y', 'iconCode': 0};
        final cat = Category.fromMap(map);
        expect(cat.colorValue, 0xFF2196F3);
      });

      test('should default iconCode to 0', () {
        final map = {'id': 'x', 'name': 'Y', 'colorValue': 0};
        final cat = Category.fromMap(map);
        expect(cat.iconCode, 0);
      });
    });
  });
}
