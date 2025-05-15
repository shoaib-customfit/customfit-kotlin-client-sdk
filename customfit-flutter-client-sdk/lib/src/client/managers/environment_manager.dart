import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../platform/background_state_monitor.dart';
import '../../platform/device_info_detector.dart';
import '../../platform/application_info_detector.dart';
import 'user_manager.dart';

/// Interface for EnvironmentManager
abstract class EnvironmentManager {
  /// Detect environment information
  Future<void> detectEnvironmentInfo(bool force);
  
  /// Shutdown the environment manager
  void shutdown();
}

/// Implementation of EnvironmentManager
class EnvironmentManagerImpl implements EnvironmentManager {
  final BackgroundStateMonitor _backgroundStateMonitor;
  final UserManager _userManager;

  bool _isDetecting = false;
  DateTime? _lastDetectionTime;
  
  EnvironmentManagerImpl({
    required BackgroundStateMonitor backgroundStateMonitor,
    required UserManager userManager,
  }) : _backgroundStateMonitor = backgroundStateMonitor,
       _userManager = userManager;

  @override
  Future<void> detectEnvironmentInfo(bool force) async {
    // Skip if already detecting or if not forced and detected recently
    if (_isDetecting || (!force && _lastDetectionTime != null && 
        DateTime.now().difference(_lastDetectionTime!).inMinutes < 60)) {
      return;
    }
    
    _isDetecting = true;
    
    try {
      // Detect device info
      final deviceContext = await DeviceInfoDetector.detectDeviceInfo();
      _userManager.updateDeviceContext(deviceContext);
      
      // Detect application info
      final applicationInfo = await ApplicationInfoDetector.detectApplicationInfo();
      if (applicationInfo != null) {
        _userManager.updateApplicationInfo(applicationInfo);
      }
      
      _lastDetectionTime = DateTime.now();
    } catch (e) {
      debugPrint('Error detecting environment info: $e');
    } finally {
      _isDetecting = false;
    }
  }
  
  @override
  void shutdown() {
    // Clean up resources
    _backgroundStateMonitor.shutdown();
  }
}
