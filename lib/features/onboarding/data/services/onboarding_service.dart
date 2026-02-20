import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';

class OnboardingService extends ChangeNotifier {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  final SharedPreferences _prefs;
  final AnalyticsService _analyticsService;

  OnboardingService(this._prefs, {AnalyticsService? analyticsService})
    : _analyticsService = analyticsService ?? AnalyticsService();

  bool get hasSeenOnboarding => _prefs.getBool(_onboardingCompleteKey) ?? false;

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingCompleteKey, true);
    await _analyticsService.logOnboardingCompleted();
    notifyListeners();
  }
}
