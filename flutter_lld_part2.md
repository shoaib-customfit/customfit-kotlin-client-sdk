# CustomFit Flutter SDK: Low-Level Design (LLD) - Part 2

## 2. Analytics Components

### 2.1 lib/src/analytics/event/event_data.dart

**Purpose**: Event data model for tracking user actions.

**Implementation Details**:
```dart
class EventData {
  final String eventCustomerId;
  final EventType eventType;
  final Map<String, dynamic> properties;
  final DateTime eventTimestamp;
  final String? sessionId;
  final String? insertId;

  // Private constructor - use create factory method instead
  const EventData._({
    required this.eventCustomerId,
    required this.eventType,
    required this.properties,
    required this.eventTimestamp,
    this.sessionId,
    this.insertId,
  });

  // Factory method with validation
  static EventData create({
    required String eventCustomerId,
    EventType eventType = EventType.track,
    Map<String, dynamic> properties = const {},
    DateTime? timestamp,
    String? sessionId,
    String? insertId,
  }) {
    // Validate and sanitize properties
    final validProperties = _validateProperties(properties);
    
    return EventData._(
      eventCustomerId: eventCustomerId,
      eventType: eventType,
      properties: validProperties,
      eventTimestamp: timestamp ?? DateTime.now(),
      sessionId: sessionId,
      insertId: insertId ?? Uuid().v4(),
    );
  }

  // Validates the properties map, removing invalid entries
  static Map<String, dynamic> _validateProperties(Map<String, dynamic> properties) {
    final validatedProps = properties.entries
        .where((entry) => entry.value != null)
        .fold<Map<String, dynamic>>({}, (map, entry) {
          map[entry.key] = entry.value;
          return map;
        });
    
    if (validatedProps.length != properties.length) {
      Logger.w("Removed ${properties.length - validatedProps.length} null property values from event");
    }
    
    // Log warning for very large property maps
    if (validatedProps.length > 50) {
      Logger.w("Large number of properties (${validatedProps.length}) for event. Consider reducing for better performance");
    }
    
    return validatedProps;
  }

  // Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'event_customer_id': eventCustomerId,
      'event_type': eventType.name,
      'properties': properties,
      'event_timestamp': eventTimestamp.toUtc().toIso8601String(),
      if (sessionId != null) 'session_id': sessionId,
      if (insertId != null) 'insert_id': insertId,
    };
  }

  // Factory method from JSON
  factory EventData.fromJson(Map<String, dynamic> json) {
    return EventData._(
      eventCustomerId: json['event_customer_id'] as String,
      eventType: EventType.values.firstWhere(
        (e) => e.name == json['event_type'],
        orElse: () => EventType.track,
      ),
      properties: (json['properties'] as Map<String, dynamic>?) ?? {},
      eventTimestamp: DateTime.parse(json['event_timestamp'] as String),
      sessionId: json['session_id'] as String?,
      insertId: json['insert_id'] as String?,
    );
  }

  @override
  String toString() => 'EventData(eventCustomerId: $eventCustomerId, eventType: $eventType, '
      'properties: $properties, eventTimestamp: $eventTimestamp, '
      'sessionId: $sessionId, insertId: $insertId)';
}
```

**Key Functions**:
- Store event data with validation
- Property sanitization
- JSON serialization support
- Factory methods for creating valid events

### 2.2 lib/src/analytics/event/event_type.dart

**Purpose**: Enumeration of event types.

**Implementation Details**:
```dart
enum EventType {
  track
}

// Extension methods for serialization
extension EventTypeExtension on EventType {
  String get name {
    switch (this) {
      case EventType.track:
        return 'TRACK';
    }
  }
}
```

**Key Functions**:
- Define event type enumeration
- Provide name mapping for serialization

### 2.3 lib/src/analytics/event/event_properties_builder.dart

**Purpose**: Builder pattern for event properties.

