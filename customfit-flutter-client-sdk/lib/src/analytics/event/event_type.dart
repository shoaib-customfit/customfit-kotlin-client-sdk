/// Represents the type of events that can be tracked
enum EventType {
  /// Session start event
  sessionStart,

  /// Session end event
  sessionEnd,

  /// Feature flag usage event
  featureFlagUsage,

  /// Screen view event
  screenView,

  /// User action event
  userAction,

  /// Custom event type
  custom,

  /// Error event
  error;

  /// Gets the string name of the event type
  String get name {
    switch (this) {
      case EventType.sessionStart:
        return 'session_start';
      case EventType.sessionEnd:
        return 'session_end';
      case EventType.featureFlagUsage:
        return 'feature_flag_usage';
      case EventType.screenView:
        return 'screen_view';
      case EventType.userAction:
        return 'user_action';
      case EventType.custom:
        return 'custom';
      case EventType.error:
        return 'error';
    }
  }
}

/// Extension methods for EventType
extension EventTypeExtension on EventType {
  /// Convert an event type string to EventType enum
  static EventType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'session_start':
        return EventType.sessionStart;
      case 'session_end':
        return EventType.sessionEnd;
      case 'feature_flag_usage':
        return EventType.featureFlagUsage;
      case 'screen_view':
        return EventType.screenView;
      case 'user_action':
        return EventType.userAction;
      case 'error':
        return EventType.error;
      default:
        return EventType.custom;
    }
  }
}
