/// Defines the type of context for feature flag evaluation
enum ContextType {
  /// User context type for user-specific targeting
  user,

  /// Device context type for device-specific targeting
  device,

  /// App context type for application-specific targeting
  app,

  /// Session context type for session-specific targeting
  session,

  /// Organization context type for organization-specific targeting
  organization,

  /// Custom context type for custom targeting rules
  custom;

  /// Convert the enum to string value
  String toValue() {
    switch (this) {
      case ContextType.user:
        return 'user';
      case ContextType.device:
        return 'device';
      case ContextType.app:
        return 'app';
      case ContextType.session:
        return 'session';
      case ContextType.organization:
        return 'organization';
      case ContextType.custom:
        return 'custom';
    }
  }

  /// Create ContextType from string value
  static ContextType? fromString(String value) {
    switch (value.toLowerCase()) {
      case 'user':
        return ContextType.user;
      case 'device':
        return ContextType.device;
      case 'app':
        return ContextType.app;
      case 'session':
        return ContextType.session;
      case 'organization':
        return ContextType.organization;
      case 'custom':
        return ContextType.custom;
      default:
        return null;
    }
  }
}
