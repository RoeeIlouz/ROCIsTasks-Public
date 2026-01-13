import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:rocis_tasks/core/config/app_config.dart';

/// Global error handling service
class ErrorService {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  static FirebaseCrashlytics? _crashlytics;
  static FirebaseAnalytics? _analytics;

  /// Initialize global error handling
  static void initialize() {
    // Initialize Firebase services if available
    try {
      if (AppConfig.enableCrashReporting) {
        _crashlytics = FirebaseCrashlytics.instance;
        _analytics = FirebaseAnalytics.instance;
      }
    } catch (e) {
      debugPrint('Firebase services not available: $e');
    }

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError(
        'Flutter Error',
        details.exception,
        details.stack,
        details.context?.toString(),
      );
    };

    // Catch async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError('Platform Error', error, stack);
      return true;
    };
  }

  /// Log error with context
  static void _logError(
    String type,
    Object error,
    StackTrace? stack, [
    String? context,
  ]) {
    if (AppConfig.enableDebugLogging) {
      debugPrint('=== $type ===');
      debugPrint('Error: $error');
      if (context != null) debugPrint('Context: $context');
      if (stack != null) debugPrint('Stack: $stack');
      debugPrint('================');
    }

    // Send to crash reporting service in production
    if (AppConfig.enableCrashReporting && _crashlytics != null) {
      try {
        _crashlytics!.recordError(
          error,
          stack,
          fatal: false,
          information: context != null ? <Object>[context] : <Object>[],
        );
      } catch (e) {
        debugPrint('Failed to record error to Crashlytics: $e');
      }
    }

    // Log to analytics for error tracking
    if (AppConfig.enableAnalytics && _analytics != null) {
      try {
        _analytics!.logEvent(
          name: 'app_error',
          parameters: {
            'error_type': type,
            'error_message': error.toString().substring(0, 100), // Limit length
            'has_stack_trace': stack != null,
          },
        );
      } catch (e) {
        debugPrint('Failed to log error to Analytics: $e');
      }
    }
  }

  /// Handle and report user-facing errors
  static void handleUserError(
    BuildContext context,
    String message, {
    Object? error,
    StackTrace? stack,
    VoidCallback? onRetry,
  }) {
    _logError('User Error', error ?? message, stack);
    
    // Show user-friendly error message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: onRetry != null
              ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : null,
        ),
      );
    }
  }

  /// Handle network errors specifically
  static void handleNetworkError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    handleUserError(
      context,
      'Network error. Please check your connection and try again.',
      onRetry: onRetry,
    );
  }

  /// Handle sync errors
  static void handleSyncError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    handleUserError(
      context,
      'Sync failed. Your data is saved locally and will sync when connection is restored.',
      onRetry: onRetry,
    );
  }

  /// Handle authentication errors
  static void handleAuthError(BuildContext context) {
    handleUserError(
      context,
      'Authentication failed. Please sign in again.',
    );
  }

  /// Handle storage errors
  static void handleStorageError(BuildContext context) {
    handleUserError(
      context,
      'Storage error. Please check available space and try again.',
    );
  }
}