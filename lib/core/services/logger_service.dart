import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:rocis_tasks/core/config/app_config.dart';

enum LogLevel { info, warning, error, critical }

/// Structured logging service for production monitoring
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  /// Log an info message
  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// Log a warning message
  static void warning(String message, {String? tag, Object? error, StackTrace? stack}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stack: stack);
  }

  /// Log an error message (sent to monitoring)
  static void error(String message, {String? tag, Object? error, StackTrace? stack}) {
    _log(LogLevel.error, message, tag: tag, error: error, stack: stack);
  }

  /// Log a critical error (sent to monitoring as fatal)
  static void critical(String message, {String? tag, Object? error, StackTrace? stack}) {
    _log(LogLevel.critical, message, tag: tag, error: error, stack: stack);
  }

  static void _log(LogLevel level, String message, {String? tag, Object? error, StackTrace? stack}) {
    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag] ' : '';
    final logMessage = '[$timestamp] [${level.name.toUpperCase()}] $tagStr$message';

    // 1. Console Output (only in debug or if enabled)
    if (kDebugMode || AppConfig.enableDebugLogging) {
      debugPrint(logMessage);
      if (error != null) debugPrint('Error Detail: $error');
      if (stack != null && level.index >= LogLevel.error.index) {
        debugPrint('Stack Trace:\n$stack');
      }
    }

    // 2. Monitoring (Crashlytics)
    if (AppConfig.enableCrashReporting && level.index >= LogLevel.warning.index) {
      final crashlytics = FirebaseCrashlytics.instance;
      
      // Add log message to Crashlytics log breadcrumbs
      crashlytics.log(logMessage);

      if (level.index >= LogLevel.error.index && error != null) {
        crashlytics.recordError(
          error,
          stack, 
          reason: message,
          fatal: level == LogLevel.critical,
          printDetails: false, // We already printed to console
        );
      }
    }
  }
}
