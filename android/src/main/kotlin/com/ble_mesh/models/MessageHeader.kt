package com.ble_mesh.models

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID

/**
 * Message header for Phase 2 routing
 *
 * Binary format (20 bytes total):
 * - Version (1 byte): Protocol version (0x01)
 * - Type (1 byte): Message type
 * - TTL (1 byte): Time-to-live (hops remaining)
 * - Hop Count (1 byte): Number of hops taken
 * - Message ID (8 bytes): Unique message identifier
 * - Sender ID (6 bytes): Compact device UUID (first 6 bytes of device UUID)
 * - Payload Length (2 bytes): Length of payload data
 */
data class MessageHeader(
    val version: Byte = PROTOCOL_VERSION,
    val type: Byte,
    var ttl: Byte,
    var hopCount: Byte,
    val messageId: Long,
    val senderId: String,  // Compact device ID as string (e.g., "55:0E:84:00:E2:9B")
    val payloadLength: Short
) {
    companion object {
        const val PROTOCOL_VERSION: Byte = 0x01
        const val HEADER_SIZE = 20  // bytes

        // Message type constants (matching MessageType enum)
        const val TYPE_PUBLIC: Byte = 0x01
        const val TYPE_PRIVATE: Byte = 0x02
        const val TYPE_CHANNEL: Byte = 0x03
        const val TYPE_PEER_ANNOUNCEMENT: Byte = 0x04
        const val TYPE_ACKNOWLEDGMENT: Byte = 0x05
        const val TYPE_KEY_EXCHANGE: Byte = 0x06
        const val TYPE_STORE_FORWARD: Byte = 0x07
        const val TYPE_ROUTING_UPDATE: Byte = 0x08

        /**
         * Generate a unique message ID using timestamp + random
         */
        fun generateMessageId(): Long {
            val timestamp = System.currentTimeMillis()
            val random = (Math.random() * Int.MAX_VALUE).toLong()
            return (timestamp shl 32) or (random and 0xFFFFFFFFL)
        }

        /**
         * Deserialize header from byte array
         *
         * @param data Byte array containing the header (must be at least HEADER_SIZE bytes)
         * @return MessageHeader object
         * @throws IllegalArgumentException if data is too small or invalid
         */
        fun fromByteArray(data: ByteArray): MessageHeader {
            if (data.size < HEADER_SIZE) {
                throw IllegalArgumentException("Data too small for header: ${data.size} < $HEADER_SIZE")
            }

            val buffer = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN)

            // Parse fields
            val version = buffer.get()
            val type = buffer.get()
            val ttl = buffer.get()
            val hopCount = buffer.get()
            val messageId = buffer.getLong()

            // Parse sender ID (6 bytes compact device ID)
            val senderIdBytes = ByteArray(6)
            buffer.get(senderIdBytes)
            val senderId = compactIdToString(senderIdBytes)

            val payloadLength = buffer.getShort()

            // Validate version
            if (version != PROTOCOL_VERSION) {
                throw IllegalArgumentException("Unsupported protocol version: $version")
            }

            return MessageHeader(
                version = version,
                type = type,
                ttl = ttl,
                hopCount = hopCount,
                messageId = messageId,
                senderId = senderId,
                payloadLength = payloadLength
            )
        }

        /**
         * Convert compact device ID bytes to string format
         * Example: [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b] -> "55:0E:84:00:E2:9B"
         */
        private fun compactIdToString(bytes: ByteArray): String {
            return bytes.joinToString(":") { byte ->
                String.format("%02X", byte)
            }
        }

        /**
         * Convert compact device ID string to bytes
         * Example: "55:0E:84:00:E2:9B" -> [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
         */
        private fun compactIdStringToBytes(compactId: String): ByteArray {
            val parts = compactId.split(":", "-")
            if (parts.size != 6) {
                throw IllegalArgumentException("Invalid compact ID format: $compactId")
            }
            return parts.map { it.toInt(16).toByte() }.toByteArray()
        }
    }

    /**
     * Serialize header to byte array
     *
     * @return Byte array of size HEADER_SIZE (20 bytes)
     */
    fun toByteArray(): ByteArray {
        val buffer = ByteBuffer.allocate(HEADER_SIZE).order(ByteOrder.BIG_ENDIAN)

        // Write fields in order
        buffer.put(version)
        buffer.put(type)
        buffer.put(ttl)
        buffer.put(hopCount)
        buffer.putLong(messageId)

        // Write sender ID (6 bytes compact device ID)
        val senderIdBytes = compactIdStringToBytes(senderId)
        buffer.put(senderIdBytes)

        buffer.putShort(payloadLength)

        return buffer.array()
    }

    /**
     * Convert to map for debugging/logging
     */
    fun toMap(): Map<String, Any> {
        return mapOf(
            "version" to version.toInt(),
            "type" to type.toInt(),
            "ttl" to ttl.toInt(),
            "hopCount" to hopCount.toInt(),
            "messageId" to messageId.toString(),
            "senderId" to senderId,
            "payloadLength" to payloadLength.toInt()
        )
    }

    /**
     * Check if message should be forwarded
     * Message can be forwarded if TTL > 1 (will be > 0 after decrement)
     */
    fun canForward(): Boolean {
        return ttl > 1
    }

    /**
     * Decrement TTL and increment hop count for forwarding
     * Should be called before forwarding message to next hop
     */
    fun prepareForForward() {
        if (ttl > 0) {
            ttl = (ttl - 1).toByte()
        }
        hopCount = (hopCount + 1).toByte()
    }

    /**
     * Get message type as string for logging
     */
    fun getTypeString(): String {
        return when (type) {
            TYPE_PUBLIC -> "PUBLIC"
            TYPE_PRIVATE -> "PRIVATE"
            TYPE_CHANNEL -> "CHANNEL"
            TYPE_PEER_ANNOUNCEMENT -> "PEER_ANNOUNCEMENT"
            TYPE_ACKNOWLEDGMENT -> "ACKNOWLEDGMENT"
            TYPE_KEY_EXCHANGE -> "KEY_EXCHANGE"
            TYPE_STORE_FORWARD -> "STORE_FORWARD"
            TYPE_ROUTING_UPDATE -> "ROUTING_UPDATE"
            else -> "UNKNOWN($type)"
        }
    }

    override fun toString(): String {
        return "MessageHeader(version=$version, type=${getTypeString()}, ttl=$ttl, " +
               "hopCount=$hopCount, messageId=$messageId, senderId=$senderId, " +
               "payloadLength=$payloadLength)"
    }
}

