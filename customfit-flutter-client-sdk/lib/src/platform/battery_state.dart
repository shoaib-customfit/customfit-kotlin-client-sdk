import 'package:battery_plus/battery_plus.dart' as battery_plus;

/// Battery state enum defining the possible states of the device battery
enum BatteryState {
  /// Battery is in a full state (90% or above)
  full,

  /// Battery is in a normal state (between 20% and 90%)
  normal,

  /// Battery is in a low state (below 20%)
  low,

  /// Battery state is unknown
  unknown,

  /// Device is charging
  charging
}

/// Extension methods for converting between battery_plus BatteryState
extension BatteryStateExtension on BatteryState {
  /// Convert battery_plus BatteryState to our BatteryState
  static BatteryState fromBatteryPlusState(
      battery_plus.BatteryState state, int level) {
    // If charging, return charging state regardless of level
    if (state == battery_plus.BatteryState.charging) {
      return BatteryState.charging;
    }

    // Otherwise determine state based on level
    if (level >= 90) {
      return BatteryState.full;
    } else if (level >= 20) {
      return BatteryState.normal;
    } else if (level > 0) {
      return BatteryState.low;
    } else {
      return BatteryState.unknown;
    }
  }
}
