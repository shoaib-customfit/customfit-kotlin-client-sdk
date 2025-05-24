import 'package:flutter/foundation.dart';

import '../../core/model/cf_user.dart';
import '../../core/model/evaluation_context.dart';
import '../../core/model/context_type.dart';
import '../../core/model/device_context.dart';
import '../../core/model/application_info.dart';

/// Interface for UserManager
abstract class UserManager {
  /// Get the current user
  CFUser getUser();

  /// Update the current user
  void updateUser(CFUser user);

  /// Add a property to the user
  void addUserProperty(String key, dynamic value);

  /// Add a string property to the user
  void addStringProperty(String key, String value);

  /// Add a number property to the user
  void addNumberProperty(String key, num value);

  /// Add a boolean property to the user
  void addBooleanProperty(String key, bool value);

  /// Add a date property to the user
  void addDateProperty(String key, DateTime value);

  /// Add a geolocation property to the user
  void addGeoPointProperty(String key, double lat, double lon);

  /// Add a JSON property to the user
  void addJsonProperty(String key, Map<String, dynamic> value);

  /// Add multiple properties to the user
  void addUserProperties(Map<String, dynamic> properties);

  /// Get all user properties
  Map<String, dynamic> getUserProperties();

  /// Add a context to the user
  void addContext(EvaluationContext context);

  /// Remove a context from the user
  void removeContext(ContextType type, String key);

  /// Update the device context
  void updateDeviceContext(DeviceContext deviceContext);

  /// Update the application info
  void updateApplicationInfo(ApplicationInfo applicationInfo);
}

/// Implementation of UserManager
class UserManagerImpl implements UserManager {
  // Current user
  CFUser _user;

  // Listeners for user changes
  final List<void Function(CFUser)> _userChangeListeners = [];

  /// Create a new UserManagerImpl
  UserManagerImpl(CFUser initialUser) : _user = initialUser;

  @override
  CFUser getUser() {
    return _user;
  }

  @override
  void updateUser(CFUser user) {
    _user = user;
    _notifyUserChangeListeners();
  }

  @override
  void addUserProperty(String key, dynamic value) {
    _user = _user.addProperty(key, value);
    _notifyUserChangeListeners();
  }

  @override
  void addStringProperty(String key, String value) {
    addUserProperty(key, value);
  }

  @override
  void addNumberProperty(String key, num value) {
    addUserProperty(key, value);
  }

  @override
  void addBooleanProperty(String key, bool value) {
    addUserProperty(key, value);
  }

  @override
  void addDateProperty(String key, DateTime value) {
    addUserProperty(key, value.toIso8601String());
  }

  @override
  void addGeoPointProperty(String key, double lat, double lon) {
    addUserProperty(key, {'lat': lat, 'lon': lon});
  }

  @override
  void addJsonProperty(String key, Map<String, dynamic> value) {
    addUserProperty(key, value);
  }

  @override
  void addUserProperties(Map<String, dynamic> properties) {
    for (final entry in properties.entries) {
      addUserProperty(entry.key, entry.value);
    }
  }

  @override
  Map<String, dynamic> getUserProperties() {
    return Map<String, dynamic>.from(_user.properties);
  }

  @override
  void addContext(EvaluationContext context) {
    _user = _user.addContext(context);
    _notifyUserChangeListeners();
  }

  @override
  void removeContext(ContextType type, String key) {
    _user = _user.removeContext(type, key);
    _notifyUserChangeListeners();
  }

  @override
  void updateDeviceContext(DeviceContext deviceContext) {
    _user = _user.withDeviceContext(deviceContext);
    _notifyUserChangeListeners();
  }

  @override
  void updateApplicationInfo(ApplicationInfo applicationInfo) {
    _user = _user.withApplicationInfo(applicationInfo);
    _notifyUserChangeListeners();
  }

  /// Add a listener for user changes
  void addUserChangeListener(void Function(CFUser) listener) {
    _userChangeListeners.add(listener);
  }

  /// Remove a listener for user changes
  void removeUserChangeListener(void Function(CFUser) listener) {
    _userChangeListeners.remove(listener);
  }

  /// Notify listeners of user changes
  void _notifyUserChangeListeners() {
    for (final listener
        in List<void Function(CFUser)>.from(_userChangeListeners)) {
      try {
        listener(_user);
      } catch (e) {
        debugPrint('Error notifying user change listener: $e');
      }
    }
  }
}
