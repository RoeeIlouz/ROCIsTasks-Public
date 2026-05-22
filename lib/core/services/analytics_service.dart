import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Log a standard event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!AppConfig.enableAnalytics) return;

    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      AppLogger.info('Analytics Event: $name', tag: 'Analytics');
    } catch (e, s) {
      AppLogger.warning(
        'Failed to log analytics event: $name',
        error: e,
        stack: s,
      );
    }
  }

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!AppConfig.enableAnalytics) return;

    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      AppLogger.info('Screen View: $screenName', tag: 'Analytics');
    } catch (e, s) {
      AppLogger.warning(
        'Failed to log screen view: $screenName',
        error: e,
        stack: s,
      );
    }
  }

  /// Log task created event
  Future<void> logTaskCreated({
    required String categoryId,
    required bool hasDueDate,
  }) async {
    await logEvent(
      name: 'task_created',
      parameters: {
        'category_id': categoryId,
        'has_due_date': hasDueDate ? 1 : 0,
      },
    );
  }

  /// Log task completed event
  Future<void> logTaskCompleted() async {
    await logEvent(name: 'task_completed');
  }

  /// Log category created event
  Future<void> logCategoryCreated({required String name}) async {
    await logEvent(
      name: 'category_created',
      parameters: {'category_name_length': name.length},
    );
  }

  /// Log task deleted event
  Future<void> logTaskDeleted() async {
    await logEvent(name: 'task_deleted');
  }

  /// Log theme changed event
  Future<void> logThemeChanged({required String themeMode}) async {
    await logEvent(
      name: 'theme_changed',
      parameters: {'theme_mode': themeMode},
    );
  }

  /// Log language changed event
  Future<void> logLanguageChanged({required String locale}) async {
    await logEvent(name: 'language_changed', parameters: {'locale': locale});
  }

  /// Log onboarding completed event
  Future<void> logOnboardingCompleted() async {
    await logEvent(name: 'onboarding_completed');
  }

  /// Log subscription management clicked event
  Future<void> logSubscriptionManagementClicked() async {
    await logEvent(name: 'subscription_management_clicked');
  }

  /// Log session start with device info
  Future<void> logSessionStart() async {
    final deviceInfo = DeviceInfoPlugin();
    String? platform;
    String? model;
    String? osVersion;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        platform = 'android';
        model = androidInfo.model;
        osVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        platform = 'ios';
        model = iosInfo.utsname.machine;
        osVersion = iosInfo.systemVersion;
      }
    } catch (e) {
      AppLogger.warning('Failed to get device info for analytics', error: e);
    }

    await logEvent(
      name: 'app_session_start',
      parameters: {
        'platform': platform ?? 'unknown',
        'device_model': model ?? 'unknown',
        'os_version': osVersion ?? 'unknown',
        'is_production': AppConfig.isProduction ? 1 : 0,
      },
    );
  }

  /// Log feature limit reached
  Future<void> logFeatureLimitReached({required String featureName}) async {
    await logEvent(
      name: 'feature_limit_reached',
      parameters: {'feature': featureName},
    );
  }

  /// Log premium feature interaction
  Future<void> logPremiumFeatureClicked({required String featureName}) async {
    await logEvent(
      name: 'premium_feature_clicked',
      parameters: {'feature': featureName},
    );
  }
}
