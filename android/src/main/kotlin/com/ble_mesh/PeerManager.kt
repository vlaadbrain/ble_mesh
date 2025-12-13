package com.ble_mesh

import android.util.Log
import com.ble_mesh.models.Peer
import java.util.concurrent.ConcurrentHashMap

/**
 * Manages discovered and connected peers
 */
class PeerManager {
    private val tag = "PeerManager"

    // Map of peer ID to Peer
    private val discoveredPeers = ConcurrentHashMap<String, Peer>()
    private val connectedPeers = ConcurrentHashMap<String, Peer>()

    // Callbacks
    var onPeerDiscovered: ((Peer) -> Unit)? = null
    var onPeerConnected: ((Peer) -> Unit)? = null
    var onPeerDisconnected: ((Peer) -> Unit)? = null

    /**
     * Add a discovered peer
     */
    fun addDiscoveredPeer(peer: Peer) {
        val existingPeer = discoveredPeers[peer.id]

        if (existingPeer == null) {
            // New peer discovered
            discoveredPeers[peer.id] = peer
            Log.d(tag, "New peer discovered: ${peer.id} (${peer.nickname})")
            onPeerDiscovered?.invoke(peer)
        } else {
            // Update existing peer (RSSI, lastSeen, etc.)
            val updatedPeer = peer.copy(lastSeen = System.currentTimeMillis())
            discoveredPeers[peer.id] = updatedPeer
            Log.d(tag, "Updated peer: ${peer.id} (${peer.nickname}), RSSI: ${peer.rssi}")
        }
    }

    /**
     * Mark a peer as connected
     */
    fun markPeerConnected(peerId: String) {
        val peer = discoveredPeers[peerId] ?: return

        val connectedPeer = peer.copy(
            isConnected = true,
            lastSeen = System.currentTimeMillis()
        )

        connectedPeers[peerId] = connectedPeer
        discoveredPeers[peerId] = connectedPeer

        Log.d(tag, "Peer connected: $peerId (${peer.nickname})")
        onPeerConnected?.invoke(connectedPeer)
    }

    /**
     * Mark a peer as disconnected
     */
    fun markPeerDisconnected(peerId: String) {
        val peer = connectedPeers.remove(peerId) ?: return

        val disconnectedPeer = peer.copy(
            isConnected = false,
            lastSeen = System.currentTimeMillis()
        )

        discoveredPeers[peerId] = disconnectedPeer

        Log.d(tag, "Peer disconnected: $peerId (${peer.nickname})")
        onPeerDisconnected?.invoke(disconnectedPeer)
    }

    /**
     * Remove a peer completely
     */
    fun removePeer(peerId: String) {
        discoveredPeers.remove(peerId)
        connectedPeers.remove(peerId)
        Log.d(tag, "Peer removed: $peerId")
    }

    /**
     * Get a peer by ID
     */
    fun getPeer(peerId: String): Peer? {
        return discoveredPeers[peerId]
    }

    /**
     * Get all discovered peers
     */
    fun getDiscoveredPeers(): List<Peer> {
        return discoveredPeers.values.toList()
    }

    /**
     * Get all connected peers
     */
    fun getConnectedPeers(): List<Peer> {
        return connectedPeers.values.toList()
    }

    /**
     * Get count of connected peers
     */
    fun getConnectedPeerCount(): Int {
        return connectedPeers.size
    }

    /**
     * Check if a peer is connected
     */
    fun isPeerConnected(peerId: String): Boolean {
        return connectedPeers.containsKey(peerId)
    }

    /**
     * Clear all peers
     */
    fun clearAll() {
        discoveredPeers.clear()
        connectedPeers.clear()
        Log.d(tag, "All peers cleared")
    }

    /**
     * Remove stale peers (not seen for a while)
     */
    fun removeStalesPeers(timeoutMs: Long = 60000L) {
        val currentTime = System.currentTimeMillis()
        val stalePeers = discoveredPeers.filter { (_, peer) ->
            !peer.isConnected && (currentTime - peer.lastSeen) > timeoutMs
        }

        stalePeers.forEach { (peerId, _) ->
            removePeer(peerId)
        }

        if (stalePeers.isNotEmpty()) {
            Log.d(tag, "Removed ${stalePeers.size} stale peers")
        }
    }

    /**
     * Clean up resources
     */
    fun cleanup() {
        clearAll()
        onPeerDiscovered = null
        onPeerConnected = null
        onPeerDisconnected = null
    }
}

