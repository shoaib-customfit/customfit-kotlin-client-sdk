/// Listener for feature flag changes.
///
/// This interface is used to listen for changes to feature flags.
abstract class FeatureFlagChangeListener<T> {
  /// Called when a feature flag value changes.
  ///
  /// [oldValue] is the previous value of the flag.
  /// [newValue] is the new value of the flag.
  void onFeatureFlagChange(T? oldValue, T? newValue);
}
