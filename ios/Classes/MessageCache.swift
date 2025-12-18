import Foundation

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
class MessageCache {
    /**
     * Composite key for message identification
     * Combines senderId (compact device ID) and messageId for unique identification
     */
    struct MessageCacheKey: Hashable {
        let senderId: String
        let messageId: Int64

        func hash(into hasher: inout Hasher) {
            hasher.combine(senderId)
            hasher.combine(messageId)
        }

        static func == (lhs: MessageCacheKey, rhs: MessageCacheKey) -> Bool {
            return lhs.senderId == rhs.senderId && lhs.messageId == rhs.messageId
        }
    }

    private struct CacheEntry {
        let key: MessageCacheKey
        let timestamp: Date
    }

    private let maxSize: Int
    private let expirationTimeInterval: TimeInterval

    // Thread-safe storage
    private var cache: [MessageCacheKey: CacheEntry] = [:]
    private var insertionOrder: [MessageCacheKey] = []
    private let queue = DispatchQueue(label: "com.ble_mesh.messageCache", attributes: .concurrent)

    /**
     * Initialize message cache
     *
     * - Parameters:
     *   - maxSize: Maximum number of entries (default: 1000)
     *   - expirationTimeInterval: Time in seconds before entries expire (default: 300 = 5 minutes)
     */
    init(maxSize: Int = 1000, expirationTimeInterval: TimeInterval = 300) {
        self.maxSize = maxSize
        self.expirationTimeInterval = expirationTimeInterval
    }

    /**
     * Check if a message has been seen before
     *
     * - Parameters:
     *   - senderId: Sender's compact device ID
     *   - messageId: Unique message identifier
     * - Returns: true if message exists in cache and hasn't expired, false otherwise
     */
    func hasMessage(senderId: String, messageId: Int64) -> Bool {
        let key = MessageCacheKey(senderId: senderId, messageId: messageId)
        return queue.sync {
            guard let entry = cache[key] else {
                return false
            }

            // Check if entry has expired
            let now = Date()
            if now.timeIntervalSince(entry.timestamp) > expirationTimeInterval {
                // Entry expired, remove it
                removeMessageUnsafe(key)
                return false
            }

            return true
        }
    }

    /**
     * Add a message to the cache
     *
     * - Parameters:
     *   - senderId: Sender's compact device ID
     *   - messageId: Unique message identifier
     * - Returns: true if message was added, false if it already existed
     */
    func addMessage(senderId: String, messageId: Int64) -> Bool {
        let key = MessageCacheKey(senderId: senderId, messageId: messageId)
        return queue.sync(flags: .barrier) {
            // Check if message already exists
            if let entry = cache[key] {
                let now = Date()
                if now.timeIntervalSince(entry.timestamp) <= expirationTimeInterval {
                    return false
                }
                // Entry expired, remove it
                removeMessageUnsafe(key)
            }

            // Check capacity and evict oldest entry if needed
            if cache.count >= maxSize {
                evictOldestUnsafe()
            }

            // Add new entry
            let entry = CacheEntry(key: key, timestamp: Date())
            cache[key] = entry
            insertionOrder.append(key)

            return true
        }
    }

    /**
     * Remove a message from the cache (unsafe - must be called within queue)
     *
     * - Parameter key: Composite message key
     */
    private func removeMessageUnsafe(_ key: MessageCacheKey) {
        cache.removeValue(forKey: key)
        if let index = insertionOrder.firstIndex(of: key) {
            insertionOrder.remove(at: index)
        }
    }

    /**
     * Evict the oldest entry from the cache (LRU) (unsafe - must be called within queue)
     */
    private func evictOldestUnsafe() {
        guard !insertionOrder.isEmpty else { return }

        let oldest = insertionOrder.removeFirst()
        cache.removeValue(forKey: oldest)
    }

    /**
     * Clear all entries from the cache
     */
    func clear() {
        queue.sync(flags: .barrier) {
            cache.removeAll()
            insertionOrder.removeAll()
        }
    }

    /**
     * Remove expired entries from the cache
     *
     * This method should be called periodically to clean up expired entries
     * and free memory.
     */
    func cleanupExpired() {
        queue.sync(flags: .barrier) {
            let now = Date()
            var expiredKeys: [MessageCacheKey] = []

            // Find all expired entries
            for (key, entry) in cache {
                if now.timeIntervalSince(entry.timestamp) > expirationTimeInterval {
                    expiredKeys.append(key)
                }
            }

            // Remove expired entries
            for key in expiredKeys {
                removeMessageUnsafe(key)
            }
        }
    }

    /**
     * Get current cache size
     *
     * - Returns: Number of entries in the cache
     */
    func size() -> Int {
        return queue.sync {
            return cache.count
        }
    }

    /**
     * Get cache statistics
     *
     * - Returns: Dictionary with cache statistics (size, capacity, oldest entry age)
     */
    func getStats() -> [String: Any] {
        return queue.sync {
            let now = Date()
            let oldestEntry = insertionOrder.first.flatMap { cache[$0] }
            let oldestEntryAge = oldestEntry.map { now.timeIntervalSince($0.timestamp) } ?? 0

            return [
                "size": cache.count,
                "capacity": maxSize,
                "oldestEntryAgeMs": Int(oldestEntryAge * 1000),
                "expirationTimeMs": Int(expirationTimeInterval * 1000)
            ]
        }
    }
}

