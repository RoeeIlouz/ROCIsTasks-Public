import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarColorService', () {
    late CalendarColorService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = CalendarColorService();
      await service.init();
    });

    test('initializes with default colors', () {
      expect(service.taskColor, CalendarColorService.defaultTaskColor);
      expect(service.googleColor, CalendarColorService.defaultGoogleColor);
      expect(service.scheduleColor, CalendarColorService.defaultScheduleColor);
      expect(
        service.assignmentColor,
        CalendarColorService.defaultAssignmentColor,
      );
    });

    test(
      'returns native color by default when no subcalendar override exists',
      () {
        const nativeColor = Color(0xFF039BE5);
        final effective = service.getEffectiveSubcalendarColor(
          'work@group.calendar.google.com',
          nativeColor: nativeColor,
        );
        expect(effective, nativeColor);
        expect(
          service.hasCustomSubcalendarColor('work@group.calendar.google.com'),
          isFalse,
        );
      },
    );

    test(
      'falls back to global googleColor when both subcalendar override and native color are missing',
      () {
        final effective = service.getEffectiveSubcalendarColor('unknown_id');
        expect(effective, service.googleColor);
      },
    );

    test('sets, persists, and retrieves subcalendar color override', () async {
      const customColor = Color(0xFFE91E63);
      const calId = 'school@group.calendar.google.com';

      await service.setSubcalendarColor(calId, customColor);

      expect(service.hasCustomSubcalendarColor(calId), isTrue);
      expect(service.getSubcalendarColor(calId), customColor);
      expect(
        service.getEffectiveSubcalendarColor(
          calId,
          nativeColor: const Color(0xFF00FF00),
        ),
        customColor,
      );

      // Verify re-initialization from SharedPreferences
      final reloadedService = CalendarColorService();
      await reloadedService.init();
      expect(reloadedService.hasCustomSubcalendarColor(calId), isTrue);
      expect(reloadedService.getSubcalendarColor(calId), customColor);
    });

    test('resets subcalendar color to native default', () async {
      const customColor = Color(0xFFFF9800);
      const calId = 'family@group.calendar.google.com';
      const nativeColor = Color(0xFF4CAF50);

      await service.setSubcalendarColor(calId, customColor);
      expect(
        service.getEffectiveSubcalendarColor(calId, nativeColor: nativeColor),
        customColor,
      );

      await service.resetSubcalendarColor(calId);
      expect(service.hasCustomSubcalendarColor(calId), isFalse);
      expect(
        service.getEffectiveSubcalendarColor(calId, nativeColor: nativeColor),
        nativeColor,
      );
    });

    test(
      'resets all colors to defaults including subcalendar overrides',
      () async {
        await service.setTaskColor(const Color(0xFF112233));
        await service.setGoogleColor(const Color(0xFF445566));
        await service.setSubcalendarColor('cal1', const Color(0xFF778899));

        await service.resetToDefaults();

        expect(service.taskColor, CalendarColorService.defaultTaskColor);
        expect(service.googleColor, CalendarColorService.defaultGoogleColor);
        expect(service.hasCustomSubcalendarColor('cal1'), isFalse);
      },
    );
  });
}
