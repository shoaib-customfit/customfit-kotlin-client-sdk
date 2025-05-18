package customfit.ai.kotlinclient.utils

import customfit.ai.kotlinclient.logging.Logger
import kotlinx.coroutines.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import java.io.File
import java.util.*
import java.util.concurrent.Executors
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock
import java.util.concurrent.TimeUnit

/**
 * A persistent queue for processing operations in the background.
 * Supports durability across app restarts and prioritization.
 */
class BackgroundQueue(
    private val queueName: String,
    private val processor: suspend (Map<String, Any>) -> Boolean,
    private val maxRetries: Int = 3,
    private val queueDirectory: File? = null
) {
    companion object {
        private const val TAG = "BackgroundQueue"
    }

    // Path for queue storage
    private val queueFile: File by lazy {
        val dir = queueDirectory ?: File(System.getProperty("java.io.tmpdir"), "cf_queues")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        File(dir, "${queueName}_queue.json")
    }

    // Queue operations
    private val pendingOperations = Collections.synchronizedList(mutableListOf<QueuedOperation>())
    
    // Queue state
    private var isProcessing = false
    private var isPaused = false
    
    // Lock for synchronization
    private val queueLock = ReentrantLock()
    
    // Coroutine scope for processing
    private val processingScope = CoroutineScope(
        Executors.newSingleThreadExecutor().asCoroutineDispatcher() + SupervisorJob()
    )
    
    // JSON serializer
    private val json = Json { ignoreUnknownKeys = true }
    
    // Initialization
    init {
        loadPersistedQueue()
        
        // Start processing if there are pending operations
        if (pendingOperations.isNotEmpty()) {
            startProcessing()
        }
        
        Logger.i(TAG, "Background queue $queueName initialized with ${pendingOperations.size} operations")
    }
    
    /**
     * Load previously persisted queue from disk
     */
    private fun loadPersistedQueue() {
        try {
            if (queueFile.exists()) {
                val contents = queueFile.readText()
                val deserializedQueue = json.decodeFromString<List<SerializableQueuedOperation>>(contents)
                
                queueLock.withLock {
                    pendingOperations.clear()
                    
                    for (item in deserializedQueue) {
                        pendingOperations.add(item.toQueuedOperation())
                    }
                    
                    // Sort by priority then timestamp
                    sortQueue()
                }
                
                Logger.d(TAG, "Loaded ${pendingOperations.size} operations from persisted queue")
            }
        } catch (e: Exception) {
            Logger.e(TAG, "Error loading persisted queue: ${e.message}", e)
            // Continue with empty queue on error
        }
    }
    
    /**
     * Save queue to disk
     */
    private fun persistQueue() {
        try {
            val serializableList = queueLock.withLock {
                pendingOperations.map { it.toSerializable() }
            }
            
            val jsonString = json.encodeToString(serializableList)
            queueFile.writeText(jsonString)
            
            Logger.d(TAG, "Persisted ${serializableList.size} operations to queue file")
        } catch (e: Exception) {
            Logger.e(TAG, "Error persisting queue: ${e.message}", e)
        }
    }
    
    /**
     * Sort the queue by priority (higher first) then timestamp (older first)
     */
    private fun sortQueue() {
        pendingOperations.sortWith(compareByDescending<QueuedOperation> { it.priority }
            .thenBy { it.timestamp })
    }
    
    /**
     * Add an operation to the queue
     *
     * @param data The data for the operation
     * @param priority Priority of the operation (higher is processed first)
     * @param uniqueKey Optional key to ensure uniqueness (will replace existing operation with same key)
     * @return Operation ID
     */
    fun enqueue(
        data: Map<String, Any>,
        priority: Int = 0,
        uniqueKey: String? = null
    ): String {
        val id = uniqueKey ?: UUID.randomUUID().toString()
        
        queueLock.withLock {
            // Check if operation with same uniqueKey exists
            if (uniqueKey != null) {
                val existingIndex = pendingOperations.indexOfFirst { it.id == uniqueKey }
                if (existingIndex != -1) {
                    Logger.d(TAG, "Replacing existing operation with uniqueKey: $uniqueKey")
                    pendingOperations.removeAt(existingIndex)
                }
            }
            
            // Add new operation
            val operation = QueuedOperation(
                id = id,
                data = data,
                priority = priority,
                timestamp = System.currentTimeMillis(),
                retryCount = 0
            )
            
            pendingOperations.add(operation)
            
            // Re-sort queue
            sortQueue()
        }
        
        // Persist queue
        persistQueue()
        
        Logger.d(TAG, "Enqueued operation with ID: $id (priority: $priority)")
        
        // Start processing if not already running
        if (!isProcessing && !isPaused) {
            startProcessing()
        }
        
        return id
    }
    
    /**
     * Start processing the queue
     */
    private fun startProcessing() {
        queueLock.withLock {
            if (isProcessing || isPaused || pendingOperations.isEmpty()) {
                return
            }
            
            isProcessing = true
        }
        
        Logger.d(TAG, "Starting queue processing")
        
        // Process outside of the lock using coroutine
        processingScope.launch {
            processNextOperation()
        }
    }
    
    /**
     * Process the next operation in the queue
     */
    private suspend fun processNextOperation() {
        var operation: QueuedOperation? = null
        
        // Get the next operation under the lock
        queueLock.withLock {
            if (pendingOperations.isEmpty() || isPaused) {
                isProcessing = false
                return
            }
            
            operation = pendingOperations.first()
        }
        
        // If no operation or paused, stop processing
        if (operation == null) {
            queueLock.withLock {
                isProcessing = false
            }
            return
        }
        
        try {
            Logger.d(TAG, "Processing operation: ${operation!!.id}")
            
            // Process the operation
            val success = processor(operation!!.data)
            
            // Remove operation if successful
            if (success) {
                queueLock.withLock {
                    pendingOperations.remove(operation)
                }
                
                Logger.d(TAG, "Operation processed successfully: ${operation!!.id}")
                
                // Persist queue
                persistQueue()
                
                // Process next operation
                processNextOperation()
            } else {
                // Handle retry
                handleRetry(operation!!)
            }
        } catch (e: Exception) {
            Logger.e(TAG, "Error processing operation ${operation!!.id}: ${e.message}", e)
            
            // Handle retry
            handleRetry(operation!!)
        }
    }
    
    /**
     * Handle retry logic for a failed operation
     */
    private suspend fun handleRetry(operation: QueuedOperation) {
        queueLock.withLock {
            // Remove from current position
            pendingOperations.remove(operation)
            
            // If under retry limit, increment retry count and requeue
            if (operation.retryCount < maxRetries) {
                val updatedOp = operation.copy(retryCount = operation.retryCount + 1)
                
                // Move to end of its priority level
                pendingOperations.add(updatedOp)
                
                // Re-sort queue
                sortQueue()
                
                Logger.w(TAG, "Operation ${operation.id} failed, retrying (${updatedOp.retryCount}/$maxRetries)")
            } else {
                // Operation failed permanently
                Logger.e(TAG, "Operation ${operation.id} failed permanently after ${operation.retryCount} retries")
            }
        }
        
        // Persist queue
        persistQueue()
        
        // Process next operation
        processNextOperation()
    }
    
    /**
     * Pause queue processing
     */
    fun pause() {
        queueLock.withLock {
            isPaused = true
            Logger.i(TAG, "Queue $queueName paused")
        }
    }
    
    /**
     * Resume queue processing
     */
    fun resume() {
        val shouldStart = queueLock.withLock {
            val wasPaused = isPaused
            isPaused = false
            Logger.i(TAG, "Queue $queueName resumed")
            wasPaused && !isProcessing && pendingOperations.isNotEmpty()
        }
        
        if (shouldStart) {
            startProcessing()
        }
    }
    
    /**
     * Get number of pending operations
     */
    fun getPendingCount(): Int {
        return queueLock.withLock { pendingOperations.size }
    }
    
    /**
     * Check if operation with given ID exists in the queue
     */
    fun containsOperation(id: String): Boolean {
        return queueLock.withLock { pendingOperations.any { it.id == id } }
    }
    
    /**
     * Remove an operation from the queue by ID
     */
    fun removeOperation(id: String): Boolean {
        val removed = queueLock.withLock {
            val index = pendingOperations.indexOfFirst { it.id == id }
            
            if (index == -1) {
                return@withLock false
            }
            
            pendingOperations.removeAt(index)
            true
        }
        
        if (removed) {
            persistQueue()
            Logger.d(TAG, "Removed operation with ID: $id")
        }
        
        return removed
    }
    
    /**
     * Clear all operations from the queue
     */
    fun clear() {
        queueLock.withLock {
            pendingOperations.clear()
        }
        
        persistQueue()
        Logger.i(TAG, "Cleared all operations from queue $queueName")
    }
    
    /**
     * Flush the queue, processing all operations immediately
     * Returns the number of successfully processed operations
     */
    suspend fun flush(): Int {
        val operations = queueLock.withLock {
            pendingOperations.toList()
        }
        
        var successCount = 0
        
        // Process all operations
        for (operation in operations) {
            try {
                Logger.d(TAG, "Flushing operation: ${operation.id}")
                
                // Process the operation
                val success = processor(operation.data)
                
                if (success) {
                    queueLock.withLock {
                        pendingOperations.remove(operation)
                    }
                    
                    successCount++
                    Logger.d(TAG, "Successfully flushed operation: ${operation.id}")
                } else {
                    Logger.w(TAG, "Failed to flush operation: ${operation.id}")
                }
            } catch (e: Exception) {
                Logger.e(TAG, "Error flushing operation ${operation.id}: ${e.message}", e)
            }
        }
        
        // Persist queue
        persistQueue()
        
        Logger.i(TAG, "Flushed $successCount/${operations.size} operations from queue $queueName")
        
        return successCount
    }
    
    /**
     * Shutdown the queue
     */
    fun shutdown() {
        // Pause processing
        pause()
        
        // Persist queue to ensure no operations are lost
        persistQueue()
        
        // Cancel any pending coroutines
        processingScope.cancel()
        
        Logger.i(TAG, "Queue $queueName shut down")
    }
}

/**
 * Represents an operation in the queue
 */
data class QueuedOperation(
    val id: String,
    val data: Map<String, Any>,
    val priority: Int,
    val timestamp: Long,
    val retryCount: Int
) {
    /**
     * Convert to serializable form
     */
    fun toSerializable(): SerializableQueuedOperation {
        return SerializableQueuedOperation(
            id = id,
            data = data.mapValues { it.value.toString() },
            priority = priority,
            timestamp = timestamp,
            retryCount = retryCount
        )
    }
}

/**
 * Serializable version of QueuedOperation for persistence
 */
@Serializable
data class SerializableQueuedOperation(
    val id: String,
    val data: Map<String, String>,
    val priority: Int,
    val timestamp: Long,
    val retryCount: Int
) {
    /**
     * Convert to regular QueuedOperation
     */
    fun toQueuedOperation(): QueuedOperation {
        return QueuedOperation(
            id = id,
            data = data,
            priority = priority,
            timestamp = timestamp,
            retryCount = retryCount
        )
    }
} 