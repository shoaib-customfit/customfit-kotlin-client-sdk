import 'device_context.dart';
import 'application_info.dart';
import 'evaluation_context.dart';
import 'context_type.dart';
import 'private_attributes_request.dart';

/// User model defining identity and attributes for the CustomFit SDK
class CFUser {
  /// User customer ID
  final String? userCustomerId;

  /// Whether the user is anonymous
  final bool anonymous;

  /// Private fields that should not be sent to analytics
  final PrivateAttributesRequest? privateFields;

  /// Session fields that should not be sent to analytics
  final PrivateAttributesRequest? sessionFields;

  /// User properties as key-value pairs
  final Map<String, dynamic> properties;

  /// Evaluation contexts for the user
  final List<EvaluationContext> contexts;

  /// Device context information
  final DeviceContext? device;

  /// Application information
  final ApplicationInfo? application;

  /// Constructor
  CFUser({
    this.userCustomerId,
    this.anonymous = false,
    this.privateFields,
    this.sessionFields,
    this.properties = const {},
    this.contexts = const [],
    this.device,
    this.application,
  });

  /// Creates a CFUser from a map representation
  factory CFUser.fromMap(Map<String, dynamic> map) {
    return CFUser(
      userCustomerId: map['user_customer_id'] as String?,
      anonymous: map['anonymous'] as bool? ?? false,
      privateFields: map['private_fields'] != null
          ? PrivateAttributesRequest.fromMap(
              map['private_fields'] as Map<String, dynamic>)
          : null,
      sessionFields: map['session_fields'] != null
          ? PrivateAttributesRequest.fromMap(
              map['session_fields'] as Map<String, dynamic>)
          : null,
      properties: (map['properties'] as Map<String, dynamic>?) ?? {},
      contexts: (map['contexts'] as List<dynamic>?)
              ?.map((e) => EvaluationContext.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      device: map['device'] != null
          ? DeviceContext.fromMap(map['device'] as Map<String, dynamic>)
          : null,
      application: map['application'] != null
          ? ApplicationInfo.fromMap(map['application'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert user to a map for serialization
  Map<String, dynamic> toMap() {
    // Start with a copy of properties
    final updatedProperties = Map<String, dynamic>.from(properties);

    // Inject contexts, device, application into properties (if present)
    if (contexts.isNotEmpty) {
      updatedProperties['contexts'] = contexts.map((e) => e.toMap()).toList();
    }
    if (device != null) {
      updatedProperties['device'] = device!.toMap();
    }
    if (application != null) {
      updatedProperties['application'] = application!.toMap();
    }

    return {
      'user_customer_id': userCustomerId,
      'anonymous': anonymous,
      if (privateFields != null) 'private_fields': privateFields!.toMap(),
      if (sessionFields != null) 'session_fields': sessionFields!.toMap(),
      'properties': updatedProperties,
    }..removeWhere((_, v) => v == null);
  }

  /// Create a copy with an added property
  CFUser addProperty(String key, dynamic value) {
    final updatedProperties = Map<String, dynamic>.from(properties);
    updatedProperties[key] = value;
    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: privateFields,
      sessionFields: sessionFields,
      properties: updatedProperties,
      contexts: contexts,
      device: device,
      application: application,
    );
  }

  /// Create a copy with added context
  CFUser addContext(EvaluationContext context) {
    final updatedContexts = List<EvaluationContext>.from(contexts);
    updatedContexts.add(context);
    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: privateFields,
      sessionFields: sessionFields,
      properties: properties,
      contexts: updatedContexts,
      device: device,
      application: application,
    );
  }

  /// Create a copy with removed context
  CFUser removeContext(ContextType type, String key) {
    final updatedContexts = contexts
        .where((context) => !(context.type == type && context.key == key))
        .toList();
    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: privateFields,
      sessionFields: sessionFields,
      properties: properties,
      contexts: updatedContexts,
      device: device,
      application: application,
    );
  }

  /// Create a copy with updated device context
  CFUser withDeviceContext(DeviceContext device) {
    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: privateFields,
      sessionFields: sessionFields,
      properties: properties,
      contexts: contexts,
      device: device,
      application: application,
    );
  }

  /// Create a copy with updated application info
  CFUser withApplicationInfo(ApplicationInfo application) {
    return CFUser(
      userCustomerId: userCustomerId,
      anonymous: anonymous,
      privateFields: privateFields,
      sessionFields: sessionFields,
      properties: properties,
      contexts: contexts,
      device: device,
      application: application,
    );
  }
}
