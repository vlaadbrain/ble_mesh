package com.ble_mesh

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * LRU cache for message deduplication with time-based expiration
 *
 * This cache is used to prevent duplicate message processing in the mesh network.
 * Messages are identified by a composite key of (senderId, messageId) to prevent
 * false positives when different senders generate the same message ID.
 *
 * Features:
 * - Composite key (senderId + messageId) for reliable deduplication
 * - LRU eviction when capacity is reached
 * - Time-based expiration (default 5 minutes)
 * - Thread-safe operations
 * - Automatic cleanup of expired entries
 */
class MessageCache(
    private val maxSize: Int = 1000,
    private val expirationTimeMs: Long = TimeUnit.MINUTES.toMillis(5)
) {
    /**
     * Composite key for message identification
     * Combines senderId (compact device ID) and messageId for unique identification
     */
    data class MessageCacheKey(
        val senderId: String,
        val messageId: Long
    ) {
        override fun toString(): String = "$senderId:$messageId"
    }

    private data class CacheEntry(
        val key: MessageCacheKey,
        val timestamp: Long
    )

    // Use ConcurrentHashMap for thread-safe operations
    private val cache = ConcurrentHashMap<MessageCacheKey, CacheEntry>()

    // Track insertion order for LRU eviction
    private val insertionOrder = mutableListOf<MessageCacheKey>()
    private val lock = Any()

    /**
     * Check if a message has been seen before
     *
     * @param senderId Sender's compact device ID
     * @param messageId Unique message identifier
     * @return true if message exists in cache and hasn't expired, false otherwise
     */
    fun hasMessage(senderId: String, messageId: Long): Boolean {
        val key = MessageCacheKey(senderId, messageId)
        val entry = cache[key] ?: return false

        // Check if entry has expired
        val now = System.currentTimeMillis()
        if (now - entry.timestamp > expirationTimeMs) {
            // Entry expired, remove it
            removeMessage(key)
            return false
        }

        return true
    }

    /**
     * Add a message to the cache
     *
     * @param senderId Sender's compact device ID
     * @param messageId Unique message identifier
     * @return true if message was added, false if it already existed
     */
    fun addMessage(senderId: String, messageId: Long): Boolean {
        // Check if message already exists
        if (hasMessage(senderId, messageId)) {
            return false
        }

        val key = MessageCacheKey(senderId, messageId)
        synchronized(lock) {
            // Check capacity and evict oldest entry if needed
            if (cache.size >= maxSize) {
                evictOldest()
            }

            // Add new entry
            val entry = CacheEntry(key, System.currentTimeMillis())
            cache[key] = entry
            insertionOrder.add(key)
        }

        return true
    }

    /**
     * Remove a message from the cache
     *
     * @param key Composite message key
     */
    private fun removeMessage(key: MessageCacheKey) {
        synchronized(lock) {
            cache.remove(key)
            insertionOrder.remove(key)
        }
    }

    /**
     * Evict the oldest entry from the cache (LRU)
     */
    private fun evictOldest() {
        synchronized(lock) {
            if (insertionOrder.isNotEmpty()) {
                val oldest = insertionOrder.removeAt(0)
                cache.remove(oldest)
            }
        }
    }

    /**
     * Clear all entries from the cache
     */
    fun clear() {
        synchronized(lock) {
            cache.clear()
            insertionOrder.clear()
        }
    }

    /**
     * Remove expired entries from the cache
     *
     * This method should be called periodically to clean up expired entries
     * and free memory.
     */
    fun cleanupExpired() {
        val now = System.currentTimeMillis()
        val expiredKeys = mutableListOf<MessageCacheKey>()

        synchronized(lock) {
            // Find all expired entries
            cache.forEach { (key, entry) ->
                if (now - entry.timestamp > expirationTimeMs) {
                    expiredKeys.add(key)
                }
            }

            // Remove expired entries
            expiredKeys.forEach { key ->
                cache.remove(key)
                insertionOrder.remove(key)
            }
        }
    }

    /**
     * Get current cache size
     *
     * @return Number of entries in the cache
     */
    fun size(): Int = cache.size

    /**
     * Get cache statistics
     *
     * @return Map with cache statistics (size, capacity, oldest entry age)
     */
    fun getStats(): Map<String, Any> {
        val now = System.currentTimeMillis()
        val oldestEntry = synchronized(lock) {
            if (insertionOrder.isNotEmpty()) {
                cache[insertionOrder[0]]
            } else {
                null
            }
        }

        return mapOf(
            "size" to cache.size,
            "capacity" to maxSize,
            "oldestEntryAgeMs" to (oldestEntry?.let { now - it.timestamp } ?: 0),
            "expirationTimeMs" to expirationTimeMs
        )
    }
}

