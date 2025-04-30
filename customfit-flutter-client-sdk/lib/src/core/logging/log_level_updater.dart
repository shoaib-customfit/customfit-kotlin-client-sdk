import '../../config/core/cf_config.dart';
import 'logger.dart';

/// Utility to update log level based on configuration
class LogLevelUpdater {
  /// Update log level based on the provided configuration
  static void updateLogLevel(CFConfig config) {
    Logger.configure(
      enabled: config.loggingEnabled,
      debugEnabled: config.debugLoggingEnabled,
    );
  }
}
