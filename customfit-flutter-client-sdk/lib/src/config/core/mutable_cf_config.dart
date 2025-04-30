import 'cf_config.dart';

/// A mutable wrapper around the immutable CFConfig.
///
/// This class allows certain configuration properties to be changed at runtime
/// while keeping most of the configuration immutable.
class MutableCFConfig {
  /// The underlying immutable configuration
  final CFConfig config;

  /// Whether the SDK is in offline mode
  bool _offlineMode;

  /// Constructor
  MutableCFConfig(this.config) : _offlineMode = config.offlineMode;

  /// Get whether the SDK is in offline mode
  bool get offlineMode => _offlineMode;

  /// Get whether auto environment attributes are enabled
  bool get autoEnvAttributesEnabled => config.autoEnvAttributesEnabled;

  /// Set offline mode
  void setOfflineMode(bool offlineMode) {
    _offlineMode = offlineMode;
  }
}
