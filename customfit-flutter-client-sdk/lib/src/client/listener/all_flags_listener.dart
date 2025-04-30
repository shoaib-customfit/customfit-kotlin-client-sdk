// lib/src/client/listener/all_flags_listener.dart

/// Listener interface for receiving all feature flag changes.
abstract class AllFlagsListener {
  /// Called when any feature flag changes.
  ///
  /// [flagMap] is a map of all current feature flags and their values.
  void onFlagsChange(Map<String, dynamic> flagMap);
}
