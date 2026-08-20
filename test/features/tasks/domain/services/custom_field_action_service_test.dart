import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/features/tasks/domain/services/custom_field_action_service.dart';

void main() {
  group('CustomFieldActionService', () {
    test('getIcon returns appropriate icon for each type', () {
      expect(
        CustomFieldActionService.getIcon(CustomFieldType.contact, '+12345'),
        Icons.phone_outlined,
      );
      expect(
        CustomFieldActionService.getIcon(CustomFieldType.contact, 'user@example.com'),
        Icons.alternate_email_rounded,
      );
      expect(
        CustomFieldActionService.getIcon(CustomFieldType.location),
        Icons.location_on_outlined,
      );
      expect(
        CustomFieldActionService.getIcon(CustomFieldType.url),
        Icons.link_rounded,
      );
      expect(
        CustomFieldActionService.getIcon(CustomFieldType.text),
        Icons.notes_rounded,
      );
    });

    test('getActionIcon returns appropriate action icon', () {
      expect(
        CustomFieldActionService.getActionIcon(CustomFieldType.contact, '123'),
        Icons.phone_in_talk_rounded,
      );
      expect(
        CustomFieldActionService.getActionIcon(CustomFieldType.contact, 'hi@mail.com'),
        Icons.mail_outline_rounded,
      );
      expect(
        CustomFieldActionService.getActionIcon(CustomFieldType.location),
        Icons.directions_outlined,
      );
      expect(
        CustomFieldActionService.getActionIcon(CustomFieldType.url),
        Icons.open_in_new_rounded,
      );
      expect(
        CustomFieldActionService.getActionIcon(CustomFieldType.text),
        Icons.copy_rounded,
      );
    });
  });
}
