import Foundation

/**
 * Manages a persistent blocklist of peers by sender UUID
 *
 * Blocked peers will not be able to connect (incoming or outgoing)
 * and their messages will be ignored.
 *
 * The blocklist is persisted to UserDefaults and survives app restarts.
 */
class BlocklistManager {
    private let tag = "BlocklistManager"

    // Thread-safe queue for blocklist operations
    private let queue = DispatchQueue(label: "com.ble_mesh.blocklist")

    // Set of blocked peer sender IDs
    private var blockedPeers: Set<String> = []

    // UserDefaults key
    private let blockedPeersKey = "ble_mesh_blocked_peers"

    init() {
        loadBlocklist()
    }

    /**
     * Block a peer by sender UUID
     *
     * - Parameter senderId: The sender UUID to block
     * - Returns: true if the peer was newly blocked, false if already blocked
     */
    func blockPeer(_ senderId: String) -> Bool {
        return queue.sync {
            if blockedPeers.insert(senderId).inserted {
                saveBlocklist()
                print("[\(tag)] Blocked peer: \(senderId) (total: \(blockedPeers.count))")
                return true
            }
            print("[\(tag)] Peer already blocked: \(senderId)")
            return false
        }
    }

    /**
     * Unblock a peer by sender UUID
     *
     * - Parameter senderId: The sender UUID to unblock
     * - Returns: true if the peer was unblocked, false if not blocked
     */
    func unblockPeer(_ senderId: String) -> Bool {
        return queue.sync {
            if blockedPeers.remove(senderId) != nil {
                saveBlocklist()
                print("[\(tag)] Unblocked peer: \(senderId) (remaining: \(blockedPeers.count))")
                return true
            }
            print("[\(tag)] Peer was not blocked: \(senderId)")
            return false
        }
    }

    /**
     * Check if a peer is blocked
     *
     * - Parameter senderId: The sender UUID to check
     * - Returns: true if the peer is blocked
     */
    func isBlocked(_ senderId: String) -> Bool {
        return queue.sync {
            return blockedPeers.contains(senderId)
        }
    }

    /**
     * Get all blocked peer IDs
     *
     * - Returns: Array of blocked sender UUIDs
     */
    func getBlockedPeers() -> [String] {
        return queue.sync {
            return Array(blockedPeers)
        }
    }

    /**
     * Get count of blocked peers
     *
     * - Returns: Number of blocked peers
     */
    func getBlockedPeerCount() -> Int {
        return queue.sync {
            return blockedPeers.count
        }
    }

    /**
     * Clear the entire blocklist
     */
    func clearBlocklist() {
        queue.sync {
            let count = blockedPeers.count
            blockedPeers.removeAll()
            saveBlocklist()
            print("[\(tag)] Cleared blocklist (\(count) peers removed)")
        }
    }

    /**
     * Load blocklist from persistent storage
     */
    private func loadBlocklist() {
        if let blockedArray = UserDefaults.standard.array(forKey: blockedPeersKey) as? [String] {
            blockedPeers = Set(blockedArray.filter { !$0.isEmpty })
            print("[\(tag)] Loaded \(blockedPeers.count) blocked peers from storage")
        } else {
            print("[\(tag)] No blocked peers found in storage")
        }
    }

    /**
     * Save blocklist to persistent storage
     */
    private func saveBlocklist() {
        let blockedArray = Array(blockedPeers)
        UserDefaults.standard.set(blockedArray, forKey: blockedPeersKey)
        UserDefaults.standard.synchronize()
        print("[\(tag)] Saved \(blockedPeers.count) blocked peers to storage")
    }

    /**
     * Clean up resources
     */
    func cleanup() {
        queue.sync {
            // Save before cleanup
            saveBlocklist()
            print("[\(tag)] Cleanup complete")
        }
    }
}

