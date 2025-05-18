// import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import 'event_data.dart';

/// Queue for storing events before they are sent.
class EventQueue {
  /// Internal queue for events.
  final Queue<EventData> _queue = Queue<EventData>();

  /// Maximum number of events that can be stored in the queue.
  final int _maxQueueSize;

  /// Callback to be notified when events are dropped.
  final Function(List<EventData>)? _onEventsDropped;

  /// Create a new event queue with the given maximum size.
  EventQueue({
    int maxQueueSize = 100,
    Function(List<EventData>)? onEventsDropped,
  })  : _maxQueueSize = maxQueueSize,
        _onEventsDropped = onEventsDropped;

  /// Add an event to the queue.
  ///
  /// If the queue is full, events will be dropped according to the configured policy.
  void addEvent(EventData event) {
    _queue.add(event);
    _ensureQueueSizeLimit();
  }

  /// Add multiple events to the queue.
  ///
  /// If the queue is full, events will be dropped according to the configured policy.
  void addEvents(List<EventData> events) {
    _queue.addAll(events);
    _ensureQueueSizeLimit();
  }

  /// Get all events in the queue and clear it.
  List<EventData> popAllEvents() {
    final events = List<EventData>.from(_queue);
    _queue.clear();
    return events;
  }

  /// Get a batch of events up to the specified size.
  List<EventData> popEventBatch(int batchSize) {
    final batchEvents = <EventData>[];
    final count = _queue.length < batchSize ? _queue.length : batchSize;

    for (int i = 0; i < count; i++) {
      batchEvents.add(_queue.removeFirst());
    }

    return batchEvents;
  }

  /// Get the current size of the queue.
  int get size => _queue.length;

  /// Check if the queue is empty.
  bool get isEmpty => _queue.isEmpty;

  /// Clear the queue.
  void clear() {
    _queue.clear();
  }

  /// Ensure the queue size doesn't exceed the limit.
  ///
  /// If the queue is too large, the oldest events will be dropped.
  void _ensureQueueSizeLimit() {
    if (_queue.length > _maxQueueSize) {
      final droppedEvents = <EventData>[];

      while (_queue.length > _maxQueueSize) {
        droppedEvents.add(_queue.removeFirst());
      }

      if (droppedEvents.isNotEmpty && _onEventsDropped != null) {
        try {
          _onEventsDropped(droppedEvents);
        } catch (e) {
          debugPrint('Error notifying about dropped events: $e');
        }
      }
    }
  }
}
