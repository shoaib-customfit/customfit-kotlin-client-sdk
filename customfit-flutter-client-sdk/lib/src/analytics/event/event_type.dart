enum EventType { track }

extension EventTypeExtension on EventType {
  /// Get string for API
  String toApiString() => name;

  /// Parse from API string
  static EventType fromString(String s) {
    switch (s.toUpperCase()) {
      case 'TRACK':
        return EventType.track;
      default:
        throw ArgumentError('Unknown EventType: $s');
    }
  }
}
