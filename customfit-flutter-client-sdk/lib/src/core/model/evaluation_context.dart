import 'context_type.dart';

/// An evaluation context that can be used for targeting
class EvaluationContext {
  /// The context type
  final ContextType type;

  /// Key identifying this context
  final String key;

  /// Name of this context (optional)
  final String? name;

  /// Properties associated with this context
  final Map<String, dynamic> properties;

  /// Private attributes that should not be sent to analytics
  final List<String> privateAttributes;

  /// Constructor
  EvaluationContext({
    required this.type,
    required this.key,
    this.name,
    this.properties = const {},
    this.privateAttributes = const [],
  });

  /// Creates an EvaluationContext from a map representation
  factory EvaluationContext.fromMap(Map<String, dynamic> map) {
    return EvaluationContext(
      type: ContextType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => ContextType.custom,
      ),
      key: map['key'] as String,
      name: map['name'] as String?,
      properties: (map['properties'] as Map<String, dynamic>?) ?? {},
      privateAttributes: (map['private_attributes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Converts the evaluation context to a map for serialization
  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'key': key,
      if (name != null) 'name': name,
      'properties': properties,
      'private_attributes': privateAttributes,
    };
  }
}
