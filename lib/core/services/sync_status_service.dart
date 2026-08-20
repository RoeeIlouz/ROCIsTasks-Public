import 'package:flutter/foundation.dart';

/// Tracks the sync status of Firestore operations.
/// UI components can listen to this to show sync indicators or error banners.
enum SyncState { idle, syncing, success, error }

class SyncStatusService extends ChangeNotifier {
  static final SyncStatusService _instance = SyncStatusService._internal();
  factory SyncStatusService() => _instance;
  SyncStatusService._internal();

  SyncState _state = SyncState.idle;
  String? _lastErrorMessage;
  DateTime? _lastSyncTime;

  SyncState get state => _state;
  String? get lastErrorMessage => _lastErrorMessage;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get hasError => _state == SyncState.error;
  bool get isSyncing => _state == SyncState.syncing;

  void setSyncing() {
    _state = SyncState.syncing;
    _lastErrorMessage = null;
    notifyListeners();
  }

  void setSuccess() {
    _state = SyncState.success;
    _lastErrorMessage = null;
    _lastSyncTime = DateTime.now();
    notifyListeners();

    // Auto-reset to idle after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (_state == SyncState.success) {
        _state = SyncState.idle;
        notifyListeners();
      }
    });
  }

  void setError(String message) {
    _state = SyncState.error;
    _lastErrorMessage = message;
    notifyListeners();
  }

  void clearError() {
    if (_state == SyncState.error) {
      _state = SyncState.idle;
      _lastErrorMessage = null;
      notifyListeners();
    }
  }
}
