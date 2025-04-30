// lib/src/core/util/retry_util.dart

import 'dart:async';
import '../../core/logging/logger.dart';

/// Utility for executing asynchronous operations with retry logic and exponential backoff.
class RetryUtil {
  /// Executes [block] with retry logic.
  ///
  /// - [maxAttempts]: Maximum number of attempts.
  /// - [initialDelayMs]: Initial delay between retries in milliseconds.
  /// - [maxDelayMs]: Maximum delay between retries in milliseconds.
  /// - [backoffMultiplier]: Multiplier for exponential backoff.
  /// - [block]: The asynchronous function to execute.
  ///
  /// Throws the last exception if all attempts fail.
  static Future<T> withRetry<T>({
    required int maxAttempts,
    required int initialDelayMs,
    required int maxDelayMs,
    required double backoffMultiplier,
    required Future<T> Function() block,
  }) async {
    int attempt = 0;
    int currentDelay = initialDelayMs;
    Exception? lastException;

    while (attempt < maxAttempts) {
      try {
        return await block();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        attempt++;
        if (attempt < maxAttempts) {
          Logger.w(
              'Attempt \$attempt failed, retrying in \$currentDelay ms: \$e');
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
    required Future<T> Function() block,
  }) async {
    try {
      return await withRetry(
        maxAttempts: maxAttempts,
        initialDelayMs: initialDelayMs,
        maxDelayMs: maxDelayMs,
        backoffMultiplier: backoffMultiplier,
        block: block,
      );
    } catch (e) {
      Logger.e('All retry attempts failed, returning null: \$e');
      return null;
    }
  }
}
