import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

/// Service to manage calendar item colors
/// Allows users to customize colors for tasks, Google Calendar events, individual subcalendars, and ROCIs Schedule events
class CalendarColorService extends ChangeNotifier {
  // Public keys for external access
  static const String keyTaskColor = 'calendar_task_color';
  static const String keyGoogleColor = 'calendar_google_color';
  static const String keyScheduleColor = 'calendar_schedule_color';
  static const String keyAssignmentColor = 'calendar_assignment_color';
  static const String keySubcalendarColorsPrefix = 'calendar_subcal_color_';

  // Default colors
  static const Color defaultTaskColor = Color(0xFF9E9E9E); // Gray
  static const Color defaultGoogleColor = Color(0xFF4285F4); // Google Blue
  static const Color defaultScheduleColor = Color(0xFF0284C7); // Sky Blue
  static const Color defaultAssignmentColor = Color(0xFFFF9800); // Orange

  // Default hex colors for widget use
  static const String defaultTaskColorHex = '#FF9E9E9E';
  static const String defaultGoogleColorHex = '#FF4285F4';
  static const String defaultScheduleColorHex = '#FF0284C7';
  static const String defaultAssignmentColorHex = '#FFFF9800';

  Color _taskColor = defaultTaskColor;
  Color _googleColor = defaultGoogleColor;
  Color _scheduleColor = defaultScheduleColor;
  Color _assignmentColor = defaultAssignmentColor;
  final Map<String, Color> _subcalendarColors = {};

  Color get taskColor => _taskColor;
  Color get googleColor => _googleColor;
  Color get scheduleColor => _scheduleColor;
  Color get assignmentColor => _assignmentColor;
  Map<String, Color> get subcalendarColors =>
      Map.unmodifiable(_subcalendarColors);

  /// Check if a subcalendar has an explicit user color override
  bool hasCustomSubcalendarColor(String calendarId) =>
      _subcalendarColors.containsKey(calendarId);

  /// Get custom subcalendar color override if present
  Color? getSubcalendarColor(String calendarId) =>
      _subcalendarColors[calendarId];

  /// Get effective color for a subcalendar:
  /// 1. Custom user override
  /// 2. Google native synced color
  /// 3. Global Google Calendar color
  Color getEffectiveSubcalendarColor(String? calendarId, {Color? nativeColor}) {
    if (calendarId != null && _subcalendarColors.containsKey(calendarId)) {
      return _subcalendarColors[calendarId]!;
    }
    if (nativeColor != null) {
      return nativeColor;
    }
    return _googleColor;
  }

  /// Initialize the service and load saved colors
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _taskColor = Color(
      prefs.getInt(keyTaskColor) ?? defaultTaskColor.toARGB32(),
    );
    _googleColor = Color(
      prefs.getInt(keyGoogleColor) ?? defaultGoogleColor.toARGB32(),
    );
    _scheduleColor = Color(
      prefs.getInt(keyScheduleColor) ?? defaultScheduleColor.toARGB32(),
    );
    _assignmentColor = Color(
      prefs.getInt(keyAssignmentColor) ?? defaultAssignmentColor.toARGB32(),
    );

