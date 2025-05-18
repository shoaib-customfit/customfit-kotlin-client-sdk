package customfit.ai.kotlinclient.analytics.event

import customfit.ai.kotlinclient.analytics.summary.SummaryManager
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.error.CFResult
import customfit.ai.kotlinclient.core.error.ErrorHandler
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.core.util.RetryUtil.withRetry
import customfit.ai.kotlinclient.network.HttpClient
import customfit.ai.kotlinclient.platform.AppState
import customfit.ai.kotlinclient.platform.AppStateListener
import customfit.ai.kotlinclient.platform.BatteryState
import customfit.ai.kotlinclient.platform.BatteryStateListener
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Timer
import java.util.UUID
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.fixedRateTimer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import customfit.ai.kotlinclient.logging.Timber

class EventTracker(
        private val sessionId: String,
        private val httpClient: HttpClient,
        private val user: CFUser,
        private val summaryManager: SummaryManager,
        private val cfConfig: CFConfig
) {
    companion object {
        private const val SOURCE = "EventTracker"
    }
    
    // Use atomics to allow thread-safe updates
    private val eventsQueueSize = cfConfig.eventsQueueSize
    private val eventsFlushTimeSeconds = AtomicInteger(cfConfig.eventsFlushTimeSeconds)
    private val eventsFlushIntervalMs = AtomicLong(cfConfig.eventsFlushIntervalMs)
    
    // Store the max events limit from config for storage enforcement
    private val maxStoredEvents = cfConfig.maxStoredEvents

    private val eventQueue: LinkedBlockingQueue<EventData> = LinkedBlockingQueue(eventsQueueSize)
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    // Timer management
    private var flushTimer: Timer? = null
    private val timerMutex = Mutex()
    
    // Track stored events metrics
    private val totalEventsTracked = AtomicInteger(0)
    private val totalEventsDropped = AtomicInteger(0)
    private val persistedEventsMutex = Mutex()
    
    // Storage for persisted events
    private val eventStorageManager = EventStorageManager(cfConfig, scope)

    init {
        Timber.i("EventTracker initialized with eventsQueueSize=$eventsQueueSize, maxStoredEvents=$maxStoredEvents, eventsFlushTimeSeconds=${eventsFlushTimeSeconds.get()}, eventsFlushIntervalMs=${eventsFlushIntervalMs.get()}")
        
        // Load persisted events on initialization
        scope.launch {
            loadPersistedEvents()
            startPeriodicFlush()
        }
    }
    
    /**
     * Load persisted events from storage while respecting queue size limits
     */
    private suspend fun loadPersistedEvents() {
        try {
            Timber.i("Loading persisted events from storage...")
            val events = eventStorageManager.loadEvents()
            
            // Check if we need to enforce the maxStoredEvents limit
            val eventsToLoad = if (events.size > maxStoredEvents) {
                Timber.w("Loaded ${events.size} events, but maxStoredEvents is $maxStoredEvents. Truncating.")
                events.takeLast(maxStoredEvents)
            } else {
                events
            }
            
            if (eventsToLoad.isEmpty()) {
                Timber.i("No persisted events found")
                return
            }
            
            var addedCount = 0
            var droppedCount = 0
            
            // Add events to the queue, respecting queue size limits
            for (event in eventsToLoad) {
                if (eventQueue.size < eventsQueueSize) {
                    if (eventQueue.offer(event)) {
                        addedCount++
                        totalEventsTracked.incrementAndGet()
                    }
                } else {
                    droppedCount++
                    totalEventsDropped.incrementAndGet()
                }
            }
            
            if (addedCount > 0) {
                Timber.i("Loaded $addedCount persisted events from storage")
            }
            
            if (droppedCount > 0) {
                Timber.w("Dropped $droppedCount persisted events due to queue size limit")
                ErrorHandler.handleError(
                    "Dropped $droppedCount persisted events due to queue size limit",
                    SOURCE,
                    ErrorHandler.ErrorCategory.INTERNAL,
                    ErrorHandler.ErrorSeverity.MEDIUM
                )
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to load persisted events: ${e.message}")
            ErrorHandler.handleException(
                e,
                "Failed to load persisted events",
                SOURCE,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
        }
    }
    
    /**
     * Persist current events to storage for later retrieval
     */
    suspend fun persistEvents(): CFResult<Int> {
        try {
            persistedEventsMutex.withLock {
                // Get a snapshot of all events in the queue
                val events = eventQueue.toList()
                
                // Enforce maxStoredEvents limit
                val eventsToStore = if (events.size > maxStoredEvents) {
                    Timber.w("Attempting to store ${events.size} events, but maxStoredEvents is $maxStoredEvents. Truncating.")
                    events.takeLast(maxStoredEvents)
                } else {
                    events
                }
                
                if (eventsToStore.isEmpty()) {
                    Timber.d("No events to persist")
                    return CFResult.success(0)
                }
                
                Timber.i("Persisting ${eventsToStore.size} events to storage")
                eventStorageManager.storeEvents(eventsToStore)
                
                return CFResult.success(eventsToStore.size)
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to persist events: ${e.message}")
            ErrorHandler.handleException(
                e,
                "Failed to persist events",
                SOURCE,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            return CFResult.error(
                "Failed to persist events",
                e,
                category = ErrorHandler.ErrorCategory.INTERNAL
            )
        }
    }

    /**
     * Updates the flush interval and restarts the timer
     *
     * @param intervalMs new interval in milliseconds
     */
    suspend fun updateFlushInterval(intervalMs: Long): CFResult<Long> {
        try {
            require(intervalMs > 0) { "Interval must be greater than 0" }

            eventsFlushIntervalMs.set(intervalMs)
            restartPeriodicFlush()
            Timber.i("Updated events flush interval to $intervalMs ms")
            return CFResult.success(intervalMs)
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Failed to update flush interval to $intervalMs",
                SOURCE,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            return CFResult.error("Failed to update flush interval", e, category = ErrorHandler.ErrorCategory.VALIDATION)
        }
    }

    /**
     * Updates the flush time threshold
     *
     * @param seconds new threshold in seconds
     */
    fun updateFlushTimeSeconds(seconds: Int): CFResult<Int> {
        try {
            require(seconds > 0) { "Seconds must be greater than 0" }

            eventsFlushTimeSeconds.set(seconds)
            Timber.i("Updated events flush time threshold to $seconds seconds")
            return CFResult.success(seconds)
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Failed to update flush time seconds to $seconds",
                SOURCE,
                ErrorHandler.ErrorSeverity.MEDIUM
            )
            return CFResult.error("Failed to update flush time seconds", e, category = ErrorHandler.ErrorCategory.VALIDATION)
        }
    }

    /**
     * Tracks an event with improved error handling and storage limit enforcement
     * Always flushes summaries before tracking a new event
     */
    fun trackEvent(eventName: String, properties: Map<String, Any> = emptyMap()): CFResult<EventData> {
        try {
            // Using Timber for consistent logging
            Timber.i("🔔 🔔 TRACK: Tracking event: $eventName with properties: $properties")
            
            // Always flush summaries first before tracking a new event
            scope.launch {
                Timber.i("🔔 🔔 TRACK: Flushing summaries before tracking event: $eventName")
                summaryManager.flushSummaries()
                    .onError { error ->
                        Timber.w("🔔 🔔 TRACK: Failed to flush summaries before tracking event: ${error.error}")
                    }
            }
            
            if (eventName.isBlank()) {
                val message = "Event name cannot be blank"
                Timber.w("🔔 TRACK: Invalid event - $message")
                ErrorHandler.handleError(
                    message,
                    SOURCE,
                    ErrorHandler.ErrorCategory.VALIDATION,
                    ErrorHandler.ErrorSeverity.MEDIUM
                )
                return CFResult.error(message, category = ErrorHandler.ErrorCategory.VALIDATION)
            }

            // Create event using our factory method with validation
            val event = EventData.create(
                eventCustomerId = eventName,
                eventType = EventType.TRACK,
                properties = properties,
                timestamp = Instant.now(),
                sessionId = sessionId,
                insertId = UUID.randomUUID().toString()
            )

            // Handle queue management with proper error and storage limit tracking
            if (eventQueue.size >= eventsQueueSize) {
                Timber.w("🔔 TRACK: Event queue is full (size = $eventsQueueSize), dropping oldest event")
                ErrorHandler.handleError(
                    "Event queue is full (size = $eventsQueueSize), dropping oldest event",
                    SOURCE,
                    ErrorHandler.ErrorCategory.INTERNAL,
                    ErrorHandler.ErrorSeverity.MEDIUM
                )
                eventQueue.poll() // Remove the oldest event
                totalEventsDropped.incrementAndGet()
            }

            if (!eventQueue.offer(event)) {
                Timber.w("🔔 TRACK: Event queue full, forcing flush for event: ${event.event_customer_id}")
                ErrorHandler.handleError(
                    "Event queue full, forcing flush for event: $event",
                    SOURCE,
                    ErrorHandler.ErrorCategory.INTERNAL,
                    ErrorHandler.ErrorSeverity.MEDIUM
                )
                scope.launch { flushEvents() }
                
                if (!eventQueue.offer(event)) {
                    val message = "Failed to queue event after flush"
                    Timber.e("🔔 TRACK: $message: ${event.event_customer_id}")
                    ErrorHandler.handleError(
                        "$message: $event",
                        SOURCE,
                        ErrorHandler.ErrorCategory.INTERNAL,
                        ErrorHandler.ErrorSeverity.HIGH
                    )
                    totalEventsDropped.incrementAndGet()
                    return CFResult.error(message, category = ErrorHandler.ErrorCategory.INTERNAL)
                }
            } else {
                Timber.i("🔔 TRACK: Event added to queue: ${event.event_customer_id}, queue size=${eventQueue.size}")
                totalEventsTracked.incrementAndGet()
                
                // If approaching capacity, persist to storage as backup
                if (eventQueue.size > eventsQueueSize * 0.7) {
                    scope.launch { 
                        persistEvents() 
                    }
                }
                
                if (eventQueue.size >= eventsQueueSize) {
                    Timber.i("🔔 TRACK: Queue size threshold reached (${eventQueue.size}/${eventsQueueSize}), triggering flush")
                    scope.launch { flushEvents() }
                }
            }
            
            return CFResult.success(event)
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Unexpected error tracking event: $eventName",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            return CFResult.error("Failed to track event", e, category = ErrorHandler.ErrorCategory.INTERNAL)
        }
    }

    private fun startPeriodicFlush() {
        scope.launch {
            try {
                timerMutex.withLock {
                    flushTimer?.cancel()
                    flushTimer = fixedRateTimer(
                        "EventFlushCheck",
                        daemon = true,
                        period = eventsFlushIntervalMs.get()
                    ) {
                        scope.launch {
                            try {
                                val lastEvent = eventQueue.peek()
                                val currentTime = Instant.now()
                                if (lastEvent != null &&
                                    currentTime.minusSeconds(eventsFlushTimeSeconds.get().toLong())
                                        .isAfter(lastEvent.event_timestamp)
                                ) {
                                    flushEvents()
                                }
                            } catch (e: Exception) {
                                ErrorHandler.handleException(
                                    e,
                                    "Error in periodic flush timer",
                                    SOURCE,
                                    ErrorHandler.ErrorSeverity.MEDIUM
                                )
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                ErrorHandler.handleException(
                    e,
                    "Failed to start periodic flush timer",
                    SOURCE,
                    ErrorHandler.ErrorSeverity.HIGH
                )
            }
        }
    }

    private suspend fun restartPeriodicFlush() {
        try {
            timerMutex.withLock {
                flushTimer?.cancel()
                flushTimer = fixedRateTimer(
                    "EventFlushCheck",
                    daemon = true,
                    period = eventsFlushIntervalMs.get()
                ) {
                    scope.launch {
                        try {
                            val lastEvent = eventQueue.peek()
                            val currentTime = Instant.now()
                            if (lastEvent != null &&
                                currentTime.minusSeconds(eventsFlushTimeSeconds.get().toLong())
                                    .isAfter(lastEvent.event_timestamp)
                            ) {
                                flushEvents()
                            }
                        } catch (e: Exception) {
                            ErrorHandler.handleException(
                                e,
                                "Error in restarted periodic flush timer",
                                SOURCE,
                                ErrorHandler.ErrorSeverity.MEDIUM
                            )
                        }
                    }
                }
                Timber.d("Restarted periodic event flush check with interval ${eventsFlushIntervalMs.get()} ms")
            }
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Failed to restart periodic flush timer",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
        }
    }

    /**
     * Flushes events to the server with improved error handling
     * Note: Summaries are already flushed in trackEvent, but we ensure they're flushed here as well
     */
    suspend fun flushEvents(): CFResult<Int> {
        try {
            // Always ensure summaries are flushed first
            Timber.i("🔔 🔔 TRACK: Beginning event flush process")
            summaryManager.flushSummaries()
                .onError { error ->
                    Timber.w("🔔 🔔 TRACK: Failed to flush summaries before flushing events: ${error.error}")
                    ErrorHandler.handleError(
                        "Failed to flush summaries before flushing events: ${error.error}",
                        SOURCE,
                        error.category,
                        ErrorHandler.ErrorSeverity.MEDIUM
                    )
                }
            
            // Check if queue is empty
            if (eventQueue.isEmpty()) {
                Timber.d("🔔 TRACK: No events to flush")
                return CFResult.success(0)
            }
            
            // Drain the queue
            val eventsToFlush = mutableListOf<EventData>()
            eventQueue.drainTo(eventsToFlush)
            
            if (eventsToFlush.isNotEmpty()) {
                Timber.i("🔔 TRACK: Flushing ${eventsToFlush.size} events to server")
                
                eventsToFlush.forEachIndexed { index, event ->
                    Timber.d("🔔 TRACK: Event #${index+1}: ${event.event_customer_id}")
                }
                
                val result = sendTrackEvents(eventsToFlush)
                
                if (result is CFResult.Success) {
                    Timber.i("🔔 TRACK: Flushed ${eventsToFlush.size} events successfully")
                    
                    // Clear persisted events on successful flush - in a coroutine to avoid suspension issues
                    scope.launch {
                        try {
                            eventStorageManager.clearEvents()
                            Timber.d("🔔 TRACK: Cleared persisted events after successful flush")
                        } catch (e: Exception) {
                            Timber.e(e, "Failed to clear persisted events: ${e.message}")
                        }
                    }
                    
                    return CFResult.success(eventsToFlush.size)
                } else if (result is CFResult.Error) {
                    Timber.w("🔔 TRACK: Failed to flush events: ${result.error}")
                    
                    // Persist undelivered events for retry later - in a coroutine to avoid suspension issues
                    scope.launch {
                        try {
                            Timber.i("🔔 TRACK: Persisting ${eventsToFlush.size} undelivered events for retry later")
                            persistedEventsMutex.withLock {
                                eventStorageManager.storeEvents(eventsToFlush)
                            }
                        } catch (e: Exception) {
                            Timber.e(e, "Failed to persist undelivered events: ${e.message}")
                        }
                    }
                    
                    return CFResult.error(
                        "Failed to flush events: ${result.error}",
                        result.exception,
                        result.code,
                        result.category
                    )
                } else {
                    Timber.d("🔔 TRACK: No events to flush after drain")
                    return CFResult.success(0)
                }
            } else {
                Timber.d("🔔 TRACK: No events to flush after drain")
                return CFResult.success(0)
            }
        } catch (e: Exception) {
            ErrorHandler.handleException(
                e,
                "Unexpected error flushing events",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            return CFResult.error("Failed to flush events", e, category = ErrorHandler.ErrorCategory.INTERNAL)
        }
    }
    
    /**
     * Get metrics about event tracking
     */
    fun getEventMetrics(): EventMetrics {
        return EventMetrics(
            queueSize = eventQueue.size,
            totalTracked = totalEventsTracked.get(),
            totalDropped = totalEventsDropped.get(),
            queueLimit = eventsQueueSize,
            storageLimit = maxStoredEvents
        )
    }
    
    /**
     * Clear all events from the queue and storage
     */
    suspend fun clearAllEvents(): CFResult<Boolean> {
        try {
            eventQueue.clear()
            eventStorageManager.clearEvents()
            Timber.i("Cleared all events from queue and storage")
            return CFResult.success(true)
        } catch (e: Exception) {
            Timber.e(e, "Failed to clear events: ${e.message}")
            return CFResult.error("Failed to clear events", e, category = ErrorHandler.ErrorCategory.INTERNAL)
        }
    }
    
    /**
     * Shutdown the event tracker, persisting events first
     */
    suspend fun shutdown() {
        try {
            Timber.i("Shutting down EventTracker, persisting ${eventQueue.size} events")
            flushTimer?.cancel()
            flushTimer = null
            
            // Try to flush first
            val flushResult = flushEvents()
            if (flushResult is CFResult.Error) {
                // If flush fails, persist the events
                persistEvents()
            }
        } catch (e: Exception) {
            Timber.e(e, "Error during EventTracker shutdown: ${e.message}")
            try {
                // Last attempt to persist events
                persistEvents()
            } catch (innerE: Exception) {
                Timber.e(innerE, "Failed to persist events during shutdown: ${innerE.message}")
            }
        }
    }

    // Define formatter for the specific timestamp format needed by the server
    private val eventTimestampFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSSX").withZone(ZoneOffset.UTC)

    /**
     * Sends tracked events to the server with improved error handling
     */
    private suspend fun sendTrackEvents(events: List<EventData>): CFResult<Boolean> {
        Timber.i("🔔 TRACK HTTP: Preparing to send ${events.size} events")
        
        // Log detailed event information before HTTP call
        events.forEachIndexed { index, event ->
            Timber.d("🔔 TRACK HTTP: Event #${index+1}: ${event.event_customer_id}, properties=${event.properties.keys.joinToString()}")
        }
        
        // First create the JSON payload
        val jsonPayload = try {
            val jsonObject = buildJsonObject {
                put("events", buildJsonArray {
                    events.forEach { event ->
                        add(buildJsonObject {
                            put("event_customer_id", JsonPrimitive(event.event_customer_id))
                            put("event_type", JsonPrimitive(event.event_type.name))
                            put("properties", buildJsonObject {
                                event.properties.forEach { (k, v) ->
                                    put(k, anyToJsonElement(v))
                                }
                            })
                            put("event_timestamp", JsonPrimitive(eventTimestampFormatter.format(event.event_timestamp)))
                            put("session_id", JsonPrimitive(event.session_id))
                            put("insert_id", JsonPrimitive(event.insert_id))
                        })
                    }
                })
                put("user", buildJsonObject {
                    user.toUserMap().forEach { (k, v) ->
                        put(k, anyToJsonElement(v))
                    }
                })
                put("cf_client_sdk_version", JsonPrimitive("1.1.1"))
            }
            Json.encodeToString(jsonObject)
        } catch (e: Exception) {
            Timber.e("🔔 TRACK HTTP: Error creating event payload for ${events.size} events")
            ErrorHandler.handleException(
                e,
                "Failed to serialize event payload",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            return CFResult.error(
                "Failed to serialize event payload",
                e,
                category = ErrorHandler.ErrorCategory.SERIALIZATION
            )
        }
        
        Timber.i("🔔 TRACK HTTP: Event payload size: ${jsonPayload.length} bytes")

        // Then send the events with retry
        val url = "https://api.customfit.ai/v1/cfe?cfenc=${cfConfig.clientKey}"
        Timber.i("🔔 TRACK HTTP: POST request to: $url")
        
        try {
            return withRetry(
                maxAttempts = cfConfig.maxRetryAttempts,
                initialDelayMs = cfConfig.retryInitialDelayMs,
                maxDelayMs = cfConfig.retryMaxDelayMs,
                backoffMultiplier = cfConfig.retryBackoffMultiplier
            ) {
                Timber.d("🔔 TRACK HTTP: Attempting to send events")
                val result = httpClient.postJson(url, jsonPayload)
                
                result.fold(
                    onSuccess = { 
                        Timber.i("🔔 TRACK HTTP: Events successfully sent to server")
                        CFResult.success(true) 
                    },
                    onError = { error ->
                        Timber.w("🔔 TRACK HTTP: Server returned error: ${error.error}")
                        throw Exception("Failed to send event: ${error.error}", error.exception)
                    }
                )
            }
        } catch (e: Exception) {
            Timber.e("🔔 TRACK HTTP: Failed to send events after ${cfConfig.maxRetryAttempts} attempts: ${e.message}")
            ErrorHandler.handleException(
                e,
                "Failed to send events after retries",
                SOURCE,
                ErrorHandler.ErrorSeverity.HIGH
            )
            
            // Re-queue the events if sending failed after all retries
            Timber.w("🔔 TRACK HTTP: Failed to send ${events.size} events, attempting to re-queue")
            
            var requeueFailed = false
            var requeueFailCount = 0
            
            events.forEach { event ->
                if (!eventQueue.offer(event)) {
                    requeueFailed = true
                    requeueFailCount++
                    Timber.e("🔔 TRACK: Failed to re-queue event ${event.event_customer_id} after send failure")
                    ErrorHandler.handleError(
                        "Failed to re-queue event after send failure: $event",
                        SOURCE,
                        ErrorHandler.ErrorCategory.INTERNAL,
                        ErrorHandler.ErrorSeverity.HIGH
                    )
                } else {
                    Timber.i("🔔 TRACK: Successfully re-queued event ${event.event_customer_id}")
                }
            }
            
            val errorMessage = if (requeueFailed) {
                "Failed to send events and $requeueFailCount event(s) could not be requeued" 
            } else {
                "Failed to send events but all ${events.size} were requeued"
            }
            
            Timber.w("🔔 TRACK: $errorMessage")
            
            return CFResult.error(
                errorMessage,
                e,
                category = ErrorHandler.ErrorCategory.NETWORK
            )
        }
    }

    /**
     * Converts any value to a JsonElement
     */
    private fun anyToJsonElement(value: Any?): JsonElement = when (value) {
        null -> JsonNull
        is String -> JsonPrimitive(value)
        is Number -> JsonPrimitive(value)
        is Boolean -> JsonPrimitive(value)
        is Map<*, *> -> buildJsonObject {
            value.forEach { (k, v) ->
                if (k is String) {
                    put(k, anyToJsonElement(v))
                }
            }
        }
        is List<*> -> buildJsonArray {
            value.forEach { item ->
                add(anyToJsonElement(item))
            }
        }
        else -> JsonPrimitive(value.toString())
    }
}

/**
 * Data class for event manager metrics
 */
data class EventMetrics(
    val queueSize: Int,
    val totalTracked: Int,
    val totalDropped: Int,
    val queueLimit: Int,
    val storageLimit: Int
)

/**
 * Manages persistent storage of events
 */
private class EventStorageManager(
    private val config: CFConfig,
    private val scope: CoroutineScope
) {
    private val prefsKey = "cf_stored_events"
    private val storageSerializer = Json { 
        ignoreUnknownKeys = true 
        isLenient = true
    }
    
    /**
     * Store events to persistent storage
     * 
     * @param events List of events to store
     * @return True if successful
     */
    suspend fun storeEvents(events: List<EventData>): Boolean {
        try {
            // In a real implementation, we would use platform-specific storage
            // This is a stub implementation that logs the action
            Timber.i("Would store ${events.size} events to persistent storage (stub)")
            Timber.d("STUB: Storage would enforce a limit of ${config.maxStoredEvents} events")
            return true
        } catch (e: Exception) {
            Timber.e(e, "Error storing events: ${e.message}")
            return false
        }
    }
    
    /**
     * Load events from persistent storage
     * 
     * @return List of loaded events
     */
    suspend fun loadEvents(): List<EventData> {
        try {
            // In a real implementation, we would use platform-specific storage
            // This is a stub implementation that logs the action
            Timber.i("Would load events from persistent storage (stub)")
            return emptyList()
        } catch (e: Exception) {
            Timber.e(e, "Error loading events: ${e.message}")
            return emptyList()
        }
    }
    
    /**
     * Clear all stored events
     * 
     * @return True if successful
     */
    suspend fun clearEvents(): Boolean {
        try {
            // In a real implementation, we would use platform-specific storage
            // This is a stub implementation that logs the action
            Timber.i("Would clear all stored events from persistent storage (stub)")
            return true
        } catch (e: Exception) {
            Timber.e(e, "Error clearing events: ${e.message}")
            return false
        }
    }
}

