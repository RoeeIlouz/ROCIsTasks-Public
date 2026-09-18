import 'package:flutter/services.dart';

/// Utility providing rate-limited (throttled) haptic feedback to prevent
/// motor buzzing and user haptic fatigue during rapid user interactions (such as chip selection).
class HapticUtils {
  static DateTime? _lastLightImpact;
  static DateTime? _lastSelectionClick;
  static DateTime? _lastMediumImpact;

  /// Visible for testing to reset throttling state between tests.
  static void resetThrottle() {
    _lastLightImpact = null;
    _lastSelectionClick = null;
    _lastMediumImpact = null;
  }

  /// Triggers [HapticFeedback.lightImpact] if at least [throttleDuration]
  /// has elapsed since the previous light impact (default 120ms).
  static void throttledLightImpact([
    Duration throttleDuration = const Duration(milliseconds: 120),
  ]) {
    final now = DateTime.now();
    if (_lastLightImpact == null ||
        now.difference(_lastLightImpact!) >= throttleDuration) {
      _lastLightImpact = now;
      HapticFeedback.lightImpact();
    }
  }

  /// Triggers [HapticFeedback.selectionClick] if at least [throttleDuration]
  /// has elapsed since the previous selection click (default 100ms).
  static void throttledSelectionClick([
    Duration throttleDuration = const Duration(milliseconds: 100),
  ]) {
    final now = DateTime.now();
    if (_lastSelectionClick == null ||
        now.difference(_lastSelectionClick!) >= throttleDuration) {
      _lastSelectionClick = now;
      HapticFeedback.selectionClick();
    }
  }

  /// Triggers [HapticFeedback.mediumImpact] if at least [throttleDuration]
  /// has elapsed since the previous medium impact (default 120ms).
  static void throttledMediumImpact([
    Duration throttleDuration = const Duration(milliseconds: 120),
  ]) {
    final now = DateTime.now();
    if (_lastMediumImpact == null ||
        now.difference(_lastMediumImpact!) >= throttleDuration) {
      _lastMediumImpact = now;
      HapticFeedback.mediumImpact();
    }
  }
}
