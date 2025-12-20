package com.ble_mesh

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import java.util.concurrent.ConcurrentHashMap

/**
 * Manages a persistent blocklist of peers by sender UUID
 *
 * Blocked peers will not be able to connect (incoming or outgoing)
 * and their messages will be ignored.
 *
 * The blocklist is persisted to SharedPreferences and survives app restarts.
 */
class BlocklistManager(context: Context) {
    private val tag = "BlocklistManager"

    private val prefs: SharedPreferences = context.getSharedPreferences(
        PREFS_NAME,
        Context.MODE_PRIVATE
    )

    // Thread-safe set of blocked peer sender IDs
    private val blockedPeers = ConcurrentHashMap.newKeySet<String>()

    companion object {
        private const val PREFS_NAME = "ble_mesh_blocklist"
        private const val KEY_BLOCKED_PEERS = "blocked_peers"
    }

    init {
        loadBlocklist()
    }

    /**
     * Block a peer by sender UUID
     *
     * @param senderId The sender UUID to block
     * @return true if the peer was newly blocked, false if already blocked
     */
    fun blockPeer(senderId: String): Boolean {
        if (blockedPeers.add(senderId)) {
            saveBlocklist()
            Log.d(tag, "Blocked peer: $senderId (total: ${blockedPeers.size})")
            return true
        }
        Log.d(tag, "Peer already blocked: $senderId")
        return false
    }

    /**
     * Unblock a peer by sender UUID
     *
     * @param senderId The sender UUID to unblock
     * @return true if the peer was unblocked, false if not blocked
     */
    fun unblockPeer(senderId: String): Boolean {
        if (blockedPeers.remove(senderId)) {
            saveBlocklist()
            Log.d(tag, "Unblocked peer: $senderId (remaining: ${blockedPeers.size})")
            return true
        }
        Log.d(tag, "Peer was not blocked: $senderId")
        return false
    }

    /**
     * Check if a peer is blocked
     *
     * @param senderId The sender UUID to check
     * @return true if the peer is blocked
     */
    fun isBlocked(senderId: String): Boolean {
        return blockedPeers.contains(senderId)
    }

    /**
     * Get all blocked peer IDs
     *
     * @return List of blocked sender UUIDs
     */
    fun getBlockedPeers(): List<String> {
        return blockedPeers.toList()
    }

    /**
     * Get count of blocked peers
     *
     * @return Number of blocked peers
     */
    fun getBlockedPeerCount(): Int {
        return blockedPeers.size
    }

    /**
     * Clear the entire blocklist
     */
    fun clearBlocklist() {
        val count = blockedPeers.size
        blockedPeers.clear()
        saveBlocklist()
        Log.d(tag, "Cleared blocklist ($count peers removed)")
    }

    /**
     * Load blocklist from persistent storage
     */
    private fun loadBlocklist() {
        val blockedPeersString = prefs.getString(KEY_BLOCKED_PEERS, "") ?: ""
        if (blockedPeersString.isNotEmpty()) {
            val peerIds = blockedPeersString.split(",").filter { it.isNotEmpty() }
            blockedPeers.addAll(peerIds)
            Log.d(tag, "Loaded ${blockedPeers.size} blocked peers from storage")
        } else {
            Log.d(tag, "No blocked peers found in storage")
        }
    }

    /**
     * Save blocklist to persistent storage
     */
    private fun saveBlocklist() {
        val blockedPeersString = blockedPeers.joinToString(",")
        prefs.edit()
            .putString(KEY_BLOCKED_PEERS, blockedPeersString)
            .apply()
        Log.d(tag, "Saved ${blockedPeers.size} blocked peers to storage")
    }

    /**
     * Clean up resources
     */
    fun cleanup() {
        // Save before cleanup
        saveBlocklist()
        Log.d(tag, "Cleanup complete")
    }
}

