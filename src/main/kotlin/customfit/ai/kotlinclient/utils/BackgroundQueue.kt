package customfit.ai.kotlinclient.utils

import customfit.ai.kotlinclient.logging.Timber
import java.util.concurrent.Callable
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.cancel
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json

/**
 * Thread-safe background processing queue with persistence.
 *
 * Features:
 * - Persistent queue that survives app restarts
 * - Priority-based processing
 * - Automatic retry on failure
 * - Operation deduplication by key
 */
class BackgroundQueue<T>(
    private val queueName: String,
    private val queueFile: java.io.File? = null,
    private val processor: (T) -> Boolean,
    private val maxRetries: Int = 3,
    private val initialDelay: Long = 1000,
    private val maxDelay: Long = 30000,
    private val backoffMultiplier: Double = 2.0,
    private val serializeOperation: ((T) -> String)? = null,
    private val deserializeOperation: ((String) -> T)? = null
) {
    companion object {
        private const val TAG = "BackgroundQueue"
    }

    private val queueLock = java.util.concurrent.locks.ReentrantLock()
    private val pendingOperations = mutableListOf<QueueOperation<T>>()
    private val isProcessing = AtomicBoolean(false)
    private var isPaused = false
    private val processingScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val idCounter = AtomicInteger(0)
    
    // Extension function to use the lock more cleanly
    private inline fun <T> java.util.concurrent.locks.ReentrantLock.withLock(action: () -> T): T {
        this.lock()
        try {
            return action()
        } finally {
            this.unlock()
        }
    }

    // Initialize with persisted queue
    init {
        queueLock.withLock {
            if (queueFile != null && queueFile.exists() && serializeOperation != null && deserializeOperation != null) {
                loadPersistedQueue()
            }
            
            Timber.i("Background queue $queueName initialized with ${pendingOperations.size} operations")
        }
    }

    /**
     * Load previously persisted operations from storage
     */
    private fun loadPersistedQueue() {
        try {
            if (queueFile != null && queueFile.exists() && serializeOperation != null && deserializeOperation != null) {
                val jsonString = queueFile.readText()
                
                if (jsonString.isNotEmpty()) {
                    val serializableList = Json.decodeFromString<List<SerializableOperation>>(jsonString)
                    
                    pendingOperations.clear()
                    
                    serializableList.forEach { serOp ->
                        try {
                            val operation = deserializeOperation.invoke(serOp.serializedOperation)
                            pendingOperations.add(
                                QueueOperation(
                                    id = serOp.id,
                                    operation = operation,
                                    uniqueKey = serOp.uniqueKey,
                                    priority = serOp.priority,
                                    retryCount = serOp.retryCount,
                                    initialBackoffMs = serOp.initialBackoffMs,
                                    maxBackoffMs = serOp.maxBackoffMs,
                                    backoffMultiplier = serOp.backoffMultiplier
                                )
                            )
                        } catch (e: Exception) {
                            Timber.e(e, "Failed to deserialize operation: ${e.message}")
                        }
                    }
                    
                    // Update id counter to be higher than any existing ID
                    val maxId = pendingOperations.maxOfOrNull { it.id.toInt() } ?: 0
                    idCounter.set(maxId + 1)
                    
                    // Sort by priority
                    sortQueue()
                }
                
                Timber.d("Loaded ${pendingOperations.size} operations from persisted queue")
            }
        } catch (e: Exception) {
            Timber.e(e, "Error loading persisted queue: ${e.message}")
            // Continue with empty queue on error
        }
    }

    /**
     * Persist queue to storage
     */
    private fun persistQueue() {
        if (queueFile == null || serializeOperation == null) {
            return
        }
        
        try {
            queueLock.withLock {
                // Create serializable list
                val serializableList = pendingOperations.map { op ->
                    SerializableOperation(
                        id = op.id,
                        serializedOperation = serializeOperation.invoke(op.operation),
                        uniqueKey = op.uniqueKey,
                        priority = op.priority,
                        retryCount = op.retryCount,
                        initialBackoffMs = op.initialBackoffMs,
                        maxBackoffMs = op.maxBackoffMs,
                        backoffMultiplier = op.backoffMultiplier
                    )
                }
                
                // Write to file
                val jsonString = Json.encodeToString(serializableList)
                queueFile.writeText(jsonString)
                
                Timber.d("Persisted ${serializableList.size} operations to queue file")
            }
        } catch (e: Exception) {
            Timber.e(e, "Error persisting queue: ${e.message}")
        }
    }

    /**
     * Add an operation to the queue
     *
     * @param operation The operation to execute
     * @param uniqueKey Optional unique key for deduplication (replaces existing operation with same key)
     * @param priority Priority for this operation (lower number = higher priority)
     * @return ID of the queued operation
     */
    fun enqueue(
        operation: T,
        uniqueKey: String? = null,
        priority: Int = 5
    ): String {
        val id = idCounter.getAndIncrement().toString()
        
        queueLock.withLock {
            // Handle deduplication if uniqueKey is provided
            if (uniqueKey != null) {
                val existingIndex = pendingOperations.indexOfFirst { it.uniqueKey == uniqueKey }
                if (existingIndex != -1) {
                    Timber.d("Replacing existing operation with uniqueKey: $uniqueKey")
                    pendingOperations.removeAt(existingIndex)
                }
            }
            
            // Add new operation
            pendingOperations.add(
                QueueOperation(
                    id = id,
                    operation = operation,
                    uniqueKey = uniqueKey,
                    priority = priority,
                    initialBackoffMs = initialDelay,
                    maxBackoffMs = maxDelay,
                    backoffMultiplier = backoffMultiplier
                )
            )
            
            // Sort the queue by priority
            sortQueue()
        }
        
        // Persist to storage
        persistQueue()
        
        Timber.d("Enqueued operation with ID: $id (priority: $priority)")
        
        // Start processing if not already running
        startProcessing()
        
        return id
    }

    /**
     * Sort the queue by priority
     */
    private fun sortQueue() {
        pendingOperations.sortBy { it.priority }
    }

    /**
     * Start processing the queue
     */
    private fun startProcessing() {
        val shouldStart = queueLock.withLock {
            if (isProcessing.get() || isPaused || pendingOperations.isEmpty()) {
                false
            } else {
                isProcessing.set(true)
                true
            }
        }
        
        if (shouldStart) {
            Timber.d("Starting queue processing")
            
            // Process outside of the lock using coroutine
            processingScope.launch {
                processNextOperation()
            }
        }
    }

    /**
     * Process the next operation in the queue
     */
    private suspend fun processNextOperation() {
        // Get the next operation
        val operation = queueLock.withLock {
            if (pendingOperations.isEmpty()) {
                isProcessing.set(false)
                null
            } else {
                pendingOperations.first()
            }
        }
        
        if (operation == null) {
            return
        }
        
        try {
            Timber.d("Processing operation: ${operation.id}")
            
            // Process the operation
            val success = processor(operation.operation)
            
            // Remove if successful
            if (success) {
                queueLock.withLock {
                    val index = pendingOperations.indexOfFirst { it.id == operation.id }
                    if (index != -1) {
                        pendingOperations.removeAt(index)
                    }
                }
                
                Timber.d("Operation processed successfully: ${operation.id}")
                
                // Persist queue
                persistQueue()
                
                // Continue processing
                if (!isPaused) {
                    queueLock.withLock {
                        if (pendingOperations.isEmpty()) {
                            isProcessing.set(false)
                        }
                    }
                    
                    if (isProcessing.get()) {
                        processNextOperation()
                    }
                } else {
                    isProcessing.set(false)
                }
            }
        } catch (e: Exception) {
            Timber.e(e, "Error processing operation ${operation.id}: ${e.message}")
            
            // Handle retry
            queueLock.withLock {
                val index = pendingOperations.indexOfFirst { it.id == operation.id }
                
                if (index == -1) {
                    // Operation was removed by another thread somehow
                    isProcessing.set(false)
                    return
                }
                
                val op = pendingOperations[index]
                
                if (op.retryCount < maxRetries) {
                    // Retry
                    val updatedOp = op.copy(retryCount = op.retryCount + 1)
                    pendingOperations[index] = updatedOp
                    
                    // Move to end of its priority level
                    pendingOperations.removeAt(index)
                    pendingOperations.add(updatedOp)
                    sortQueue()
                    
                    Timber.w("Operation ${operation.id} failed, retrying (${updatedOp.retryCount}/$maxRetries)")
                } else {
                    // Operation failed permanently
                    Timber.e("Operation ${operation.id} failed permanently after ${operation.retryCount} retries")
                }
            }
            
            // Persist updated queue
            persistQueue()
            
            // Continue processing after failure with a delay for backoff
            val delay = calculateBackoff(operation.retryCount, operation.initialBackoffMs, operation.maxBackoffMs, operation.backoffMultiplier)
            kotlinx.coroutines.delay(delay)
            
            if (!isPaused) {
                processNextOperation()
            } else {
                isProcessing.set(false)
            }
        }
    }

    /**
     * Calculate exponential backoff delay
     */
    private fun calculateBackoff(
        attempt: Int,
        initialDelayMs: Long,
        maxDelayMs: Long,
        multiplier: Double
    ): Long {
        val delay = (initialDelayMs * Math.pow(multiplier, attempt.toDouble())).toLong()
        return Math.min(delay, maxDelayMs)
    }

    /**
     * Pause queue processing
     */
    fun pause() {
        queueLock.withLock {
            isPaused = true
            Timber.i("Queue $queueName paused")
        }
    }

    /**
     * Resume queue processing
     */
    fun resume() {
        val shouldStart = queueLock.withLock {
            val wasPaused = isPaused
            isPaused = false
            Timber.i("Queue $queueName resumed")
            wasPaused && !isProcessing.get() && pendingOperations.isNotEmpty()
        }
        
        if (shouldStart) {
            startProcessing()
        }
    }

    /**
     * Remove an operation from the queue
     *
     * @param id ID of the operation to remove
     * @return true if the operation was found and removed
     */
    fun removeOperation(id: String): Boolean {
        val removed = queueLock.withLock {
            val index = pendingOperations.indexOfFirst { it.id == id }
            if (index != -1) {
                pendingOperations.removeAt(index)
                true
            } else {
                false
            }
        }
        
        if (removed) {
            persistQueue()
            Timber.d("Removed operation with ID: $id")
        }
        
        return removed
    }

    /**
     * Get the number of pending operations
     */
    fun size(): Int = queueLock.withLock { pendingOperations.size }

    /**
     * Clear all operations from the queue
     */
    fun clear() {
        queueLock.withLock {
            pendingOperations.clear()
        }
        
        persistQueue()
        Timber.i("Cleared all operations from queue $queueName")
    }

    /**
     * Get the number of operations with the given priority
     */
    fun countByPriority(priority: Int): Int = queueLock.withLock {
        pendingOperations.count { it.priority == priority }
    }

    /**
     * Flush all pending operations
     *
     * @return Number of successfully processed operations
     */
    suspend fun flush(): Int {
        // Pause queue processing
        pause()
        
        // Get all operations
        val operations = queueLock.withLock { pendingOperations.toList() }
        
        var successCount = 0
        
        // Process each operation
        for (operation in operations) {
            try {
                Timber.d("Flushing operation: ${operation.id}")
                
                // Process the operation
                val success = processor(operation.operation)
                
                if (success) {
                    queueLock.withLock {
                        val index = pendingOperations.indexOfFirst { it.id == operation.id }
                        if (index != -1) {
                            pendingOperations.removeAt(index)
                        }
                    }
                    
                    successCount++
                    Timber.d("Successfully flushed operation: ${operation.id}")
                } else {
                    Timber.w("Failed to flush operation: ${operation.id}")
                }
            } catch (e: Exception) {
                Timber.e(e, "Error flushing operation ${operation.id}: ${e.message}")
            }
        }
        
        // Persist updated queue
        persistQueue()
        
        Timber.i("Flushed $successCount/${operations.size} operations from queue $queueName")
        
        return successCount
    }

    /**
     * Clean up resources
     */
    fun shutdown() {
        // Cancel all coroutines
        processingScope.cancel()
        
        Timber.i("Queue $queueName shut down")
    }
} 