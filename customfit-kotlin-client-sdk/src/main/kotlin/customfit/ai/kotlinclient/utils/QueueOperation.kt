package customfit.ai.kotlinclient.utils

import kotlinx.serialization.Serializable

/**
 * Represents an operation in the background processing queue
 */
data class QueueOperation<T>(
    val id: String,
    val operation: T,
    val uniqueKey: String? = null,
    val priority: Int = 5,
    val retryCount: Int = 0,
    val initialBackoffMs: Long = 1000,
    val maxBackoffMs: Long = 30000,
    val backoffMultiplier: Double = 2.0
)

/**
 * Serializable version of QueueOperation for persistence
 */
@Serializable
data class SerializableOperation(
    val id: String,
    val serializedOperation: String,
    val uniqueKey: String? = null,
    val priority: Int = 5,
    val retryCount: Int = 0,
    val initialBackoffMs: Long = 1000,
    val maxBackoffMs: Long = 30000,
    val backoffMultiplier: Double = 2.0
) 