import 'battery_state.dart';

/// Interface for battery state change listeners.
abstract class BatteryStateListener {
  /// Called when the battery state changes.
  ///
  /// [newState] is the new state of the battery.
  /// [level] is the current battery level (0-100).
  void onBatteryStateChanged(BatteryState newState, int level);
}