**Implementation Details**:
```dart
class EventPropertiesBuilder {
  final Map<String, dynamic> _properties = {};

  // Add string property
  EventPropertiesBuilder addString(String key, String value) {
    _properties[key] = value;
    return this;
  }

  // Add number property
  EventPropertiesBuilder addNumber(String key, num value) {
    _properties[key] = value;
    return this;
  }

  // Add boolean property
  EventPropertiesBuilder addBoolean(String key, bool value) {
    _properties[key] = value;
    return this;
  }

  // Add DateTime property
  EventPropertiesBuilder addDateTime(String key, DateTime value) {
    _properties[key] = value.toUtc().toIso8601String();
    return this;
  }

  // Add list property
  EventPropertiesBuilder addList(String key, List<dynamic> value) {
    _properties[key] = value;
    return this;
  }

  // Add map property
  EventPropertiesBuilder addMap(String key, Map<String, dynamic> value) {
    _properties[key] = value;
    return this;
  }

  // Generic add method
  EventPropertiesBuilder add(String key, dynamic value) {
    if (value == null) {
      return this;
    }
    _properties[key] = value;
    return this;
  }

  // Build the properties map
  Map<String, dynamic> build() {
    return Map<String, dynamic>.from(_properties);
  }
}
```

**Key Functions**:
- Fluent builder API for event properties
- Type-specific methods
- Immutable output

### 2.4 lib/src/analytics/event/event_tracker.dart

**Purpose**: Core implementation of event tracking and queueing.

**Implementation Details**:
```dart
class EventTracker {
  final String _sessionId;
  final HttpClient _httpClient;
  final CFUser _user;
  final SummaryManager _summaryManager;
  final CFConfig _config;
  
  // Queue for batching events
  final EventQueue _eventQueue;
  
  // Configuration parameters with atomic updates
  int get _eventsQueueSize => _config.eventsQueueSize;
  int _eventsFlushTimeSeconds;
  int _eventsFlushIntervalMs;
  
  // Timer management
  Timer? _flushTimer;
  final _timerMutex = Mutex();
  
  // Event serialization
  final _eventFormatter = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
  
  EventTracker(
    this._sessionId,
    this._httpClient,
    this._user,
    this._summaryManager,
    this._config,
  ) : 
    _eventQueue = EventQueue(_config.eventsQueueSize),
    _eventsFlushTimeSeconds = _config.eventsFlushTimeSeconds,
    _eventsFlushIntervalMs = _config.eventsFlushIntervalMs {
    Logger.i("EventTracker initialized with eventsQueueSize=$_eventsQueueSize, eventsFlushTimeSeconds=$_eventsFlushTimeSeconds, eventsFlushIntervalMs=$_eventsFlushIntervalMs");
    _startPeriodicFlush();
  }

  // Update flush interval
  Future<CFResult<int>> updateFlushInterval(int intervalMs) async {
    try {
      if (intervalMs <= 0) {
        throw ArgumentError("Interval must be greater than 0");
      }
      
      _eventsFlushIntervalMs = intervalMs;
      await _restartPeriodicFlush();
      Logger.i("Updated events flush interval to $intervalMs ms");
      return CFResult.success(intervalMs);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to update flush interval to $intervalMs",
        "EventTracker",
        ErrorSeverity.medium
      );
      return CFResult.error(
        "Failed to update flush interval", 
        exception: e, 
        category: ErrorCategory.validation
      );
    }
  }

  // Update flush time threshold
  Future<CFResult<int>> updateFlushTimeThreshold(int seconds) async {
    try {
      if (seconds <= 0) {
        throw ArgumentError("Threshold must be greater than 0");
      }
      
      _eventsFlushTimeSeconds = seconds;
      Logger.i("Updated events flush time threshold to $seconds seconds");
      return CFResult.success(seconds);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to update flush time threshold to $seconds",
        "EventTracker",
        ErrorSeverity.medium
      );
      return CFResult.error(
        "Failed to update flush time threshold", 
        exception: e, 
        category: ErrorCategory.validation
      );
    }
  }

  // Track event with validation
  Future<CFResult<EventData>> trackEvent(String eventName, Map<String, dynamic> properties) async {
    try {
      if (eventName.isEmpty) {
        const message = "Event name cannot be blank";
        ErrorHandler.handleError(
          message,
          "EventTracker",
          ErrorCategory.validation,
          ErrorSeverity.medium
        );
        return CFResult.error(message, category: ErrorCategory.validation);
      }

      // Create event using our factory method with validation
      final event = EventData.create(
        eventCustomerId: eventName,
        eventType: EventType.track,
        properties: properties,
        timestamp: DateTime.now(),
        sessionId: _sessionId,
      );

      // Handle queue management with proper error tracking
      if (_eventQueue.isFull) {
        ErrorHandler.handleError(
          "Event queue is full (size = $_eventsQueueSize), dropping oldest event",
          "EventTracker",
          ErrorCategory.internal,
          ErrorSeverity.medium
        );
        _eventQueue.removeOldest();
      }

      final added = _eventQueue.add(event);
      if (!added) {
        ErrorHandler.handleError(
          "Event queue full, forcing flush for event: $event",
          "EventTracker",
          ErrorCategory.internal,
          ErrorSeverity.medium
        );
        
        await flushEvents();
        
        final addedAfterFlush = _eventQueue.add(event);
        if (!addedAfterFlush) {
          const message = "Failed to queue event after flush";
          ErrorHandler.handleError(
            "$message: $event",
            "EventTracker",
            ErrorCategory.internal,
            ErrorSeverity.high
          );
          return CFResult.error(message, category: ErrorCategory.internal);
        }
      } else {
        Logger.d("Event added to queue: $event");
        if (_eventQueue.isFull) {
          flushEvents();
        }
      }
      
      return CFResult.success(event);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Unexpected error tracking event: $eventName",
        "EventTracker",
        ErrorSeverity.high
      );
      return CFResult.error(
        "Failed to track event", 
        exception: e, 
        category: ErrorCategory.internal
      );
    }
  }

  // Flush events to the server
  Future<CFResult<bool>> flushEvents() async {
    if (_eventQueue.isEmpty) {
      return CFResult.success(true);
    }

    Logger.d("Flushing ${_eventQueue.length} events");
    final events = _eventQueue.getAll();
    _eventQueue.clear();

    return _sendEvents(events);
  }

  // Send events to the server
  Future<CFResult<bool>> _sendEvents(List<EventData> events) async {
    if (events.isEmpty) {
      return CFResult.success(true);
    }

    // Create JSON payload
    final jsonPayload = _createEventsPayload(events);
    if (jsonPayload == null) {
      return CFResult.error(
        "Failed to create events payload",
        category: ErrorCategory.serialization
      );
    }

    // Send with retry
    return RetryUtil.withRetry(
      () => _httpClient.post(
        "${CFConstants.api.baseApiUrl}/v1/events",
        data: jsonPayload,
      ),
      maxAttempts: _config.maxRetryAttempts,
      initialDelayMs: _config.retryInitialDelayMs,
      maxDelayMs: _config.retryMaxDelayMs,
      backoffMultiplier: _config.retryBackoffMultiplier,
    );
  }

  // Create events payload
  Map<String, dynamic>? _createEventsPayload(List<EventData> events) {
    try {
      return {
        'events': events.map((e) => e.toJson()).toList(),
        'user': _user.toUserMap(),
        'cf_client_sdk_version': CFConstants.general.sdkVersion,
      };
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to serialize event payload",
        "EventTracker",
        ErrorSeverity.high
      );
      return null;
    }
  }

  // Start periodic flush timer
  Future<void> _startPeriodicFlush() async {
    await _timerMutex.synchronized(() {
      _flushTimer?.cancel();
      _flushTimer = Timer.periodic(
        Duration(milliseconds: _eventsFlushIntervalMs),
        (_) => flushEvents(),
      );
    });
  }

  // Restart periodic flush timer
  Future<void> _restartPeriodicFlush() async {
    await _startPeriodicFlush();
  }

  // Stop periodic flush timer
  Future<void> _stopPeriodicFlush() async {
    await _timerMutex.synchronized(() {
      _flushTimer?.cancel();
      _flushTimer = null;
    });
  }
}
```

