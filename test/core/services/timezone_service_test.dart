import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:rocis_tasks/core/services/timezone_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  group('TimezoneService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initializes default state correctly', () {
      final service = TimezoneService();
      expect(service.isAuto, isTrue);
      expect(service.selectedTimezone, isNull);
    });

    test('availableTimezones returns non-empty sorted list', () {
      final timezones = TimezoneService.availableTimezones;
      expect(timezones, isNotEmpty);
      expect(timezones.contains('UTC'), isTrue);
      expect(timezones.contains('Asia/Jerusalem'), isTrue);
      expect(timezones.contains('America/New_York'), isTrue);
    });

    test('setTimezone sets explicit timezone and updates tz.local', () async {
      final service = TimezoneService();
      await service.setTimezone('America/New_York');

      expect(service.isAuto, isFalse);
      expect(service.selectedTimezone, equals('America/New_York'));
      expect(service.currentTimezone, equals('America/New_York'));
      expect(tz.local.name, equals('America/New_York'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_selected_timezone'), equals('America/New_York'));
    });

    test('setTimezone with null restores auto mode', () async {
      final service = TimezoneService();
      await service.setTimezone('Europe/London');
      expect(service.isAuto, isFalse);

      await service.setTimezone(null);
      expect(service.isAuto, isTrue);
      expect(service.selectedTimezone, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_selected_timezone'), equals('auto'));
    });

    test('formatTimezoneOffset returns valid UTC offset string', () {
      final service = TimezoneService();
      final utcOffset = service.formatTimezoneOffset('UTC');
      expect(utcOffset, equals('UTC+00:00'));

      final nyOffset = service.formatTimezoneOffset('America/New_York');
      expect(nyOffset.startsWith('UTC-'), isTrue);
    });
  });
}
