/// Represents a request for private attributes that should not be sent to analytics
class PrivateAttributesRequest {
  /// List of user fields to keep private
  final List<String> userFields;

  /// Properties to keep private
  final Map<String, dynamic> properties;

  /// Constructor
  PrivateAttributesRequest({
    this.userFields = const [],
    this.properties = const {},
  });

  /// Creates a PrivateAttributesRequest from a map representation
  factory PrivateAttributesRequest.fromMap(Map<String, dynamic> map) {
    return PrivateAttributesRequest(
      userFields: (map['user_fields'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      properties: (map['properties'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Converts the private attributes request to a map for serialization
  Map<String, dynamic> toMap() {
    return {
      'user_fields': userFields,
      'properties': properties,
    };
  }
}
