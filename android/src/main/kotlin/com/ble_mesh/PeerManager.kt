package com.ble_mesh

import android.util.Log
import com.ble_mesh.models.Peer
import com.ble_mesh.models.PeerConnectionState
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
            connectionState = PeerConnectionState.CONNECTED,
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
            connectionState = PeerConnectionState.DISCONNECTED,
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
     * Get a peer by ID (connectionId)
     */
    fun getPeer(peerId: String): Peer? {
        return discoveredPeers[peerId]
    }

    /**
     * Get a peer by sender UUID
     */
    fun getPeerBySenderId(senderId: String): Peer? {
        return discoveredPeers.values.firstOrNull { it.senderId == senderId }
    }

    /**
     * Update peer senderId (after handshake)
     */
    fun updatePeerSenderId(connectionId: String, senderId: String) {
        discoveredPeers[connectionId]?.let { peer ->
            val updatedPeer = peer.copy(senderId = senderId)
            discoveredPeers[connectionId] = updatedPeer
            if (connectedPeers.containsKey(connectionId)) {
                connectedPeers[connectionId] = updatedPeer
            }
            Log.d(tag, "Updated peer senderId: $connectionId -> $senderId")
        }
    }

    /**
     * Update peer connection state
     */
    fun updatePeerConnectionState(senderId: String, state: com.ble_mesh.models.PeerConnectionState) {
        val peer = getPeerBySenderId(senderId) ?: return
        val updatedPeer = peer.copy(
            connectionState = state,
            lastSeen = System.currentTimeMillis()
        )
        discoveredPeers[peer.connectionId] = updatedPeer
        if (state == com.ble_mesh.models.PeerConnectionState.CONNECTED) {
            connectedPeers[peer.connectionId] = updatedPeer
        } else if (state == com.ble_mesh.models.PeerConnectionState.DISCONNECTED) {
            connectedPeers.remove(peer.connectionId)
        }
        Log.d(tag, "Updated peer state: $senderId -> ${state.name}")
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
    fun removeStalePeers(timeoutMs: Long = 60000L) {
        val currentTime = System.currentTimeMillis()
        val stalePeers = discoveredPeers.filter { (_, peer) ->
            peer.connectionState != PeerConnectionState.CONNECTED && (currentTime - peer.lastSeen) > timeoutMs
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

