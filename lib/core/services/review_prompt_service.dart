import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for a Play Store rating at a good moment: after the user has completed
/// [completionsBeforePrompt] tasks, used the app for [minDaysInstalled] days, and
/// not been asked in [cooldown]. Google Play decides whether the sheet shows.
class ReviewPromptService {
  static final ReviewPromptService _instance = ReviewPromptService._internal();
  factory ReviewPromptService() => _instance;
  ReviewPromptService._internal();

  static const completionsBeforePrompt = 10;
  static const minDaysInstalled = 3;
  static const cooldown = Duration(days: 90);

  static const _firstSeenKey = 'review_first_seen_ms';
  static const _completionsKey = 'review_completions';
  static const _lastPromptKey = 'review_last_prompt_ms';

  DateTime? _suppressedUntil;

  /// Keeps the prompt away briefly, e.g. while a widget action returns to the
  /// home screen.
  void suppressFor(Duration duration) =>
      _suppressedUntil = DateTime.now().add(duration);

  /// Call when the user completes a task.
  Future<void> onTaskCompleted() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final firstSeen = prefs.getInt(_firstSeenKey);
      if (firstSeen == null) {
        await prefs.setInt(_firstSeenKey, now.millisecondsSinceEpoch);
      }
      final completions = (prefs.getInt(_completionsKey) ?? 0) + 1;
      await prefs.setInt(_completionsKey, completions);

      final installed = DateTime.fromMillisecondsSinceEpoch(
        firstSeen ?? now.millisecondsSinceEpoch,
      );
      final lastPrompt = prefs.getInt(_lastPromptKey);
      final ready =
          completions >= completionsBeforePrompt &&
          now.difference(installed).inDays >= minDaysInstalled &&
          (lastPrompt == null ||
              now.difference(DateTime.fromMillisecondsSinceEpoch(lastPrompt)) >=
                  cooldown);
      final suppressed =
          _suppressedUntil != null && now.isBefore(_suppressedUntil!);
      final foreground =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!ready || suppressed || !foreground) return;

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await prefs.setInt(_lastPromptKey, now.millisecondsSinceEpoch);
      await AnalyticsService().logEvent(
        name: 'review_prompt_requested',
        parameters: {'completions': completions},
      );
      await review.requestReview();
    } catch (e) {
      AppLogger.warning('Review prompt failed: $e', tag: 'Review');
    }
  }
}
