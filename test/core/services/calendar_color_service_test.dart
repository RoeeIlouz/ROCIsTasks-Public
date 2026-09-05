import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/calendar_color_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarColorService', () {
    late CalendarColorService colorService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      colorService = CalendarColorService();
      await colorService.init();
    });

    test('initializes with default colors and empty subcalendars', () {
      expect(colorService.taskColor, CalendarColorService.defaultTaskColor);
      expect(colorService.googleColor, CalendarColorService.defaultGoogleColor);
      expect(colorService.subcalendarColors.isEmpty, isTrue);
    });

    test('getEffectiveSubcalendarColor falls back correctly', () async {
      const calId = 'work_cal_123';
      const nativeColor = Color(0xFF00FF00);

      // 1. Without native color or custom color -> falls back to googleColor
      expect(
        colorService.getEffectiveSubcalendarColor(calId),
        colorService.googleColor,
      );

      // 2. With native color, no custom color -> uses native color
      expect(
        colorService.getEffectiveSubcalendarColor(
          calId,
          nativeColor: nativeColor,
        ),
        nativeColor,
      );

      // 3. With custom color override -> uses custom color over native color
      const customColor = Color(0xFFFF0055);
      await colorService.setSubcalendarColor(calId, customColor);

      expect(colorService.hasCustomSubcalendarColor(calId), isTrue);
      expect(colorService.getSubcalendarColor(calId), customColor);
      expect(
        colorService.getEffectiveSubcalendarColor(
          calId,
          nativeColor: nativeColor,
        ),
        customColor,
      );
    });

    test('resetSubcalendarColor removes override', () async {
      const calId = 'personal_cal_456';
      const customColor = Color(0xFF9C27B0);
      const nativeColor = Color(0xFF4285F4);

      await colorService.setSubcalendarColor(calId, customColor);
      expect(colorService.hasCustomSubcalendarColor(calId), isTrue);

      await colorService.resetSubcalendarColor(calId);
      expect(colorService.hasCustomSubcalendarColor(calId), isFalse);
      expect(
        colorService.getEffectiveSubcalendarColor(
          calId,
          nativeColor: nativeColor,
        ),
        nativeColor,
      );
    });

    test('resetToDefaults clears all subcalendar overrides', () async {
      await colorService.setSubcalendarColor('cal_1', const Color(0xFF111111));
      await colorService.setSubcalendarColor('cal_2', const Color(0xFF222222));
      expect(colorService.subcalendarColors.length, 2);

      await colorService.resetToDefaults();
      expect(colorService.subcalendarColors.isEmpty, isTrue);
      expect(colorService.hasCustomSubcalendarColor('cal_1'), isFalse);
      expect(colorService.hasCustomSubcalendarColor('cal_2'), isFalse);
    });

    test(
      'reloads subcalendar colors from SharedPreferences during init',
      () async {
        SharedPreferences.setMockInitialValues({
          '${CalendarColorService.keySubcalendarColorsPrefix}school':
              0xFF123456,
        });

        final newService = CalendarColorService();
        await newService.init();

        expect(newService.hasCustomSubcalendarColor('school'), isTrue);
        expect(
          newService.getSubcalendarColor('school')?.toARGB32(),
          0xFF123456,
        );
      },
    );
  });
}
