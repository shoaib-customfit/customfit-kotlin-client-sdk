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
import '../../analytics/summary/summary_manager.dart';
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
  final CFConfig _config;

  // Added reference to SummaryManager to ensure summaries are flushed before events
  final SummaryManager? _summaryManager;

  bool _autoFlushEnabled = true;
  Timer? _flushTimer;
  EventCallback? _eventCallback;

  /// Creates a new event tracker with the given dependencies
  EventTracker(
    this._httpClient,
    this._connectionManager,
    this._user,
    this._sessionId,
    this._config, {
    SummaryManager? summaryManager,
  }) : _summaryManager = summaryManager {
    _connectionManager.addConnectionStatusListener(this);
    _startFlushTimer();
  }

  /// Track a single event.
  ///
  /// Returns a result with event data or error.
  Future<CFResult<EventData>> trackEvent(String eventName,
      [Map<String, dynamic> properties = const {}]) async {
    try {
      // Enhanced logging similar to Kotlin improvements
      debugPrint(
          '🔔 🔔 TRACK: Tracking event: $eventName with properties: $properties');

      // Flush summaries before tracking a new event if SummaryManager is provided
      if (_summaryManager != null) {
        debugPrint(
            '🔔 🔔 TRACK: Flushing summaries before tracking event: $eventName');
        await _summaryManager!.flushSummaries().then((result) {
          if (!result.isSuccess) {
            debugPrint(
                '🔔 🔔 TRACK: Failed to flush summaries: ${result.getErrorMessage()}');
          }
        });
      }

      // Validate event name
      if (eventName.isEmpty) {
        debugPrint('🔔 TRACK: Invalid event - Event name cannot be blank');
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
      if (_eventQueue.size >= _getMaxQueueSize()) {
        debugPrint(
            '🔔 TRACK: Event queue is full (size = ${_eventQueue.size}), dropping oldest event');
        ErrorHandler.handleError(
          'Event queue is full, dropping oldest event',
          source: _source,
          severity: ErrorSeverity.medium,
        );
        // Queue will handle dropping the oldest events automatically
      }

      _eventQueue.addEvent(internalEvent);
      debugPrint(
          '🔔 TRACK: Event added to queue: ${internalEvent.eventCustomerId}, queue size=${_eventQueue.size}');

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
        if (_eventQueue.size >= (_getMaxQueueSize() * 0.75).round()) {
          debugPrint(
              '🔔 TRACK: Queue size threshold reached (${_eventQueue.size}/${_getMaxQueueSize()}), triggering flush');
          _maybeFlushEvents();
        }
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
      debugPrint('🔔 🔔 TRACK: Tracking ${events.length} events');

      // Flush summaries before tracking new events if SummaryManager is provided
      if (_summaryManager != null) {
        debugPrint(
            '🔔 🔔 TRACK: Flushing summaries before tracking ${events.length} events');
        await _summaryManager!.flushSummaries().then((result) {
          if (!result.isSuccess) {
            debugPrint(
                '🔔 🔔 TRACK: Failed to flush summaries: ${result.getErrorMessage()}');
          }
        });
      }

      // Add to queue
      _eventQueue.addEvents(events);
      debugPrint(
          '🔔 TRACK: ${events.length} events added to queue, queue size=${_eventQueue.size}');

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
        if (_eventQueue.size >= (_getMaxQueueSize() * 0.75).round()) {
          debugPrint(
              '🔔 TRACK: Queue size threshold reached (${_eventQueue.size}/${_getMaxQueueSize()}), triggering flush');
          _maybeFlushEvents();
        }
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
    debugPrint('🔔 🔔 TRACK: Beginning event flush process');

    if (_eventQueue.isEmpty) {
      debugPrint('🔔 TRACK: No events to flush');
      return CFResult.success(true);
    }

    if (_connectionManager.getConnectionStatus() !=
        ConnectionStatus.connected) {
      debugPrint('🔔 TRACK: Cannot flush events: network not connected');
      return CFResult.error('Cannot flush events: network not connected');
    }

    try {
      // Flush summaries first
      if (_summaryManager != null) {
        debugPrint('🔔 🔔 TRACK: Flushing summaries before flushing events');
        await _summaryManager!.flushSummaries().then((result) {
          if (!result.isSuccess) {
            debugPrint(
                '🔔 🔔 TRACK: Failed to flush summaries: ${result.getErrorMessage()}');
          }
        });
      }

      // Get batch of events to send
      final events = _eventQueue.popEventBatch(100); // Default batch size
      if (events.isEmpty) {
        debugPrint('🔔 TRACK: No events to flush after drain');
        return CFResult.success(true);
      }

      debugPrint('🔔 TRACK: Flushing ${events.length} events to server');

      // Log individual events being sent (with limited detail for privacy)
      events.asMap().forEach((index, event) {
        debugPrint(
            '🔔 TRACK: Event #${index + 1}: ${event.eventCustomerId}, properties=${event.properties.keys.join(", ")}');
      });

      // Prepare events for sending
      final eventsJson = events.map((e) => e.toMap()).toList();
      final payload = jsonEncode(eventsJson);
      debugPrint('🔔 TRACK HTTP: Event payload size: ${payload.length} bytes');

      // Send events to server
      final url = 'https://api.customfit.ai/v2/events';
      debugPrint('🔔 TRACK HTTP: POST request to: $url');

      final result = await _httpClient.post(
        url,
        data: payload,
      );

      if (result.isSuccess) {
        debugPrint('🔔 TRACK: Successfully flushed ${events.length} events');
        _connectionManager.recordConnectionSuccess();

        // If we have more events, trigger another flush
        if (!_eventQueue.isEmpty) {
          debugPrint(
              '🔔 TRACK: Queue still has events, triggering another flush');
          _maybeFlushEvents();
        }

        return CFResult.success(true);
      } else {
        final errorMessage =
            'Failed to send events to server: ${result.getErrorMessage()}';
        debugPrint('🔔 TRACK HTTP: $errorMessage');

        // Put events back in queue
        debugPrint(
            '🔔 TRACK HTTP: Failed to send ${events.length} events, attempting to re-queue');

        var requeueFailCount = 0;
        for (final event in events) {
          if (_eventQueue.size >= _getMaxQueueSize()) {
            requeueFailCount++;
            debugPrint(
                '🔔 TRACK: Failed to re-queue event ${event.eventCustomerId} after send failure');
          } else {
            _eventQueue.addEvent(event);
            debugPrint(
                '🔔 TRACK: Successfully re-queued event ${event.eventCustomerId}');
          }
        }

        final resultMessage = requeueFailCount > 0
            ? 'Failed to send events and $requeueFailCount event(s) could not be requeued'
            : 'Failed to send events but all ${events.length} were requeued';

        debugPrint('🔔 TRACK: $resultMessage');

        // Record connection failure
        _connectionManager.recordConnectionFailure(errorMessage);

        return CFResult.error(resultMessage);
      }
    } catch (e) {
      debugPrint('🔔 TRACK HTTP: Error during flush: ${e.toString()}');
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
    debugPrint('🔔 TRACK: Connection status changed to $status');
    if (status == ConnectionStatus.connected && _autoFlushEnabled) {
      debugPrint('🔔 TRACK: Connection restored, attempting to flush events');
      _maybeFlushEvents();
    }
  }

  /// Set a callback to be notified when events are tracked.
  void setEventCallback(EventCallback? callback) {
    _eventCallback = callback;
    debugPrint(
        '🔔 TRACK: Event callback ${callback == null ? 'removed' : 'set'}');
  }

  /// Enable or disable automatic event flushing.
  void setAutoFlush(bool enabled) {
    _autoFlushEnabled = enabled;
    debugPrint('🔔 TRACK: Auto flush ${enabled ? 'enabled' : 'disabled'}');
    if (enabled) {
      _startFlushTimer();
    } else {
      _stopFlushTimer();
    }
  }

  /// Shutdown the event tracker and release resources.
  Future<void> shutdown() async {
    debugPrint('🔔 TRACK: Shutting down event tracker');
    _stopFlushTimer();
    _connectionManager.removeConnectionStatusListener(this);
    await flush();
  }

  /// Start the timer for flushing events periodically.
  void _startFlushTimer() {
    _stopFlushTimer();
    if (_autoFlushEnabled) {
      debugPrint(
          '🔔 TRACK: Starting flush timer with interval ${_config.eventsFlushIntervalMs}ms');
      _flushTimer = Timer.periodic(
        Duration(milliseconds: _config.eventsFlushIntervalMs),
        (_) {
          debugPrint('🔔 TRACK: Flush timer triggered');
          _maybeFlushEvents();
        },
      );
    }
  }

  /// Stop the flush timer.
  void _stopFlushTimer() {
    if (_flushTimer != null) {
      debugPrint('🔔 TRACK: Stopping flush timer');
      _flushTimer!.cancel();
      _flushTimer = null;
    }
  }

  /// Flush events if conditions are met.
  void _maybeFlushEvents() {
    if (_connectionManager.getConnectionStatus() ==
        ConnectionStatus.connected) {
      if (!_eventQueue.isEmpty) {
        debugPrint('🔔 TRACK: Conditions met for flushing events');
        flush();
      }
    } else {
      debugPrint('🔔 TRACK: Skipping flush: network not connected');
    }
  }

  /// Helper method to get the maximum queue size
  int _getMaxQueueSize() {
    // Get this from the EventQueue instance
    return 100; // Using the default value from the constructor
  }
}
