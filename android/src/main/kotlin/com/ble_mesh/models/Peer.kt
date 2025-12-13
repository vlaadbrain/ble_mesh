package com.ble_mesh.models

import android.bluetooth.BluetoothDevice

/**
 * Represents a peer in the BLE mesh network
 */
data class Peer(
    val id: String,
    val nickname: String,
    val rssi: Int = 0,
    val lastSeen: Long = System.currentTimeMillis(),
    val isConnected: Boolean = false,
    val hopCount: Int = 0,
    val device: BluetoothDevice? = null
) {
    /**
     * Convert to a map for sending to Flutter
     */
    fun toMap(): Map<String, Any> {
        return mapOf(
            "id" to id,
            "nickname" to nickname,
            "rssi" to rssi,
            "lastSeen" to lastSeen,
            "isConnected" to isConnected,
            "hopCount" to hopCount
        )
    }

    companion object {
        /**
         * Create a Peer from a BluetoothDevice
         */
        fun fromDevice(device: BluetoothDevice, rssi: Int = 0): Peer {
            return Peer(
                id = device.address,
                nickname = device.name ?: "Unknown",
                rssi = rssi,
                device = device
            )
        }
    }
}

