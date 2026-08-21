import 'package:flutter/foundation.dart';

/// Application configuration class
/// This should be used to manage environment-specific settings
class AppConfig {
  // Environment flags
  static const bool isProduction = kReleaseMode;
  static const bool isDevelopment = kDebugMode;

  // App information
  static const String appName = 'ROCI\'s Tasks';
  static const String appVersion = '0.2.10';
  static const String supportEmail = 'support@rocisapps.com';
  static const String privacyPolicyUrl = 'https://rocisapps.com/privacy.html';
  static const String termsOfServiceUrl = 'https://rocisapps.com/terms.html';
  static const String websiteUrl = 'https://rocisapps.com';
  static const String webAppUrl = 'https://tasks.rocisapps.com';
  static const String githubUrl =
      'https://github.com/RoeeIlouz/ROCIsTasks-public';

  // Lemon Squeezy Web Checkout URLs
  static const String lemonSqueezyMonthlyUrl =
      'https://rocisapps.lemonsqueezy.com/checkout/buy/5833ecbc-c8c9-4044-974c-782c1fd47e4b?embed=1&discount=0';
  static const String lemonSqueezyYearlyUrl =
      'https://rocisapps.lemonsqueezy.com/checkout/buy/9afcddf6-d31c-4031-8d49-38e4afdbcee4?embed=1&discount=0';
  static const String lemonSqueezyLifetimeUrl =
      'https://rocisapps.lemonsqueezy.com/checkout/buy/40f6b2af-ab2f-4bef-ab3f-32da7f417930?embed=1&discount=0';

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
  static const int notificationDebounceMs = 200; // Widget update debounce

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
