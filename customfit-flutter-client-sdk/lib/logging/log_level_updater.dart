import '../src/config/core/cf_config.dart';
import 'logger.dart';

/// Helper class to update log levels based on configuration
class LogLevelUpdater {
  /// Updates the log level based on the provided configuration
  static void updateLogLevel(CFConfig config) {
    final logEnabled = config.loggingEnabled;
    final debugLogEnabled = config.debugLoggingEnabled;

    Logger.configure(
      enabled: logEnabled,
      debugEnabled: debugLogEnabled,
    );
  }
}
