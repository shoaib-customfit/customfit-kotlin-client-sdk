// lib/src/core/util/retry_util.dart

import 'dart:async';
import '../../logging/logger.dart';
import 'circuit_breaker.dart';

/// Utility for executing asynchronous operations with retry logic and exponential backoff.
class RetryUtil {
  /// Executes [block] with retry logic.
  ///
  /// - [maxAttempts]: Maximum number of attempts.
  /// - [initialDelayMs]: Initial delay between retries in milliseconds.
  /// - [maxDelayMs]: Maximum delay between retries in milliseconds.
  /// - [backoffMultiplier]: Multiplier for exponential backoff.
  /// - [retryOn]: Optional predicate to determine if retry should happen for an exception.
  /// - [block]: The asynchronous function to execute.
  ///
  /// Throws the last exception if all attempts fail.
  static Future<T> withRetry<T>({
    required int maxAttempts,
    required int initialDelayMs,
    required int maxDelayMs,
    required double backoffMultiplier,
    bool Function(Exception)? retryOn,
    required Future<T> Function() block,
  }) async {
    int attempt = 0;
    int currentDelay = initialDelayMs;
    Exception? lastException;

    while (attempt < maxAttempts) {
      try {
        return await block();
      } catch (e) {
        final exception = e is Exception ? e : Exception(e.toString());
        lastException = exception;
        attempt++;

        // Check if we should retry based on the predicate
        if (retryOn != null && !retryOn(exception)) {
          Logger.w(
              'Exception does not meet retry criteria, failing immediately: $e');
          break;
        }

        if (attempt < maxAttempts) {
          Logger.w('Attempt $attempt failed, retrying in $currentDelay ms: $e');
          await Future.delayed(Duration(milliseconds: currentDelay));
          currentDelay = (currentDelay * backoffMultiplier).toInt();
          if (currentDelay > maxDelayMs) {
            currentDelay = maxDelayMs;
          }
        }
      }
    }

    throw lastException ?? Exception('All retry attempts failed');
  }

  /// Executes [block] with retry logic and returns null if all attempts fail.
  static Future<T?> withRetryOrNull<T>({
    required int maxAttempts,
    required int initialDelayMs,
    required int maxDelayMs,
    required double backoffMultiplier,
    bool Function(Exception)? retryOn,
    required Future<T> Function() block,
  }) async {
    try {
      return await withRetry(
        maxAttempts: maxAttempts,
        initialDelayMs: initialDelayMs,
        maxDelayMs: maxDelayMs,
        backoffMultiplier: backoffMultiplier,
        retryOn: retryOn,
        block: block,
      );
    } catch (e) {
      Logger.e('All retry attempts failed, returning null: $e');
      return null;
    }
  }

  /// Executes [block] with timeout, returning a fallback value if timeout occurs.
  ///
  /// - [timeoutMs]: Timeout in milliseconds.
  /// - [fallback]: Fallback value to return on timeout.
  /// - [logTimeout]: Whether to log timeout warnings.
  /// - [block]: The asynchronous function to execute.
  static Future<T> withTimeout<T>({
    required int timeoutMs,
    required T fallback,
    bool logTimeout = true,
    required Future<T> Function() block,
  }) async {
    try {
      return await block().timeout(
        Duration(milliseconds: timeoutMs),
        onTimeout: () {
          if (logTimeout) {
            Logger.w(
                'Operation timed out after $timeoutMs ms. Using fallback value.');
          }
          return fallback;
        },
      );
    } catch (e) {
      Logger.e('Operation failed: $e. Using fallback value.');
      return fallback;
    }
  }

