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
    String formattedMessage;

    if (message.contains('API POLL')) {
      formattedMessage = '📡 $message';
      developer.log(formattedMessage, name: _logPrefix, level: 500);
      // Always print to terminal for better visibility
      print('$_logPrefix: $formattedMessage');
    } else if (message.contains('SUMMARY')) {
      formattedMessage = '📊 $message';
      developer.log(formattedMessage, name: _logPrefix, level: 500);
      print('$_logPrefix: $formattedMessage');
    } else if (message.contains('CONFIG VALUE') ||
        message.contains('CONFIG UPDATE')) {
      formattedMessage = '🔧 $message';
      developer.log(formattedMessage, name: _logPrefix, level: 500);
      print('$_logPrefix: $formattedMessage');
    } else if (message.contains('TRACK') || message.contains('🔔')) {
      formattedMessage = '🔔 $message';
      developer.log(formattedMessage, name: _logPrefix, level: 500);
      print('$_logPrefix: $formattedMessage');
    } else {
      formattedMessage = message;
      developer.log(formattedMessage, name: _logPrefix, level: 500);
      print('$_logPrefix: $formattedMessage');
    }
  }

  /// Log a debug message
  static void d(String message) {
    if (enabled && debugEnabled) {
      developer.log(message, name: _logPrefix, level: 500);
      // Always print debug logs to terminal
      print('$_logPrefix [DEBUG]: $message');
    }
  }

  /// Log an info message
  static void i(String message) {
    if (enabled) {
      developer.log(message, name: _logPrefix, level: 800);
      print('$_logPrefix [INFO]: $message');
    }
  }

  /// Log a warning message
  static void w(String message) {
    if (enabled) {
      developer.log(message, name: _logPrefix, level: 900);
      print('$_logPrefix [WARN]: $message');
    }
  }

  /// Log an error message
  static void e(String message) {
    if (enabled) {
      developer.log(message, name: _logPrefix, level: 1000);
      print('$_logPrefix [ERROR]: $message');
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
      print('$_logPrefix [EXCEPTION]: $message\nError: $error');
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
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
