import 'dart:convert';

import 'event_type.dart';

/// Represents event data to be sent to the backend
class EventData {
  /// Unique identifier for the event
  final String eventId;

  /// Customer ID associated with the event
  final String eventCustomerId;

  /// Type of the event
  final EventType eventType;

  /// Properties/attributes associated with the event
  final Map<String, dynamic> properties;

  /// Session ID for the event
  final String sessionId;

  /// Timestamp when the event occurred
  final int eventTimestamp;

  /// Creates a new event data instance
  EventData({
    required this.eventId,
    required this.eventCustomerId,
    required this.eventType,
    this.properties = const {},
    required this.sessionId,
    required this.eventTimestamp,
  });

  /// Factory method to create an event with automatically generated values where needed
  static EventData create({
    required String eventCustomerId,
    required EventType eventType,
    Map<String, dynamic> properties = const {},
    required String sessionId,
    int? eventTimestamp,
  }) {
    return EventData(
      eventId: '${DateTime.now().millisecondsSinceEpoch}-${eventType.name}',
      eventCustomerId: eventCustomerId,
      eventType: eventType,
      properties: properties,
      sessionId: sessionId,
      eventTimestamp: eventTimestamp ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Convert this event to a JSON map
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventCustomerId': eventCustomerId,
      'eventType': eventType.name,
      'properties': properties,
      'sessionId': sessionId,
      'eventTimestamp': eventTimestamp,
    };
  }

  /// Create an EventData instance from a JSON map
  factory EventData.fromMap(Map<String, dynamic> map) {
    return EventData(
      eventId: map['eventId'] as String,
      eventCustomerId: map['eventCustomerId'] as String,
      eventType: EventTypeExtension.fromString(map['eventType'] as String),
      properties: map['properties'] as Map<String, dynamic>,
      sessionId: map['sessionId'] as String,
      eventTimestamp: map['eventTimestamp'] as int,
    );
  }

  /// Convert to JSON string
  String toJson() => jsonEncode(toMap());

  /// Create from JSON string
  factory EventData.fromJson(String source) =>
      EventData.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
