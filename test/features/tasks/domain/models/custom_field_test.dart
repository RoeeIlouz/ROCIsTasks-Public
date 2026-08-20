import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';

void main() {
  group('TaskCustomField Model', () {
    group('constructor', () {
      test('should create custom field with required properties', () {
        final field = TaskCustomField(
          type: CustomFieldType.contact,
          label: 'Phone',
          value: '+1234567890',
        );

        expect(field.type, CustomFieldType.contact);
        expect(field.label, 'Phone');
        expect(field.value, '+1234567890');
        expect(field.id, isNotEmpty);
      });

      test('should generate unique IDs', () {
        final f1 = TaskCustomField(
          type: CustomFieldType.location,
          label: 'Office',
          value: 'NYC',
        );
        final f2 = TaskCustomField(
          type: CustomFieldType.location,
          label: 'Office',
          value: 'NYC',
        );
        expect(f1.id, isNot(equals(f2.id)));
      });

      test('should accept custom ID', () {
        final field = TaskCustomField(
          id: 'custom-cf-id',
          type: CustomFieldType.url,
          label: 'Website',
          value: 'https://rocis.io',
        );
        expect(field.id, 'custom-cf-id');
      });
    });

    group('copyWith', () {
      test('should copy unchanged', () {
        final field = TaskCustomField(
          id: '1',
          type: CustomFieldType.contact,
          label: 'Email',
          value: 'test@example.com',
        );
        final copy = field.copyWith();
        expect(copy.id, '1');
        expect(copy.type, CustomFieldType.contact);
        expect(copy.label, 'Email');
        expect(copy.value, 'test@example.com');
      });

      test('should copy with updated values', () {
        final field = TaskCustomField(
          id: '1',
          type: CustomFieldType.text,
          label: 'Old',
          value: '123',
        );
        final copy = field.copyWith(
          type: CustomFieldType.location,
          label: 'New Location',
          value: 'Paris, France',
        );
        expect(copy.id, '1');
        expect(copy.type, CustomFieldType.location);
        expect(copy.label, 'New Location');
        expect(copy.value, 'Paris, France');
      });
    });

    group('toMap / fromMap', () {
      test('should serialize and deserialize correctly', () {
        final field = TaskCustomField(
          id: 'cf-100',
          type: CustomFieldType.location,
          label: 'Meeting Place',
          value: 'Times Square',
        );

        final map = field.toMap();
        final restored = TaskCustomField.fromMap(map);

        expect(restored.id, 'cf-100');
        expect(restored.type, CustomFieldType.location);
        expect(restored.label, 'Meeting Place');
        expect(restored.value, 'Times Square');
      });

      test('should handle string type name fromMap', () {
        final map = {
          'id': 'cf-200',
          'type': 'url',
          'label': 'Docs',
          'value': 'https://docs.flutter.dev',
        };

        final restored = TaskCustomField.fromMap(map);
        expect(restored.type, CustomFieldType.url);
        expect(restored.label, 'Docs');
        expect(restored.value, 'https://docs.flutter.dev');
      });

      test('should fallback gracefully for unknown type', () {
        final map = {
          'id': 'cf-300',
          'type': 999,
          'label': 'Note',
          'value': 'Some value',
        };

        final restored = TaskCustomField.fromMap(map);
        expect(restored.type, CustomFieldType.text);
      });
    });

    group('equality', () {
      test('should equal another instance with identical properties', () {
        final f1 = TaskCustomField(
          id: 'fixed-id',
          type: CustomFieldType.contact,
          label: 'Phone',
          value: '12345',
        );
        final f2 = TaskCustomField(
          id: 'fixed-id',
          type: CustomFieldType.contact,
          label: 'Phone',
          value: '12345',
        );

        expect(f1, equals(f2));
        expect(f1.hashCode, equals(f2.hashCode));
      });
    });
  });
}
