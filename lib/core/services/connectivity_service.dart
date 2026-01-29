import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

/// Service to monitor network connectivity status
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;
  bool _hasCheckedInitial = false;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  // Singleton pattern
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  /// Initialize connectivity monitoring
  Future<void> init() async {
    // Check initial connectivity
    await _checkConnectivity();

    // Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateConnectivity(results);
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectivity(results);
      _hasCheckedInitial = true;
    } catch (e) {
      AppLogger.error('Error checking connectivity', error: e, tag: 'Connectivity');
      _isOnline = false;
      _hasCheckedInitial = true;
      notifyListeners();
    }
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;

    // Consider online if any connection type is available (except none)
    _isOnline =
        results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);

    if (wasOnline != _isOnline && _hasCheckedInitial) {
      AppLogger.info('Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}', tag: 'Connectivity');
      notifyListeners();
    }
  }

  /// Manually refresh connectivity status
  Future<void> refresh() async {
    await _checkConnectivity();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
