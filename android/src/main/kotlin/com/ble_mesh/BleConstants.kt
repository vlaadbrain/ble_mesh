package com.ble_mesh

import java.util.UUID

/**
 * Constants for BLE mesh networking
 */
object BleConstants {
    // Service UUID for BLE mesh
    val MESH_SERVICE_UUID: UUID = UUID.fromString("00001234-0000-1000-8000-00805f9b34fb")

    // Characteristic UUIDs
    val MSG_CHARACTERISTIC_UUID: UUID = UUID.fromString("00001235-0000-1000-8000-00805f9b34fb")
    val CONTROL_CHARACTERISTIC_UUID: UUID = UUID.fromString("00001237-0000-1000-8000-00805f9b34fb")

    // Scan settings
    const val SCAN_PERIOD_MS = 10000L // 10 seconds
    const val SCAN_INTERVAL_BALANCED_MS = 5000L // 5 seconds between scans
    const val SCAN_INTERVAL_POWER_SAVER_MS = 15000L // 15 seconds between scans

    // Connection settings
    const val MAX_CONNECTIONS = 7
    const val CONNECTION_TIMEOUT_MS = 30000L // 30 seconds

    // Message settings
    const val MAX_MESSAGE_SIZE = 512 // bytes
    const val MTU_SIZE = 512 // Maximum Transmission Unit
}