  /// Executes [block] with timeout, returning null if timeout occurs.
  ///
  /// - [timeoutMs]: Timeout in milliseconds.
  /// - [logTimeout]: Whether to log timeout warnings.
  /// - [block]: The asynchronous function to execute.
  static Future<T?> withTimeoutOrNull<T>({
    required int timeoutMs,
    bool logTimeout = true,
    required Future<T> Function() block,
  }) async {
    try {
      final completer = Completer<T?>();

      // Create a timeout timer
      final timer = Timer(Duration(milliseconds: timeoutMs), () {
        if (!completer.isCompleted) {
          if (logTimeout) {
            Logger.w('Operation timed out after $timeoutMs ms');
          }
          completer.complete(null);
        }
      });

      // Execute the block
      block().then((result) {
        if (!completer.isCompleted) {
          timer.cancel();
          completer.complete(result);
        }
      }).catchError((e) {
        if (!completer.isCompleted) {
          timer.cancel();
          Logger.e('Operation failed: $e');
          completer.complete(null);
        }
      });

      return completer.future;
    } catch (e) {
      Logger.e('Error setting up timeout: $e');
      return null;
    }
  }

  /// Executes a block with circuit breaker protection
  ///
  /// - [operationKey]: Unique identifier for this operation.
  /// - [failureThreshold]: Number of failures before opening circuit.
  /// - [resetTimeoutMs]: Time in ms before allowing retries when circuit open.
  /// - [fallback]: Optional fallback value to return on failure.
  /// - [block]: The asynchronous function to execute.
  static Future<T> withCircuitBreaker<T>({
    required String operationKey,
    required int failureThreshold,
    required int resetTimeoutMs,
    T? fallback,
    required Future<T> Function() block,
  }) async {
    final circuitBreaker = CircuitBreaker.getInstance(
        operationKey, failureThreshold, resetTimeoutMs);

    return circuitBreaker.executeWithCircuitBreaker(block, fallback: fallback);
  }

  /// Executes block and tracks execution time for performance monitoring
  ///
  /// - [operationName]: Name of the operation for logging.
  /// - [warnThresholdMs]: Threshold in ms above which to log a warning.
  /// - [block]: The asynchronous function to execute.
  static Future<T> withPerformanceTracking<T>({
    required String operationName,
    int warnThresholdMs = 1000,
    required Future<T> Function() block,
  }) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    try {
      final result = await block();
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - startTime;

      if (elapsedMs > warnThresholdMs) {
        Logger.w(
            '$operationName took $elapsedMs ms (threshold: $warnThresholdMs ms)');
      } else {
        Logger.d('$operationName completed in $elapsedMs ms');
      }

      return result;
    } catch (e) {
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - startTime;
      Logger.e('$operationName failed after $elapsedMs ms: $e');
      rethrow;
    }
  }

  /// Runs multiple operations in parallel with proper error handling
  ///
  /// - [operations]: List of async operations to run in parallel.
  /// - [continueOnError]: Whether to continue if an operation fails.
  static Future<List<Result<T>>> runParallel<T>({
    required List<Future<T> Function()> operations,
    bool continueOnError = true,
  }) async {
    final futures = <Future<Result<T>>>[];

    for (final operation in operations) {
      futures.add(_executeOperation(operation, continueOnError));
    }

    return Future.wait(futures);
  }

  /// Helper to execute an operation and wrap in Result
  static Future<Result<T>> _executeOperation<T>(
      Future<T> Function() operation, bool continueOnError) async {
    try {
      final result = await operation();
      return Result.success(result);
    } catch (e) {
      if (!continueOnError) {
        rethrow;
      }
      return Result.failure(e is Exception ? e : Exception(e.toString()));
    }
  }
}

/// Simple Result class for wrapping success/failure
class Result<T> {
  final T? _value;
  final Exception? _error;
  final bool _isSuccess;

  Result._success(this._value)
      : _error = null,
        _isSuccess = true;
  Result._failure(this._error)
      : _value = null,
        _isSuccess = false;

  static Result<T> success<T>(T value) => Result<T>._success(value);
  static Result<T> failure<T>(Exception error) => Result<T>._failure(error);

  bool get isSuccess => _isSuccess;
  bool get isFailure => !_isSuccess;

  T get getOrThrow {
    if (_isSuccess) return _value as T;
    throw _error!;
  }

  T? get getOrNull => _isSuccess ? _value : null;

  Exception? get exceptionOrNull => _isSuccess ? null : _error;

  R fold<R>(R Function(T) onSuccess, R Function(Exception) onFailure) {
    return _isSuccess ? onSuccess(_value as T) : onFailure(_error!);
  }
}