**Key Functions**:
- Track events with validation
- Queue events for batching
- Periodic flushing to server
- JSON payload creation
- Retry logic for API failures

### 2.5 lib/src/analytics/event/event_queue.dart

**Purpose**: Queue for batching events.

**Implementation Details**:
```dart
class EventQueue {
  final int _capacity;
  final Queue<EventData> _queue = Queue<EventData>();
  final _queueMutex = Mutex();

  EventQueue(this._capacity) {
    if (_capacity <= 0) {
      throw ArgumentError("Queue capacity must be greater than 0");
    }
  }

  // Check if queue is empty
  bool get isEmpty => _queue.isEmpty;

  // Check if queue is full
  bool get isFull => _queue.length >= _capacity;

  // Get number of events in queue
  int get length => _queue.length;

  // Get remaining capacity
  int get remainingCapacity => _capacity - _queue.length;

  // Add event to queue
  bool add(EventData event) {
    if (isFull) {
      return false;
    }
    
    _queueMutex.synchronized(() {
      _queue.add(event);
    });
    
    return true;
  }

  // Remove oldest event
  EventData? removeOldest() {
    if (isEmpty) {
      return null;
    }
    
    return _queueMutex.synchronized(() {
      return _queue.removeFirst();
    });
  }

  // Get all events but keep them in queue
  List<EventData> peekAll() {
    return _queueMutex.synchronized(() {
      return List<EventData>.from(_queue);
    });
  }

  // Get all events and remove them from queue
  List<EventData> getAll() {
    return _queueMutex.synchronized(() {
      final events = List<EventData>.from(_queue);
      _queue.clear();
      return events;
    });
  }

  // Clear the queue
  void clear() {
    _queueMutex.synchronized(() {
      _queue.clear();
    });
  }
}
```

