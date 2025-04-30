import 'app_state.dart';

/// Interface for app state change listeners.
abstract class AppStateListener {
  /// Called when the app state changes.
  ///
  /// [newState] is the new state of the application.
  void onAppStateChanged(AppState newState);
}
