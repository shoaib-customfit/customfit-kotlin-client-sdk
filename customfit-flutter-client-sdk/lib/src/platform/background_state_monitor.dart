import 'app_state.dart';
import 'app_state_listener.dart';
import 'battery_state.dart';
import 'battery_state_listener.dart';

/// Abstract class for background state monitoring.
abstract class BackgroundStateMonitor {
  /// Add app state listener
  void addAppStateListener(AppStateListener listener);

  /// Remove app state listener
  void removeAppStateListener(AppStateListener listener);

  /// Add battery state listener
  void addBatteryStateListener(BatteryStateListener listener);

  /// Remove battery state listener
  void removeBatteryStateListener(BatteryStateListener listener);

  /// Get current app state
  AppState getCurrentAppState();

  /// Get current battery state
  BatteryState getCurrentBatteryState();

  /// Get current battery level (0-100)
  int getCurrentBatteryLevel();

  /// Clean up resources
  void shutdown();
}
