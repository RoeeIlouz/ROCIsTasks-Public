import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('should have correct app name', () {
      expect(AppConfig.appName, "ROCI's Tasks");
    });

    test('should have valid version string', () {
      expect(AppConfig.appVersion, isNotEmpty);
      expect(AppConfig.appVersion, matches(RegExp(r'^\d+\.\d+\.\d+(\+\d+)?$')));
    });

    test('should have valid URLs', () {
      expect(AppConfig.privacyPolicyUrl, startsWith('https://'));
      expect(AppConfig.termsOfServiceUrl, startsWith('https://'));
      expect(AppConfig.websiteUrl, startsWith('https://'));
    });

    test('should have valid support email', () {
      expect(AppConfig.supportEmail, contains('@'));
    });

    test('should have correct Firebase project ID', () {
      expect(AppConfig.firebaseProjectId, 'rocis-todo');
    });

    test('should have valid performance settings', () {
      expect(AppConfig.maxTasksPerPage, greaterThan(0));
      expect(AppConfig.syncTimeoutSeconds, greaterThan(0));
      expect(AppConfig.notificationDebounceMs, greaterThan(0));
    });

    test('should have valid UI limits', () {
      expect(AppConfig.maxDescriptionLength, greaterThan(0));
      expect(AppConfig.maxTitleLength, greaterThan(0));
    });

    test('should have valid monetization limits', () {
      expect(AppConfig.freeCategoryLimit, greaterThan(0));
      expect(AppConfig.freeWidgetLimit, greaterThan(0));
    });

    test('should have correct entitlement ID', () {
      expect(AppConfig.entitlementId, 'ROCIsApps Pro');
    });

    test('getConfigSummary should return map', () {
      final summary = AppConfig.getConfigSummary();
      expect(summary, isA<Map<String, dynamic>>());
      expect(summary['appName'], "ROCI's Tasks");
      expect(summary['appVersion'], isNotEmpty);
      expect(summary['firebaseProjectId'], 'rocis-todo');
      expect(summary.containsKey('isProduction'), true);
      expect(summary.containsKey('enableAnalytics'), true);
    });

    test('feature flags should be consistent', () {
      // In debug mode, analytics should be disabled
      // In release mode, analytics should be enabled
      expect(AppConfig.enableAnalytics, AppConfig.isProduction);
      expect(AppConfig.enableCrashReporting, AppConfig.isProduction);
      expect(AppConfig.enablePerformanceMonitoring, AppConfig.isProduction);
    });
  });
}
