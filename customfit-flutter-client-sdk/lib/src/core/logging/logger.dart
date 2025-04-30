import 'dart:developer' as developer;

/// SDK logging utility class
class Logger {
  /// Whether logging is enabled
  static bool enabled = true;

  /// Whether debug logging is enabled
  static bool debugEnabled = false;

  /// Log a debug message
  static void d(String message) {
    if (enabled && debugEnabled) {
      developer.log(message, name: 'CustomFit', level: 500);
    }
  }

  /// Log an info message
  static void i(String message) {
    if (enabled) {
      developer.log(message, name: 'CustomFit', level: 800);
    }
  }

  /// Log a warning message
  static void w(String message) {
    if (enabled) {
      developer.log(message, name: 'CustomFit', level: 900);
    }
  }

  /// Log an error message
  static void e(String message) {
    if (enabled) {
      developer.log(message, name: 'CustomFit', level: 1000);
    }
  }

  /// Configure logging
  static void configure({
    required bool enabled,
    required bool debugEnabled,
  }) {
    Logger.enabled = enabled;
    Logger.debugEnabled = debugEnabled;
  }
}
