import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';

class OnboardingService extends ChangeNotifier {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  final AnalyticsService _analyticsService;
  late final Box _settingsBox;

  OnboardingService({AnalyticsService? analyticsService})
    : _analyticsService = analyticsService ?? AnalyticsService() {
    _settingsBox = Hive.box('settings');
  }

  bool get hasSeenOnboarding => _settingsBox.get(_onboardingCompleteKey, defaultValue: false);

  Future<void> completeOnboarding() async {
    await _settingsBox.put(_onboardingCompleteKey, true);
    await _analyticsService.logOnboardingCompleted();
    notifyListeners();
  }
}
