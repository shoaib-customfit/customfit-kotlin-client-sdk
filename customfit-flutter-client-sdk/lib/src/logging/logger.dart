import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kDebugMode;

/// SDK logging utility class that mimics Kotlin's Timber implementation
class Logger {
  /// Whether logging is enabled
  static bool enabled = true;

  /// Whether debug logging is enabled
  static bool debugEnabled = false;

  /// Log prefix to identify the SDK platform
  static const String _logPrefix = "Customfit.ai-SDK [Flutter]";

  /// Enhanced console output with emoji indicators
  static void _directConsoleOutput(String message) {
    if (message.contains('API POLL')) {
      developer.log('📡 $message', name: _logPrefix, level: 500);
    } else if (message.contains('SUMMARY')) {
      developer.log('📊 $message', name: _logPrefix, level: 500);
    } else if (message.contains('CONFIG VALUE') ||
        message.contains('CONFIG UPDATE')) {
      developer.log('🔧 $message', name: _logPrefix, level: 500);
    } else if (message.contains('TRACK') || message.contains('🔔')) {
      developer.log('🔔 $message', name: _logPrefix, level: 500);
    } else {
      developer.log(message, name: _logPrefix, level: 500);
    }
  }

  /// Log a debug message
  static void d(String message) {
    if (enabled && debugEnabled) {
      developer.log(message, name: _logPrefix, level: 500);
      if (kDebugMode) {
        _directConsoleOutput(message);
      }
    }
  }

  /// Log an info message
  static void i(String message) {
    if (enabled) {
      developer.log(message, name: _logPrefix, level: 800);
      if (kDebugMode) {
        _directConsoleOutput(message);
      }
    }
  }

  /// Log a warning message
  static void w(String message) {
    if (enabled) {
      developer.log(message, name: _logPrefix, level: 900);
      if (kDebugMode) {
        _directConsoleOutput(message);
      }
    }
  }

  /// Log an error message
  static void e(String message) {
    if (enabled) {
      developer.log(message, name: _logPrefix, level: 1000);
      if (kDebugMode) {
        _directConsoleOutput(message);
      }
    }
  }

  /// Log an error message with exception
  static void exception(Object error, String message,
      {StackTrace? stackTrace}) {
    if (enabled) {
      final errorMsg =
          '$message\nError: $error${stackTrace != null ? '\nStackTrace: $stackTrace' : ''}';
      developer.log(errorMsg,
          name: _logPrefix, level: 1000, error: error, stackTrace: stackTrace);
      if (kDebugMode) {
        _directConsoleOutput('ERROR: $message');
      }
    }
  }

  /// Configure logging
  static void configure({
    required bool enabled,
    required bool debugEnabled,
  }) {
    Logger.enabled = enabled;
    Logger.debugEnabled = debugEnabled;
    d('Logging configured: enabled=$enabled, debugEnabled=$debugEnabled');
  }
}
