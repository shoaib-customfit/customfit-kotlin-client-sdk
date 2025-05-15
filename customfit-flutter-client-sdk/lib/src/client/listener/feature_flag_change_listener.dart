/// Listener for feature flag changes.
///
/// This interface is used to listen for changes to feature flags.
abstract class FeatureFlagChangeListener {
  /// Called when a feature flag value changes.
  ///
  /// [flagKey] is the key of the flag that changed.
  /// [oldValue] is the previous value of the flag.
  /// [newValue] is the new value of the flag.
  void onFeatureFlagChanged(String flagKey, dynamic oldValue, dynamic newValue);
}