**Key Functions**:
- Thread-safe queue implementation
- Fixed capacity management
- Batch operations

### 2.6 lib/src/analytics/summary/summary_manager.dart

**Purpose**: Manages analytics summaries.

**Implementation Details**:
```dart
class SummaryManager {
  final String _sessionId;
  final HttpClient _httpClient;
  final CFUser _user;
  final CFConfig _config;
  
  // Queue for batching summaries
  final SummaryQueue _summaryQueue;
  
  // Configuration parameters with atomic updates
  int get _summariesQueueSize => _config.summariesQueueSize;
  int _summariesFlushTimeSeconds;
  int _summariesFlushIntervalMs;
  
  // Timer management
  Timer? _flushTimer;
  final _timerMutex = Mutex();
  
  SummaryManager(
    this._sessionId,
    this._httpClient,
    this._user,
    this._config,
  ) : 
    _summaryQueue = SummaryQueue(_config.summariesQueueSize),
    _summariesFlushTimeSeconds = _config.summariesFlushTimeSeconds,
    _summariesFlushIntervalMs = _config.summariesFlushIntervalMs {
    Logger.i("SummaryManager initialized with summariesQueueSize=$_summariesQueueSize, summariesFlushTimeSeconds=$_summariesFlushTimeSeconds, summariesFlushIntervalMs=$_summariesFlushIntervalMs");
    _startPeriodicFlush();
  }

  // Update flush interval
  Future<CFResult<int>> updateFlushInterval(int intervalMs) async {
    try {
      if (intervalMs <= 0) {
        throw ArgumentError("Interval must be greater than 0");
      }
      
      _summariesFlushIntervalMs = intervalMs;
      await _restartPeriodicFlush();
      Logger.i("Updated summaries flush interval to $intervalMs ms");
      return CFResult.success(intervalMs);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to update flush interval to $intervalMs",
        "SummaryManager",
        ErrorSeverity.medium
      );
      return CFResult.error(
        "Failed to update flush interval", 
        exception: e, 
        category: ErrorCategory.validation
      );
    }
  }

  // Track summary data
  Future<CFResult<SummaryData>> trackSummary(SummaryData summary) async {
    try {
      // Handle queue management with proper error tracking
      if (_summaryQueue.isFull) {
        ErrorHandler.handleError(
          "Summary queue is full (size = $_summariesQueueSize), dropping oldest summary",
          "SummaryManager",
          ErrorCategory.internal,
          ErrorSeverity.medium
        );
        _summaryQueue.removeOldest();
      }

      final added = _summaryQueue.add(summary);
      if (!added) {
        ErrorHandler.handleError(
          "Summary queue full, forcing flush for summary: $summary",
          "SummaryManager",
          ErrorCategory.internal,
          ErrorSeverity.medium
        );
        
        await flushSummaries();
        
        final addedAfterFlush = _summaryQueue.add(summary);
        if (!addedAfterFlush) {
          const message = "Failed to queue summary after flush";
          ErrorHandler.handleError(
            "$message: $summary",
            "SummaryManager",
            ErrorCategory.internal,
            ErrorSeverity.high
          );
          return CFResult.error(message, category: ErrorCategory.internal);
        }
      } else {
        Logger.d("Summary added to queue: $summary");
        if (_summaryQueue.isFull) {
          flushSummaries();
        }
      }
      
      return CFResult.success(summary);
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Unexpected error tracking summary",
        "SummaryManager",
        ErrorSeverity.high
      );
      return CFResult.error(
        "Failed to track summary", 
        exception: e, 
        category: ErrorCategory.internal
      );
    }
  }

  // Flush summaries to the server
  Future<CFResult<bool>> flushSummaries() async {
    if (_summaryQueue.isEmpty) {
      return CFResult.success(true);
    }

    Logger.d("Flushing ${_summaryQueue.length} summaries");
    final summaries = _summaryQueue.getAll();
    _summaryQueue.clear();

    return _sendSummaries(summaries);
  }

  // Send summaries to the server
  Future<CFResult<bool>> _sendSummaries(List<SummaryData> summaries) async {
    if (summaries.isEmpty) {
      return CFResult.success(true);
    }

    // Create JSON payload
    final jsonPayload = _createSummariesPayload(summaries);
    if (jsonPayload == null) {
      return CFResult.error(
        "Failed to create summaries payload",
        category: ErrorCategory.serialization
      );
    }

    // Send with retry
    return RetryUtil.withRetry(
      () => _httpClient.post(
        "${CFConstants.api.baseApiUrl}/v1/summaries",
        data: jsonPayload,
      ),
      maxAttempts: _config.maxRetryAttempts,
      initialDelayMs: _config.retryInitialDelayMs,
      maxDelayMs: _config.retryMaxDelayMs,
      backoffMultiplier: _config.retryBackoffMultiplier,
    );
  }

  // Create summaries payload
  Map<String, dynamic>? _createSummariesPayload(List<SummaryData> summaries) {
    try {
      return {
        'summaries': summaries.map((s) => s.toJson()).toList(),
        'user': _user.toUserMap(),
        'cf_client_sdk_version': CFConstants.general.sdkVersion,
        'session_id': _sessionId,
      };
    } catch (e) {
      ErrorHandler.handleException(
        e,
        "Failed to serialize summaries payload",
        "SummaryManager",
        ErrorSeverity.high
      );
      return null;
    }
  }

  // Start periodic flush timer
  Future<void> _startPeriodicFlush() async {
    await _timerMutex.synchronized(() {
      _flushTimer?.cancel();
      _flushTimer = Timer.periodic(
        Duration(milliseconds: _summariesFlushIntervalMs),
        (_) => flushSummaries(),
      );
    });
  }

  // Restart periodic flush timer
  Future<void> _restartPeriodicFlush() async {
    await _startPeriodicFlush();
  }

  // Stop periodic flush timer
  Future<void> _stopPeriodicFlush() async {
    await _timerMutex.synchronized(() {
      _flushTimer?.cancel();
      _flushTimer = null;
    });
  }
}
```

