// lib/src/client/listener/feature_flag_change_listener.dart

/// Listener interface for receiving a specific feature flag change.
abstract class FeatureFlagChangeListener<T> {
  /// Called when the feature flag [flagKey] changes to [newValue].
  ///
  /// [oldValue] is the previous value (or null if none).
  void onFeatureFlagChange(String flagKey, T? oldValue, T newValue);
}
