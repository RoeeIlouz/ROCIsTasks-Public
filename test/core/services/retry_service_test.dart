import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/retry_service.dart';

void main() {
  group('RetryService', () {
    group('retry', () {
      test('should return result on first successful attempt', () async {
        int attempts = 0;
        final result = await RetryService.retry(
          () async {
            attempts++;
            return 'success';
          },
          maxAttempts: 3,
          initialDelay: Duration.zero,
        );
        expect(result, 'success');
        expect(attempts, 1);
      });

      test('should retry and succeed on second attempt', () async {
        int attempts = 0;
        final result = await RetryService.retry(
          () async {
            attempts++;
            if (attempts < 2) throw Exception('fail');
            return 'success';
          },
          maxAttempts: 3,
          initialDelay: Duration.zero,
        );
        expect(result, 'success');
        expect(attempts, 2);
      });

      test('should retry and succeed on third attempt', () async {
        int attempts = 0;
        final result = await RetryService.retry(
          () async {
            attempts++;
            if (attempts < 3) throw Exception('fail');
            return 'success';
          },
          maxAttempts: 3,
          initialDelay: Duration.zero,
        );
        expect(result, 'success');
        expect(attempts, 3);
      });

      test('should throw after max attempts exhausted', () async {
        int attempts = 0;
        await expectLater(
          () => RetryService.retry(
            () async {
              attempts++;
              throw Exception('always fail');
            },
            maxAttempts: 3,
            initialDelay: Duration.zero,
          ),
          throwsException,
        );
        expect(attempts, 3);
      });

      test('should respect shouldRetry predicate', () async {
        int attempts = 0;
        expect(
          () => RetryService.retry(
            () async {
              attempts++;
              throw FormatException('non-retryable');
            },
            maxAttempts: 3,
            initialDelay: Duration.zero,
            shouldRetry: (error) => error is! FormatException,
          ),
          throwsA(isA<FormatException>()),
        );
        await Future.delayed(Duration.zero);
        expect(attempts, 1); // Should not retry
      });

      test('should retry when shouldRetry returns true', () async {
        int attempts = 0;
        final result = await RetryService.retry(
          () async {
            attempts++;
            if (attempts < 2) throw Exception('timeout error');
            return 'success';
          },
          maxAttempts: 3,
          initialDelay: Duration.zero,
          shouldRetry: (error) => error.toString().contains('timeout'),
        );
        expect(result, 'success');
        expect(attempts, 2);
      });
    });

    group('retryFirestoreOperation', () {
      test('should retry on unavailable error', () async {
        int attempts = 0;
        final result = await RetryService.retryFirestoreOperation(
          () async {
            attempts++;
            if (attempts < 2) throw Exception('UNAVAILABLE');
            return 'synced';
          },
          maxAttempts: 3,
        );
        expect(result, 'synced');
        expect(attempts, 2);
      });

      test('should retry on timeout error', () async {
        int attempts = 0;
        final result = await RetryService.retryFirestoreOperation(
          () async {
            attempts++;
            if (attempts < 2) throw Exception('deadline-exceeded');
            return 'done';
          },
          maxAttempts: 3,
        );
        expect(result, 'done');
        expect(attempts, 2);
      });

      test('should not retry on non-retryable error', () async {
        int attempts = 0;
        expect(
          () => RetryService.retryFirestoreOperation(
            () async {
              attempts++;
              throw Exception('permission-denied');
            },
            maxAttempts: 3,
          ),
          throwsException,
        );
        await Future.delayed(Duration.zero);
        expect(attempts, 1);
      });
    });

    group('retryNetworkOperation', () {
      test('should retry on connection error', () async {
        int attempts = 0;
        final result = await RetryService.retryNetworkOperation(
          () async {
            attempts++;
            if (attempts < 2) throw Exception('Connection refused');
            return 'connected';
          },
          maxAttempts: 3,
        );
        expect(result, 'connected');
        expect(attempts, 2);
      });

      test('should retry on socket error', () async {
        int attempts = 0;
        final result = await RetryService.retryNetworkOperation(
          () async {
            attempts++;
            if (attempts < 2) throw Exception('SocketException');
            return 'ok';
          },
          maxAttempts: 3,
        );
        expect(result, 'ok');
        expect(attempts, 2);
      });
    });

    group('retryWithCircuitBreaker', () {
      test('should execute on first call', () async {
        final result = await RetryService.retryWithCircuitBreaker(
          'test-op',
          () async => 'done',
          maxAttempts: 1,
        );
        expect(result, 'done');
      });

      test('should open circuit breaker after failure', () async {
        try {
          await RetryService.retryWithCircuitBreaker(
            'failing-op',
            () async => throw Exception('fail'),
            maxAttempts: 1,
          );
        } catch (_) {}

        // Second call should fail immediately due to circuit breaker
        expect(
          () => RetryService.retryWithCircuitBreaker(
            'failing-op',
            () async => 'should not run',
            maxAttempts: 1,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
