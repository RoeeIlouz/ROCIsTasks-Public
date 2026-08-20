import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:rocis_tasks/core/services/logger_service.dart';

class TimezoneService extends ChangeNotifier {
  static const String _prefKey = 'app_selected_timezone';
  static const String autoTimezoneValue = 'auto';

  static bool _tzDataInitialized = false;
  static void _ensureInitialized() {
    if (!_tzDataInitialized) {
      try {
        tz_data.initializeTimeZones();
        _tzDataInitialized = true;
      } catch (_) {}
    }
  }

  String? _selectedTimezone;
  String _currentTimezone = 'UTC';
  bool _isAuto = true;

  String get currentTimezone => _currentTimezone;
  String? get selectedTimezone => _selectedTimezone;
  bool get isAuto => _isAuto;

  static List<String> get availableTimezones {
    _ensureInitialized();
    final list = tz.timeZoneDatabase.locations.keys.toList();
    list.sort();
    return list;
  }

  Future<void> init() async {
    _ensureInitialized();
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && saved.isNotEmpty && saved != autoTimezoneValue) {
        if (tz.timeZoneDatabase.locations.containsKey(saved)) {
          _selectedTimezone = saved;
          _isAuto = false;
          _currentTimezone = saved;
          tz.setLocalLocation(tz.getLocation(saved));
          AppLogger.info('Loaded manual timezone: $saved', tag: 'Timezone');
          return;
        }
      }

      // Auto mode
      _isAuto = true;
      _selectedTimezone = null;
      await _detectAndApplyDeviceTimezone();
    } catch (e) {
      AppLogger.warning('Failed to initialize TimezoneService: $e', tag: 'Timezone');
    }
  }

  Future<void> _detectAndApplyDeviceTimezone() async {
    String detectedTz = 'UTC';
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone().timeout(
        const Duration(seconds: 2),
      );
      detectedTz = tzInfo.identifier;
    } catch (e) {
      AppLogger.warning('Could not get local device timezone: $e', tag: 'Timezone');
    }

    if (tz.timeZoneDatabase.locations.containsKey(detectedTz)) {
      _currentTimezone = detectedTz;
      tz.setLocalLocation(tz.getLocation(detectedTz));
    } else {
      _currentTimezone = 'UTC';
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    AppLogger.info('Applied device timezone: $_currentTimezone', tag: 'Timezone');
  }

  Future<void> setTimezone(String? timezone) async {
    final prefs = await SharedPreferences.getInstance();
    if (timezone == null || timezone.isEmpty || timezone == autoTimezoneValue) {
      _isAuto = true;
      _selectedTimezone = null;
      await prefs.setString(_prefKey, autoTimezoneValue);
      await _detectAndApplyDeviceTimezone();
    } else {
      if (tz.timeZoneDatabase.locations.containsKey(timezone)) {
        _isAuto = false;
        _selectedTimezone = timezone;
        _currentTimezone = timezone;
        tz.setLocalLocation(tz.getLocation(timezone));
        await prefs.setString(_prefKey, timezone);
        AppLogger.info('Updated timezone to: $timezone', tag: 'Timezone');
      }
    }
    notifyListeners();
  }

  String formatTimezoneOffset(String tzName) {
    _ensureInitialized();
    try {
      final loc = tz.getLocation(tzName);
      final now = tz.TZDateTime.now(loc);
      final offset = now.timeZoneOffset;
      final hours = offset.inHours;
      final minutes = (offset.inMinutes % 60).abs();
      final sign = hours >= 0 ? '+' : '-';
      final hStr = hours.abs().toString().padLeft(2, '0');
      final mStr = minutes.toString().padLeft(2, '0');
      return 'UTC$sign$hStr:$mStr';
    } catch (_) {
      return 'UTC';
    }
  }
}
