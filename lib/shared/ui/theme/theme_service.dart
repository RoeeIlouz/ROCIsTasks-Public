import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  bool _useMaterialTheme = true;
  bool _useAmoledTheme = false;
  bool _use24HourFormat = false;
  bool _autoRemoveNlpDates = true;
  Locale? _locale;

  ThemeMode get themeMode => _themeMode;
  bool get useMaterialTheme => _useMaterialTheme;
  bool get useAmoledTheme => _useAmoledTheme;
  bool get use24HourFormat => _use24HourFormat;
  bool get autoRemoveNlpDates => _autoRemoveNlpDates;
  Locale? get locale => _locale;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Load ThemeMode
    final themeModeIndex = prefs.getInt('theme_mode');
    if (themeModeIndex != null) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }
    // Load Material Theme
    _useMaterialTheme = prefs.getBool('use_material_theme') ?? true;
    // Load AMOLED Theme
    _useAmoledTheme = prefs.getBool('use_amoled_theme') ?? false;
    // Load 24h format
    _use24HourFormat = prefs.getBool('use_24h_format') ?? false;
    // Load NLP settings
    _autoRemoveNlpDates = prefs.getBool('auto_remove_nlp_dates') ?? true;
    // Load Locale
    final languageCode = prefs.getString('language_code');
    if (languageCode != null) {
      _locale = Locale(languageCode);
    }
    notifyListeners();
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', _themeMode.index);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', _themeMode.index);
  }

  Future<void> toggleMaterialTheme(bool value) async {
    _useMaterialTheme = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_material_theme', _useMaterialTheme);
  }

  Future<void> toggleAmoledTheme(bool value) async {
    _useAmoledTheme = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_amoled_theme', _useAmoledTheme);
  }

  Future<void> toggle24HourFormat(bool value) async {
    _use24HourFormat = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_24h_format', _use24HourFormat);
  }

  Future<void> toggleAutoRemoveNlpDates(bool value) async {
    _autoRemoveNlpDates = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_remove_nlp_dates', _autoRemoveNlpDates);
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale != null) {
      await prefs.setString('language_code', locale.languageCode);
    } else {
      await prefs.remove('language_code');
    }
  }
}