**Key Functions**:
- Track summary data
- Queue summaries for batching
- Periodic flushing to server
- JSON payload creation
- Retry logic for API failures

### 2.7 lib/src/analytics/summary/summary_data.dart

**Purpose**: Summary data model.

**Implementation Details**:
```dart
class SummaryData {
  final String summaryType;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? insertId;

  // Private constructor - use create factory method instead
  const SummaryData._({
    required this.summaryType,
    required this.data,
    required this.timestamp,
    this.insertId,
  });

  // Factory method with validation
  static SummaryData create({
    required String summaryType,
    required Map<String, dynamic> data,
    DateTime? timestamp,
    String? insertId,
  }) {
    if (summaryType.isEmpty) {
      throw ArgumentError("Summary type cannot be empty");
    }
    
    // Validate and sanitize data
    final validData = _validateData(data);
    
    return SummaryData._(
      summaryType: summaryType,
      data: validData,
      timestamp: timestamp ?? DateTime.now(),
      insertId: insertId ?? Uuid().v4(),
    );
  }

  // Validates the data map, removing invalid entries
  static Map<String, dynamic> _validateData(Map<String, dynamic> data) {
    final validatedData = data.entries
        .where((entry) => entry.value != null)
        .fold<Map<String, dynamic>>({}, (map, entry) {
          map[entry.key] = entry.value;
          return map;
        });
    
    if (validatedData.length != data.length) {
      Logger.w("Removed ${data.length - validatedData.length} null data values from summary");
    }
    
    return validatedData;
  }

  // Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'summary_type': summaryType,
      'data': data,
      'timestamp': timestamp.toUtc().toIso8601String(),
      if (insertId != null) 'insert_id': insertId,
    };
  }

  // Factory method from JSON
  factory SummaryData.fromJson(Map<String, dynamic> json) {
    return SummaryData._(
      summaryType: json['summary_type'] as String,
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
      insertId: json['insert_id'] as String?,
    );
  }

  @override
  String toString() => 'SummaryData(summaryType: $summaryType, data: $data, '
      'timestamp: $timestamp, insertId: $insertId)';
}
```

**Key Functions**:
- Store summary data with validation
- Data sanitization
- JSON serialization support
- Factory methods for creating valid summaries 