    _subcalendarColors.clear();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(keySubcalendarColorsPrefix)) {
        final calId = key.substring(keySubcalendarColorsPrefix.length);
        final colorInt = prefs.getInt(key);
        if (colorInt != null) {
          _subcalendarColors[calId] = Color(colorInt);
        }
      }
    }

    notifyListeners();
  }

  /// Set the task color
  Future<void> setTaskColor(Color color) async {
    _taskColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyTaskColor, color.toARGB32());
    await _saveToWidget();
    notifyListeners();
  }

  /// Set the Google Calendar color
  Future<void> setGoogleColor(Color color) async {
    _googleColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyGoogleColor, color.toARGB32());
    await _saveToWidget();
    notifyListeners();
  }

  /// Set the ROCIs Schedule color
  Future<void> setScheduleColor(Color color) async {
    _scheduleColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyScheduleColor, color.toARGB32());
    await _saveToWidget();
    notifyListeners();
  }

  /// Set the assignment color
  Future<void> setAssignmentColor(Color color) async {
    _assignmentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyAssignmentColor, color.toARGB32());
    await _saveToWidget();
    notifyListeners();
  }

  /// Set a custom subcalendar color
  Future<void> setSubcalendarColor(String calendarId, Color color) async {
    _subcalendarColors[calendarId] = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$keySubcalendarColorsPrefix$calendarId',
      color.toARGB32(),
    );
    await _saveToWidget();
    notifyListeners();
  }

  /// Reset a subcalendar to its native Google synced color
  Future<void> resetSubcalendarColor(String calendarId) async {
    _subcalendarColors.remove(calendarId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$keySubcalendarColorsPrefix$calendarId');
    await _saveToWidget();
    notifyListeners();
  }

  /// Reset all colors to defaults
  Future<void> resetToDefaults() async {
    _taskColor = defaultTaskColor;
    _googleColor = defaultGoogleColor;
    _scheduleColor = defaultScheduleColor;
    _assignmentColor = defaultAssignmentColor;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyTaskColor);
    await prefs.remove(keyGoogleColor);
    await prefs.remove(keyScheduleColor);
    await prefs.remove(keyAssignmentColor);

    final subKeys = prefs
        .getKeys()
        .where((k) => k.startsWith(keySubcalendarColorsPrefix))
        .toList();
    for (final k in subKeys) {
      await prefs.remove(k);
    }
    _subcalendarColors.clear();

    await _saveToWidget();
    notifyListeners();
  }

  /// Save colors to widget data for native access and trigger widget update
  Future<void> _saveToWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'calendar_task_color',
        '#${_taskColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      );
      await HomeWidget.saveWidgetData<String>(
        'calendar_google_color',
        '#${_googleColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      );
      await HomeWidget.saveWidgetData<String>(
        'calendar_schedule_color',
        '#${_scheduleColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      );
      await HomeWidget.saveWidgetData<String>(
        'calendar_assignment_color',
        '#${_assignmentColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      );

      // Save subcalendar color mapping as JSON string for native widgets
      final Map<String, String> subcalHexMap = {};
      _subcalendarColors.forEach((id, color) {
        subcalHexMap[id] =
            '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
      });
      await HomeWidget.saveWidgetData<String>(
        'calendar_subcal_colors',
        jsonEncode(subcalHexMap),
      );

      // Trigger widget update to apply new colors
      await HomeWidget.updateWidget(
        name: 'FullCalendarWidgetProvider',
        iOSName: 'FullCalendarWidget',
      );
    } catch (_) {
      // Gracefully ignore errors on platforms or test environments where HomeWidget is unavailable
    }
  }

  /// Get color as hex string for widget
  String taskColorHex() =>
      '#${_taskColor.toARGB32().toRadixString(16).padLeft(8, '0')}';
  String googleColorHex() =>
      '#${_googleColor.toARGB32().toRadixString(16).padLeft(8, '0')}';
  String scheduleColorHex() =>
      '#${_scheduleColor.toARGB32().toRadixString(16).padLeft(8, '0')}';
  String assignmentColorHex() =>
      '#${_assignmentColor.toARGB32().toRadixString(16).padLeft(8, '0')}';

  /// Get color for a specific event type
  Color getColorForType(String type) {
    switch (type) {
      case 'task':
        return _taskColor;
      case 'google':
        return _googleColor;
      case 'schedule':
      case 'schedule_event':
        return _scheduleColor;
      case 'assignment':
        return _assignmentColor;
      default:
        return _taskColor;
    }
  }

  /// Get hex color for a specific event type
  String getHexColorForType(String type) {
    final color = getColorForType(type);
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
  }
}
