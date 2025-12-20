package com.ble_mesh.models

import android.bluetooth.BluetoothDevice

/**
 * Connection state of a peer
 */
enum class PeerConnectionState {
    DISCOVERED,
    CONNECTING,
    CONNECTED,
    DISCONNECTING,
    DISCONNECTED
}

/**
 * Represents a peer in the BLE mesh network
 */
data class Peer(
    val senderId: String? = null,        // Stable UUID identifier (6-byte compact format)
    val connectionId: String,            // MAC address for connections
    val nickname: String,
    val rssi: Int = 0,
    val lastSeen: Long = System.currentTimeMillis(),
    val connectionState: PeerConnectionState = PeerConnectionState.DISCOVERED,
    val hopCount: Int = 0,
    val lastForwardTime: Long? = null,
    val isBlocked: Boolean = false,
    val device: BluetoothDevice? = null  // For connection operations
) {
    /**
     * Convenience property for backward compatibility (returns connectionId)
     */
    val id: String
        get() = connectionId

    /**
     * Check if peer can be connected to
     */
    val canConnect: Boolean
        get() = senderId != null &&
                connectionState == PeerConnectionState.DISCOVERED &&
                !isBlocked

    /**
     * Convert to a map for sending to Flutter
     */
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "senderId" to senderId,
            "connectionId" to connectionId,
            "id" to connectionId,  // For backward compatibility
            "nickname" to nickname,
            "rssi" to rssi,
            "lastSeen" to lastSeen,
            "connectionState" to connectionState.name.lowercase(),
            "hopCount" to hopCount,
            "lastForwardTime" to lastForwardTime,
            "isBlocked" to isBlocked
        )
    }

    companion object {
        /**
         * Create a Peer from a BluetoothDevice
         */
        fun fromDevice(
            device: BluetoothDevice,
            rssi: Int = 0,
            senderId: String? = null
        ): Peer {
            return Peer(
                senderId = senderId,
                connectionId = device.address,
                nickname = device.name ?: "Unknown",
                rssi = rssi,
                device = device,
                connectionState = PeerConnectionState.DISCOVERED
            )
        }
    }
}

