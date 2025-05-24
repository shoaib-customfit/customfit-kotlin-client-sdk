/// Represents the type of events that can be tracked
enum EventType {
  /// Track custom event
  TRACK;

  /// Gets the string name of the event type
  String get name {
    switch (this) {
      case EventType.TRACK:
        return 'TRACK';
    }
  }
}

/// Extension methods for EventType
extension EventTypeExtension on EventType {
  /// Convert an event type string to EventType enum
  static EventType fromString(String value) {
    switch (value) {
      case 'TRACK':
        return EventType.TRACK;
      default:
        return EventType.TRACK; // Default to TRACK for any unrecognized value
    }
  }
}
