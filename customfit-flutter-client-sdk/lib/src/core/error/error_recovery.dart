import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../logging/logger.dart';
import '../../core/util/retry_util.dart';
import '../error/cf_result.dart';
import '../error/error_category.dart';
import '../util/circuit_breaker.dart';

/// Provides recovery strategies for different types of errors
class ErrorRecoveryStrategy {
  static const String _source = 'ErrorRecoveryStrategy';

  /// Execute with the appropriate recovery strategy based on error type
  static Future<CFResult<T>> executeWithRecovery<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxRetries = 3,
    int initialDelayMs = 200,
    T? fallback,
    bool logFailures = true,
  }) async {
    try {
      // Use circuit breaker to prevent hammering failing services
      return await RetryUtil.withCircuitBreaker(
        operationKey: operationName,
        failureThreshold: 5,
        resetTimeoutMs: 30000, // 30 seconds
        fallback: fallback,
        block: () => _executeWithRetryAndFallback(
          operation: operation,
          operationName: operationName,
          maxRetries: maxRetries,
          initialDelayMs: initialDelayMs,
          fallback: fallback,
          logFailures: logFailures,
        ),
      ).then((value) => CFResult.success(value));
    } catch (e) {
      if (logFailures) {
        Logger.e('Operation $operationName failed after recovery attempts: $e');
      }

      final category = _categorizeError(e);
      return CFResult.error(
        'Failed to execute $operationName: ${e.toString()}',
        exception: e is Exception ? e : Exception(e.toString()),
        category: category,
      );
    }
  }

  /// Execute with custom retry and fallback logic
  static Future<T> _executeWithRetryAndFallback<T>({
    required Future<T> Function() operation,
    required String operationName,
    required int maxRetries,
    required int initialDelayMs,
    T? fallback,
    bool logFailures = true,
  }) async {
    try {
      return await RetryUtil.withRetry(
        maxAttempts: maxRetries,
        initialDelayMs: initialDelayMs,
        maxDelayMs: 5000, // 5 seconds max delay
        backoffMultiplier: 1.5,
        retryOn: (e) => _shouldRetry(e),
        block: () => _executeWithConnectivityCheck(operation),
      );
    } catch (e) {
      if (logFailures) {
        Logger.e(
            'Operation $operationName failed after $maxRetries retries: $e');
      }

      if (fallback != null) {
        Logger.w('Using fallback value for $operationName');
        return fallback;
      }

      rethrow;
    }
  }

  /// Execute with connectivity check before attempting operation
  static Future<T> _executeWithConnectivityCheck<T>(
    Future<T> Function() operation,
  ) async {
    // Check connectivity first
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      Logger.w('No network connectivity detected, waiting for connection...');

      // Wait for connectivity to be restored
      final completer = Completer<void>();

      // Set up a subscription to monitor connectivity changes
      final subscription =
          Connectivity().onConnectivityChanged.listen((result) {
        if (result != ConnectivityResult.none && !completer.isCompleted) {
          Logger.i('Network connectivity restored');
          completer.complete();
        }
      });

      // Wait up to 30 seconds for connectivity
      try {
        await completer.future.timeout(const Duration(seconds: 30));
      } catch (e) {
        Logger.e('Timed out waiting for network connectivity');
        throw NetworkUnavailableException('Network is currently unavailable');
      } finally {
        subscription.cancel();
      }
    }

    // Execute the operation
    try {
      return await operation();
    } on SocketException catch (e) {
      Logger.e('Socket error during operation: $e');
      throw NetworkException('Network error: ${e.message}');
    } on TimeoutException catch (e) {
      Logger.e('Timeout during operation: $e');
      throw TimeoutException('Operation timed out');
    } catch (e) {
      rethrow;
    }
  }

  /// Determine if the exception is retriable
  static bool _shouldRetry(Exception exception) {
    // Network errors should be retried
    if (exception is SocketException ||
        exception is TimeoutException ||
        exception is NetworkException ||
        exception is NetworkUnavailableException) {
      return true;
    }

    // Server errors (5xx) should be retried
    if (exception is HttpException) {
      // Extract status code if available in the message
      final message = exception.message;
      if (message.contains('500') ||
          message.contains('502') ||
          message.contains('503') ||
          message.contains('504')) {
        return true;
      }
    }

    // Other exceptions should not be retried
    return false;
  }

  /// Categorize the error for better handling
  static ErrorCategory _categorizeError(dynamic error) {
    if (error is SocketException ||
        error is NetworkException ||
        error is NetworkUnavailableException) {
      return ErrorCategory.network;
    }

    if (error is TimeoutException) {
      return ErrorCategory.timeout;
    }

    if (error is CircuitOpenException) {
      return ErrorCategory.circuitBreaker;
    }

    if (error is FormatException) {
      return ErrorCategory.serialization;
    }

    if (error is HttpException) {
      final message = error.message;
      if (message.contains('401') || message.contains('403')) {
        return ErrorCategory.authentication;
      }
      if (message.contains('429')) {
        return ErrorCategory.rateLimit;
      }
      return ErrorCategory.network;
    }

    return ErrorCategory.unknown;
  }
}

/// Exception indicating a general network error
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

/// Exception indicating no network connectivity
class NetworkUnavailableException implements Exception {
  final String message;
  NetworkUnavailableException(this.message);

  @override
  String toString() => 'NetworkUnavailableException: $message';
}
