import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../config/core/cf_config.dart';
import '../../core/error/cf_result.dart';
import '../../core/error/error_handler.dart';
import '../../core/error/error_severity.dart';
import '../../core/model/cf_user.dart';
import '../../network/connection/connection_information.dart';
import '../../network/connection/connection_manager.dart';
import '../../network/connection/connection_status.dart';
import '../../network/connection/connection_status_listener.dart';
import '../../network/http_client.dart';
import 'event_callback.dart';
import 'event_queue.dart';
import 'event_data.dart';
import 'event_type.dart';

/// Implements robust event tracking with batching, retry logic, and network awareness.
class EventTracker implements ConnectionStatusListener {
  static const String _source = 'EventTracker';

  final EventQueue _eventQueue = EventQueue(maxQueueSize: 100);
  final HttpClient _httpClient;
  final ConnectionManager _connectionManager;
  final CFUser _user;
  // ignore: unused_field
  final String _sessionId;
  // ignore: unused_field
  final CFConfig _config;

  bool _autoFlushEnabled = true;
  Timer? _flushTimer;
  EventCallback? _eventCallback;

  /// Creates a new event tracker with the given dependencies
  EventTracker(
    this._httpClient,
    this._connectionManager,
    this._user,
    this._sessionId,
    this._config,
  ) {
    _connectionManager.addConnectionStatusListener(this);
    _startFlushTimer();
  }

  /// Track a single event.
  ///
  /// Returns a result with event data or error.
  Future<CFResult<EventData>> trackEvent(String eventName,
      [Map<String, dynamic> properties = const {}]) async {
    try {
      // Validate event name
      if (eventName.isEmpty) {
        return CFResult.error('Event name cannot be blank');
      }

      // Create event data
      final internalEvent = EventData(
        eventCustomerId: _user.userCustomerId ?? 'anonymous',
        eventType: EventType.TRACK,
        properties: properties,
        eventTimestamp: DateTime.now().toUtc(),
      );

      // Add to queue
      _eventQueue.addEvent(internalEvent);

      // Notify callback if set
      if (_eventCallback != null) {
        try {
          // Using as cast to ensure type safety
          _eventCallback!(internalEvent);
        } catch (e) {
          ErrorHandler.handleException(
            e,
            'Error in event callback',
            source: _source,
            severity: ErrorSeverity.low,
          );
        }
      }

      // Flush if auto flush is enabled and connection is available
      if (_autoFlushEnabled &&
          _connectionManager.getConnectionStatus() ==
              ConnectionStatus.connected) {
        _maybeFlushEvents();
      }

      return CFResult.success(internalEvent);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Failed to track event',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error('Failed to track event: ${e.toString()}');
    }
  }

  /// Track multiple events.
  ///
  /// Returns a result with the tracked events or error.
  Future<CFResult<List<EventData>>> trackEvents(List<EventData> events) async {
    try {
      // Add to queue
      _eventQueue.addEvents(events);

      // Notify callback for each event if set
      if (_eventCallback != null) {
        for (final event in events) {
          try {
            // Using as cast to ensure type safety
            _eventCallback!(event);
          } catch (e) {
            ErrorHandler.handleException(
              e,
              'Error in event callback',
              source: _source,
              severity: ErrorSeverity.low,
            );
          }
        }
      }

      // Flush if auto flush is enabled and connection is available
      if (_autoFlushEnabled &&
          _connectionManager.getConnectionStatus() ==
              ConnectionStatus.connected) {
        _maybeFlushEvents();
      }

      return CFResult.success(events);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Failed to track events',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error('Failed to track events: ${e.toString()}');
    }
  }

  /// This will attempt to send all events in the queue immediately.
  /// Returns a result indicating success or failure.
  Future<CFResult<bool>> flush() async {
    if (_eventQueue.isEmpty) {
      return CFResult.success(true);
    }

    if (_connectionManager.getConnectionStatus() !=
        ConnectionStatus.connected) {
      return CFResult.error('Cannot flush events: network not connected');
    }

    try {
      // Get batch of events to send
      final events = _eventQueue.popEventBatch(100); // Default batch size
      if (events.isEmpty) {
        return CFResult.success(true);
      }

      // Prepare events for sending
      final eventsJson = events.map((e) => e.toMap()).toList();
      final payload = jsonEncode(eventsJson);

      // Send events to server
      final url = 'https://api.customfit.ai/v2/events';
      final result = await _httpClient.post(
        url,
        data: payload,
      );

      if (result.isSuccess) {
        debugPrint('Successfully sent ${events.length} events');
        _connectionManager.recordConnectionSuccess();

        // If we have more events, trigger another flush
        if (!_eventQueue.isEmpty) {
          _maybeFlushEvents();
        }

        return CFResult.success(true);
      } else {
        final errorMessage = 'Failed to send events to server';
        debugPrint(errorMessage);

        // Put events back in queue
        _eventQueue.addEvents(events);

        // Record connection failure
        _connectionManager.recordConnectionFailure(errorMessage);

        return CFResult.error(errorMessage);
      }
    } catch (e) {
      ErrorHandler.handleException(
        e,
        'Failed to flush events',
        source: _source,
        severity: ErrorSeverity.medium,
      );
      return CFResult.error('Failed to flush events: ${e.toString()}');
    }
  }

  /// Implement ConnectionStatusListener
  @override
  void onConnectionStatusChanged(
      ConnectionStatus status, ConnectionInformation info) {
    if (status == ConnectionStatus.connected && _autoFlushEnabled) {
      _maybeFlushEvents();
    }
  }

  /// Set a callback to be notified when events are tracked.
  void setEventCallback(EventCallback? callback) {
    _eventCallback = callback;
  }

  /// Enable or disable automatic event flushing.
  void setAutoFlush(bool enabled) {
    _autoFlushEnabled = enabled;
    if (enabled) {
      _startFlushTimer();
    } else {
      _stopFlushTimer();
    }
  }

  /// Shutdown the event tracker and release resources.
  Future<void> shutdown() async {
    _stopFlushTimer();
    _connectionManager.removeConnectionStatusListener(this);
    await flush();
  }

  /// Start the timer for flushing events periodically.
  void _startFlushTimer() {
    _stopFlushTimer();
    if (_autoFlushEnabled) {
      _flushTimer = Timer.periodic(
        Duration(milliseconds: 30000), // 30 seconds default
        (_) => _maybeFlushEvents(),
      );
    }
  }

  /// Stop the flush timer.
  void _stopFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Try to flush events if conditions are right
  void _maybeFlushEvents() {
    if (!_eventQueue.isEmpty &&
        _connectionManager.getConnectionStatus() ==
            ConnectionStatus.connected) {
      flush();
    }
  }

  /// Flushes events from the event queue to the server.
  /// This is a convenience method that forwards to the internal flush method.
  Future<CFResult<bool>> flushEvents() async {
    return await flush();
  }
}
