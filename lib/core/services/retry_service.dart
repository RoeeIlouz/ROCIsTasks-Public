import 'dart:async';
import 'dart:math';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

/// Service for handling retry logic with exponential backoff
class RetryService {
  /// Retry a function with exponential backoff
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 30),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (error) {
        attempt++;

        if (AppConfig.enableDebugLogging) {
          AppLogger.warning(
            'Retry attempt $attempt/$maxAttempts failed',
            error: error,
          );
        }

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          rethrow;
        }

        // If this was the last attempt, rethrow the error
        if (attempt >= maxAttempts) {
          rethrow;
        }

        // Wait before retrying with exponential backoff
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: min(
            (delay.inMilliseconds * backoffMultiplier).round(),
            maxDelay.inMilliseconds,
          ),
        );
      }
    }

    throw StateError('Retry logic error - should not reach here');
  }

  /// Retry network operations specifically
  static Future<T> retryNetworkOperation<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
  }) async {
    return retry(
      operation,
      maxAttempts: maxAttempts,
      shouldRetry: _isRetryableNetworkError,
    );
  }

  /// Retry Firestore operations specifically
  static Future<T> retryFirestoreOperation<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
  }) async {
    return retry(
      operation,
      maxAttempts: maxAttempts,
      shouldRetry: _isRetryableFirestoreError,
    );
  }

  /// Check if an error is retryable for network operations
  static bool _isRetryableNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Common retryable network errors
    return errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('host') ||
        errorString.contains('unreachable');
  }

  /// Check if an error is retryable for Firestore operations
  static bool _isRetryableFirestoreError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Retryable Firestore errors
    return errorString.contains('unavailable') ||
        errorString.contains('deadline-exceeded') ||
        errorString.contains('internal') ||
        errorString.contains('timeout') ||
        errorString.contains('cancelled') ||
        _isRetryableNetworkError(error);
  }

  /// Retry with circuit breaker pattern
  static Future<T> retryWithCircuitBreaker<T>(
    String operationName,
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration circuitBreakerTimeout = const Duration(minutes: 5),
  }) async {
    final circuitBreakerKey = 'circuit_breaker_$operationName';

    // Check if circuit breaker is open
    if (_circuitBreakers.containsKey(circuitBreakerKey)) {
      final breakerInfo = _circuitBreakers[circuitBreakerKey]!;
      if (DateTime.now().isBefore(breakerInfo['resetTime'])) {
        throw Exception('Circuit breaker is open for $operationName');
      } else {
        // Reset circuit breaker
        _circuitBreakers.remove(circuitBreakerKey);
      }
    }

    try {
      return await retry(operation, maxAttempts: maxAttempts);
    } catch (error) {
      // Open circuit breaker
      _circuitBreakers[circuitBreakerKey] = {
        'resetTime': DateTime.now().add(circuitBreakerTimeout),
        'error': error,
      };
      rethrow;
    }
  }

  static final Map<String, Map<String, dynamic>> _circuitBreakers = {};
}
