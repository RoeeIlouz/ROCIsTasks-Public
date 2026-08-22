import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

/// Service to monitor network connectivity status with resilient fallback
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicCheckTimer;
  bool _isOnline = true;

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
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChanged);

    // Periodic check to self-heal from false-negative offline states
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_isOnline) {
        _checkConnectivity();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _processConnectivityResults(results);
    } catch (e) {
      AppLogger.warning('Error checking connectivity via plugin, attempting fallback lookup: $e', tag: 'Connectivity');
      await _verifyRealInternet();
    }
  }

  Future<void> _handleConnectivityChanged(List<ConnectivityResult> results) async {
    await _processConnectivityResults(results);
  }

  Future<void> _processConnectivityResults(List<ConnectivityResult> results) async {
    final hasActiveInterface = results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);

    bool actualOnline = hasActiveInterface;

    // If connectivity_plus claims no connection on mobile/desktop, verify via DNS lookup before assuming offline
    if (!hasActiveInterface && !kIsWeb) {
      actualOnline = await _isInternetReachable();
    }

    _setOnlineState(actualOnline);
  }

  Future<void> _verifyRealInternet() async {
    if (kIsWeb) {
      _setOnlineState(true);
      return;
    }
    final reachable = await _isInternetReachable();
    _setOnlineState(reachable);
  }

  Future<bool> _isInternetReachable() async {
    try {
      final lookup = await InternetAddress.lookup('8.8.8.8')
          .timeout(const Duration(milliseconds: 2000));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final lookupHost = await InternetAddress.lookup('google.com')
            .timeout(const Duration(milliseconds: 2000));
        return lookupHost.isNotEmpty && lookupHost[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  void _setOnlineState(bool isOnline) {
    final wasOnline = _isOnline;
    _isOnline = isOnline;
    final stateChanged = wasOnline != _isOnline;

    if (stateChanged) {
      AppLogger.info('Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}', tag: 'Connectivity');
      notifyListeners();
    }
  }

  /// Manually refresh connectivity status
  Future<void> refresh() async {
    await _checkConnectivity();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _periodicCheckTimer?.cancel();
    super.dispose();
  }
}
