/// Listener interface for receiving all feature flag changes.
abstract class AllFlagsListener {
  /// Called when any feature flag changes.
  ///
  /// [oldFlags] is a map of all previous feature flags and their values.
  /// [newFlags] is a map of all current feature flags and their values.
  void onAllFlagsChanged(
      Map<String, dynamic> oldFlags, Map<String, dynamic> newFlags);
}
