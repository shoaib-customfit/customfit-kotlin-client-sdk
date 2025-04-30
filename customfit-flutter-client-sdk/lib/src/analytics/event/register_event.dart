import 'dart:convert';
import '../../core/model/cf_user.dart';
import 'event_data.dart';

/// Mirrors Kotlin’s RegisterEvent data class
class RegisterEvent {
  final List<EventData> events;
  final CFUser user;

  RegisterEvent({required this.events, required this.user});

  Map<String, dynamic> toMap() {
    return {
      'events': events.map((e) => e.toMap()).toList(),
      'user': user.toMap(),
    };
  }

  String toJson() => jsonEncode(toMap());

  factory RegisterEvent.fromMap(Map<String, dynamic> m) {
    return RegisterEvent(
      events: (m['events'] as List)
          .map((e) => EventData.fromMap(e as Map<String, dynamic>))
          .toList(),
      user: CFUser.fromMap(m['user'] as Map<String, dynamic>),
    );
  }

  factory RegisterEvent.fromJson(String json) =>
      RegisterEvent.fromMap(jsonDecode(json) as Map<String, dynamic>);
}
