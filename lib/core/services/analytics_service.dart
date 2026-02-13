import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

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
  Future<void> logTaskCompleted({required String taskId}) async {
    await logEvent(name: 'task_completed', parameters: {'task_id': taskId});
  }

  /// Log category created event
  Future<void> logCategoryCreated({required String name}) async {
    await logEvent(
      name: 'category_created',
      parameters: {'category_name_length': name.length},
    );
  }

  /// Log task deleted event
  Future<void> logTaskDeleted({required String taskId}) async {
    await logEvent(name: 'task_deleted', parameters: {'task_id': taskId});
  }
}
