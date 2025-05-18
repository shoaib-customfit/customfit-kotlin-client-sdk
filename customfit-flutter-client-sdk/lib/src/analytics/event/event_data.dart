// lib/src/analytics/event/event_data.dart

import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../core/logging/logger.dart';
import 'event_type.dart';

/// Data class representing an analytics event, mirroring Kotlin's EventData
class EventData {
  /// Customer/user ID associated with the event
  final String eventCustomerId;

  /// Type of event
  final EventType eventType;

  /// Event properties as key-value pairs
  final Map<String, dynamic> properties;

  /// Timestamp when the event occurred
  final DateTime eventTimestamp;

  /// Session ID associated with the event
  final String? sessionId;

  /// Unique ID for the event insertion
  final String? insertId;

  // ISO 8601 format with milliseconds and timezone
  static final _formatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSSX');

  /// Constructor
  EventData({
    required this.eventCustomerId,
    required this.eventType,
    required this.properties,
    required this.eventTimestamp,
    this.sessionId,
    this.insertId,
  });

  /// Factory to create a validated EventData with default timestamp/ID
  static EventData create({
    required String eventCustomerId,
    EventType eventType = EventType.track,
    Map<String, dynamic> properties = const {},
    DateTime? timestamp,
    String? sessionId,
    String? insertId,
  }) {
    final validProps = _validateProperties(properties);
    return EventData(
      eventCustomerId: eventCustomerId,
      eventType: eventType,
      properties: validProps,
      eventTimestamp: timestamp ?? DateTime.now().toUtc(),
      sessionId: sessionId,
      insertId: insertId ?? const Uuid().v4(),
    );
  }

  /// Ensure no null values and log warnings exactly like Kotlin
  static Map<String, dynamic> _validateProperties(Map<String, dynamic> props) {
    final validated = <String, dynamic>{};
    props.forEach((k, v) {
      if (v != null) validated[k] = v;
    });
    final removed = props.length - validated.length;
    if (removed > 0) {
      Logger.w('Removed $removed null property values from event');
    }
    if (validated.length > 50) {
      Logger.w(
          'Large number of properties (${validated.length}) for event. Consider reducing for better performance');
    }
    return validated;
  }

  /// Convert to a Map for JSON serialization
  Map<String, dynamic> toMap() {
    return {
      'event_customer_id': eventCustomerId,
      'event_type': eventType.toApiString(),
      'properties': properties,
      'event_timestamp': _formatter.format(eventTimestamp),
      if (sessionId != null) 'session_id': sessionId,
      if (insertId != null) 'insert_id': insertId,
    };
  }

  /// Convert to JSON string
  String toJson() => jsonEncode(toMap());

  /// Create from a Map
  factory EventData.fromMap(Map<String, dynamic> m) {
    return EventData(
      eventCustomerId: m['event_customer_id'] as String,
      eventType: EventTypeExtension.fromString(m['event_type'] as String),
      properties: Map<String, dynamic>.from(m['properties'] ?? {}),
      eventTimestamp: DateTime.parse(m['event_timestamp'] as String),
      sessionId: m['session_id'] as String?,
      insertId: m['insert_id'] as String?,
    );
  }

  /// Create from JSON string
  factory EventData.fromJson(String json) =>
      EventData.fromMap(jsonDecode(json) as Map<String, dynamic>);
}
