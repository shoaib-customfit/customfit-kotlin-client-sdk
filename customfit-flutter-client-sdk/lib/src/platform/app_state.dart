import 'package:flutter/widgets.dart';

/// App state enum defining the possible states of the application
enum AppState {
  /// App is in the foreground and visible to the user
  foreground,

  /// App is in the background but still running
  background,

  /// App is in the process of being terminated
  terminated
}

/// Extension methods for converting between Flutter's AppLifecycleState
extension AppStateExtension on AppState {
  /// Convert Flutter's AppLifecycleState to AppState
  static AppState fromAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        return AppState.foreground;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        return AppState.background;
      case AppLifecycleState.detached:
        return AppState.terminated;
      default:
        return AppState.foreground;
    }
  }
}
