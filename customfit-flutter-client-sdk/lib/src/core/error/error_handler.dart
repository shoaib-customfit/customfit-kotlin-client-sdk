// lib/models/error_handler.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'error_category.dart';
import 'error_severity.dart';

/// Centralized error handling utility with
/// categorization, rate-limiting, and reporting.
class ErrorHandler {
  static final Map<String, int> _errorCounts = {};
  static const int _maxLogRate = 10;

  /// Handles and logs an exception, returns its ErrorCategory.
  static ErrorCategory handleException(
    dynamic exception,
    String message, {
    String source = 'unknown',
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    final category = _categorizeException(exception);
    final enhanced = _buildErrorMessage(message, source, severity, category);

    final key = '${exception.runtimeType}:$source:$message';
    final count = (_errorCounts[key] ?? 0) + 1;
    _errorCounts[key] = count;

    if (count <= _maxLogRate) {
      _logBySeverity(enhanced, severity);
    } else if (count == _maxLogRate + 1) {
      debugPrint(
          'WARN: Rate limiting similar error: $key. Further occurrences won\'t be logged.');
    }

    return category;
  }

  /// Handles and logs an error without an exception.
  static void handleError(
    String message, {
    String source = 'unknown',
    ErrorCategory category = ErrorCategory.unknown,
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    final enhanced = _buildErrorMessage(message, source, severity, category);

    final key = '$source:$message:$category';
    final count = (_errorCounts[key] ?? 0) + 1;
    _errorCounts[key] = count;

    if (count <= _maxLogRate) {
      _logBySeverity(enhanced, severity);
    } else if (count == _maxLogRate + 1) {
      debugPrint(
          'WARN: Rate limiting similar error: $key. Further occurrences won\'t be logged.');
    }
  }

  /// Clears all rate-limit counters.
  static void resetErrorCounts() => _errorCounts.clear();

  //—— Internal Helpers ——//

  static ErrorCategory _categorizeException(dynamic e) {
    if (e is TimeoutException) return ErrorCategory.timeout;
    if (e is FormatException) return ErrorCategory.serialization;
    if (e is ArgumentError || e is StateError) return ErrorCategory.validation;
    // Dart doesn't have a built-in SecurityException; customize as needed:
    if (e.runtimeType.toString().toLowerCase().contains('security')) {
      return ErrorCategory.permission;
    }
    if (e is SocketException) return ErrorCategory.network;
    return ErrorCategory.unknown;
  }

  static String _buildErrorMessage(
    String message,
    String source,
    ErrorSeverity severity,
    ErrorCategory category,
  ) =>
      '[$source] [$severity] [$category] $message';

  static void _logBySeverity(String msg, ErrorSeverity sev) {
    switch (sev) {
      case ErrorSeverity.low:
        debugPrint('DEBUG: $msg');
        break;
      case ErrorSeverity.medium:
        debugPrint('WARN: $msg');
        break;
      case ErrorSeverity.high:
        debugPrint('ERROR: $msg');
        break;
      case ErrorSeverity.critical:
        debugPrint('CRITICAL: $msg');
        break;
    }
  }
}
