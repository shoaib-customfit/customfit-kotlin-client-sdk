import 'dart:developer' as developer;

/// SDK logging utility class that mimics Kotlin's Timber implementation
class Logger {
  /// Whether logging is enabled
  static bool enabled = true;

  /// Whether debug logging is enabled
  static bool debugEnabled = false;

  /// Log prefix to identify the SDK platform
  static const String _logPrefix = "Customfit.ai-SDK [Flutter]";

  /// Log a debug message
  static void d(String message) {
    if (enabled && debugEnabled) {
      developer.log(message, name: _logPrefix, level: 500);
      // Always print debug logs to terminal
      // ignore: avoid_print
      print('$_logPrefix [DEBUG]: $message');
    }
  }

  /// Log an info message
  static void i(String message) {
    if (enabled) {
      developer.log(message, name: _logPrefix, level: 800);
      // ignore: avoid_print
      print('$_logPrefix [INFO]: $message');
    }
  }

  /// Log a warning message
  static void w(String message) {
    if (enabled) {
      developer.log(message, name: _logPrefix, level: 900);
      // ignore: avoid_print
      print('$_logPrefix [WARN]: $message');
    }
  }

  /// Log an error message
  static void e(String message) {
    if (enabled) {
      developer.log(message, name: _logPrefix, level: 1000);
      // ignore: avoid_print
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
      // ignore: avoid_print
      print('$_logPrefix [EXCEPTION]: $message\nError: $error');
      if (stackTrace != null) {
        // ignore: avoid_print
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
