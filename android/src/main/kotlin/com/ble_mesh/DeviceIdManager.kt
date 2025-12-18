package com.ble_mesh

import android.content.Context
import android.content.SharedPreferences
import java.util.UUID

/**
 * Manages persistent device identity for BLE mesh networking
 *
 * Generates and stores a stable UUID-based device identifier that persists
 * across app restarts. This replaces the unreliable MAC address-based
 * identification system.
 *
 * Device ID Format:
 * - Full ID: UUID v4 (128-bit), e.g., "550e8400-e29b-41d4-a716-446655440000"
 * - Compact ID: First 6 bytes (48-bit), e.g., [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
 * - String format: "55:0E:84:00:E2:9B" (for display/logging)
 */
class DeviceIdManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(
        PREFS_NAME,
        Context.MODE_PRIVATE
    )

    companion object {
        private const val PREFS_NAME = "ble_mesh_device_id"
        private const val KEY_DEVICE_ID = "device_id"

        /**
         * Convert UUID string to compact 6-byte representation
         *
         * Takes the first 12 hex characters (after removing hyphens) and converts
         * them to a 6-byte array.
         *
         * Example:
         * - Input: "550e8400-e29b-41d4-a716-446655440000"
         * - Output: [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
         */
        fun compactIdFromUuid(uuid: String): ByteArray {
            // Remove hyphens and take first 12 hex chars (6 bytes)
            val hex = uuid.replace("-", "")
            if (hex.length < 12) {
                throw IllegalArgumentException("Invalid UUID format: $uuid")
            }

            val compactHex = hex.substring(0, 12)
            return compactHex.chunked(2)
                .map { it.toInt(16).toByte() }
                .toByteArray()
        }

        /**
         * Convert compact ID bytes to string format
         *
         * Example:
         * - Input: [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
         * - Output: "55:0E:84:00:E2:9B"
         */
        fun compactIdToString(bytes: ByteArray): String {
            if (bytes.size != 6) {
                throw IllegalArgumentException("Compact ID must be exactly 6 bytes, got ${bytes.size}")
            }

            return bytes.joinToString(":") { byte ->
                String.format("%02X", byte)
            }
        }

        /**
         * Convert compact ID string to bytes
         *
         * Example:
         * - Input: "55:0E:84:00:E2:9B"
         * - Output: [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
         */
        fun compactIdStringToBytes(compactId: String): ByteArray {
            val parts = compactId.split(":", "-")
            if (parts.size != 6) {
                throw IllegalArgumentException("Invalid compact ID format: $compactId (expected XX:XX:XX:XX:XX:XX)")
            }
            return parts.map { it.toInt(16).toByte() }.toByteArray()
        }
    }

    /**
     * Get or create the device UUID
     *
     * On first call, generates a new UUID v4 and stores it persistently.
     * Subsequent calls return the stored UUID.
     *
     * @return UUID string in format "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
     */
    fun getOrCreateDeviceId(): String {
        val existing = prefs.getString(KEY_DEVICE_ID, null)
        if (!existing.isNullOrEmpty()) {
            return existing
        }

        // Generate new UUID v4
        val newId = UUID.randomUUID().toString()
        prefs.edit().putString(KEY_DEVICE_ID, newId).apply()
        return newId
    }

    /**
     * Get the compact device ID (first 6 bytes of UUID)
     *
     * This is used in the MessageHeader senderId field for efficient
     * binary serialization.
     *
     * @return 6-byte ByteArray
     */
    fun getCompactId(): ByteArray {
        val uuid = getOrCreateDeviceId()
        return compactIdFromUuid(uuid)
    }

    /**
     * Get the compact device ID as a formatted string
     *
     * @return String in format "XX:XX:XX:XX:XX:XX" (e.g., "55:0E:84:00:E2:9B")
     */
    fun getCompactIdString(): String {
        val bytes = getCompactId()
        return compactIdToString(bytes)
    }

    /**
     * Reset the device ID (for testing or user-initiated reset)
     *
     * Deletes the stored UUID. Next call to getOrCreateDeviceId() will
     * generate a new UUID.
     */
    fun resetDeviceId() {
        prefs.edit().remove(KEY_DEVICE_ID).apply()
    }

    /**
     * Check if a device ID exists
     */
    fun hasDeviceId(): Boolean {
        val existing = prefs.getString(KEY_DEVICE_ID, null)
        return !existing.isNullOrEmpty()
    }
}

