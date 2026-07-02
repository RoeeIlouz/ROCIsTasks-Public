import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/sync_status_service.dart';

void main() {
  group('SyncStatusService', () {
    late SyncStatusService service;

    setUp(() {
      service = SyncStatusService();
      // Reset to idle
      service.clearError();
    });

    test('should start in idle state', () {
      expect(service.state, SyncState.idle);
      expect(service.hasError, false);
      expect(service.isSyncing, false);
      expect(service.lastErrorMessage, isNull);
    });

    test('setSyncing should set state to syncing', () {
      service.setSyncing();
      expect(service.state, SyncState.syncing);
      expect(service.isSyncing, true);
      expect(service.lastErrorMessage, isNull);
    });

    test('setSuccess should set state to success', () {
      service.setSuccess();
      expect(service.state, SyncState.success);
      expect(service.hasError, false);
      expect(service.lastSyncTime, isNotNull);
    });

    test('setSuccess should clear error message', () {
      service.setError('error');
      service.setSuccess();
      expect(service.lastErrorMessage, isNull);
    });

    test('setError should set state to error with message', () {
      service.setError('Sync failed');
      expect(service.state, SyncState.error);
      expect(service.hasError, true);
      expect(service.lastErrorMessage, 'Sync failed');
    });

    test('clearError should reset to idle from error state', () {
      service.setError('error');
      service.clearError();
      expect(service.state, SyncState.idle);
      expect(service.hasError, false);
      expect(service.lastErrorMessage, isNull);
    });

    test('clearError should not change state if not in error', () {
      service.setSyncing();
      service.clearError();
      expect(service.state, SyncState.syncing);
    });

    test('should notify listeners on state changes', () {
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      service.setSyncing();
      service.setSuccess();
      service.setError('fail');
      service.clearError();

      expect(notifyCount, 4);
    });

    test('setSyncing should clear previous error message', () {
      service.setError('old error');
      service.setSyncing();
      expect(service.lastErrorMessage, isNull);
    });
  });
}
