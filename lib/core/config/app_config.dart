import 'package:flutter/foundation.dart';

/// Application configuration class
/// This should be used to manage environment-specific settings
class AppConfig {
  // Environment flags
  static const bool isProduction = kReleaseMode;
  static const bool isDevelopment = kDebugMode;

  // App information
  static const String appName = 'ROCI\'s Tasks';
  static const String appVersion = '1.0.3';
  static const String supportEmail = 'support@ilouz.xyz';
  static const String privacyPolicyUrl =
      'https://rocisapps.ilouz.xyz/privacy.html';
  static const String termsOfServiceUrl =
      'https://rocisapps.ilouz.xyz/terms.html';
  static const String websiteUrl = 'https://rocisapps.ilouz.xyz';

  // Feature flags
  static const bool enableAnalytics = isProduction;
  static const bool enableCrashReporting = isProduction;
  static const bool enableDebugLogging = isDevelopment;
  static const bool enablePerformanceMonitoring = isProduction;
  static const bool enableRemoteConfig =
      true; // Enabled for both to allow overrides

  // API Configuration
  static const String firebaseProjectId = 'rocis-todo';

  // Security settings
  static const bool enableCertificatePinning = isProduction;

  // Performance settings
  static const int maxTasksPerPage = 50;
  static const int syncTimeoutSeconds = 30;
  static const int notificationDebounceMs = 1000; // Increased from 300ms

  // UI settings
  static const int maxDescriptionLength = 500;
  static const int maxTitleLength = 100;

  // Monetization Limits
  static const int freeCategoryLimit = 5;
  static const int freeWidgetLimit =
      1; // For future use if we restrict widget count

  // RevenueCat
  static const String entitlementId = 'ROCIsApps Pro';

  /// Get configuration summary for debugging
  static Map<String, dynamic> getConfigSummary() {
    return {
      'isProduction': isProduction,
      'isDevelopment': isDevelopment,
      'appName': appName,
      'appVersion': appVersion,
      'enableAnalytics': enableAnalytics,
      'enableCrashReporting': enableCrashReporting,
      'enableDebugLogging': enableDebugLogging,
      'firebaseProjectId': firebaseProjectId,
      'enableCertificatePinning': enableCertificatePinning,
    };
  }
}
