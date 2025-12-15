package com.ble_mesh.models

import java.util.UUID

/**
 * Type of message
 */
enum class MessageType(val value: Int) {
    PUBLIC(0),
    PRIVATE(1),
    CHANNEL(2),
    SYSTEM(3);

    companion object {
        fun fromInt(value: Int) = values().firstOrNull { it.value == value } ?: PUBLIC
    }
}

/**
 * Delivery status of a message
 */
enum class DeliveryStatus(val value: Int) {
    PENDING(0),
    SENT(1),
    DELIVERED(2),
    FAILED(3);

    companion object {
        fun fromInt(value: Int) = values().firstOrNull { it.value == value } ?: PENDING
    }
}

/**
 * Represents a message in the mesh network
 */
data class Message(
    val id: String = UUID.randomUUID().toString(),
    val senderId: String,
    val senderNickname: String,
    val content: String,
    val type: MessageType = MessageType.PUBLIC,
    val timestamp: Long = System.currentTimeMillis(),
    val channel: String? = null,
    val isEncrypted: Boolean = false,
    val status: DeliveryStatus = DeliveryStatus.PENDING,
    // Phase 2: Routing fields
    val ttl: Int = 7,              // Time-to-live (hops remaining)
    val hopCount: Int = 0,         // Number of hops taken
    val messageId: Long = MessageHeader.generateMessageId(),  // Unique message ID
    val isForwarded: Boolean = false  // Was this message forwarded?
) {
    companion object {
        /**
         * Parse message from byte array (header + payload)
         *
         * @param data Byte array containing header and payload
         * @return Message object or null if parsing fails
         */
        fun fromByteArray(data: ByteArray, senderNickname: String = "Unknown"): Message? {
            return try {
                // Parse header
                val header = MessageHeader.fromByteArray(data)

                // Extract payload
                val payloadBytes = data.copyOfRange(MessageHeader.HEADER_SIZE, data.size)
                val content = String(payloadBytes, Charsets.UTF_8)

                // Create message
                Message(
                    id = header.messageId.toString(),
                    senderId = header.senderId,
                    senderNickname = senderNickname,
                    content = content,
                    type = messageTypeFromHeaderType(header.type),
                    timestamp = System.currentTimeMillis(),
                    channel = null,
                    isEncrypted = false,
                    status = DeliveryStatus.DELIVERED,
                    ttl = header.ttl.toInt(),
                    hopCount = header.hopCount.toInt(),
                    messageId = header.messageId,
                    isForwarded = header.hopCount > 0
                )
            } catch (e: Exception) {
                android.util.Log.e("Message", "Failed to parse message from bytes", e)
                null
            }
        }

        /**
         * Convert MessageHeader type to MessageType
         */
        private fun messageTypeFromHeaderType(headerType: Byte): MessageType {
            return when (headerType) {
                MessageHeader.TYPE_PUBLIC -> MessageType.PUBLIC
                MessageHeader.TYPE_PRIVATE -> MessageType.PRIVATE
                MessageHeader.TYPE_CHANNEL -> MessageType.CHANNEL
                else -> MessageType.PUBLIC
            }
        }

        /**
         * Convert MessageType to MessageHeader type
         */
        private fun headerTypeFromMessageType(messageType: MessageType): Byte {
            return when (messageType) {
                MessageType.PUBLIC -> MessageHeader.TYPE_PUBLIC
                MessageType.PRIVATE -> MessageHeader.TYPE_PRIVATE
                MessageType.CHANNEL -> MessageHeader.TYPE_CHANNEL
                MessageType.SYSTEM -> MessageHeader.TYPE_PUBLIC
            }
        }
    }

    /**
     * Serialize message to byte array (header + payload)
     *
     * @return Byte array containing header and payload
     */
    fun toByteArray(): ByteArray {
        val payloadBytes = content.toByteArray(Charsets.UTF_8)

        val header = MessageHeader(
            type = headerTypeFromMessageType(type),
            ttl = ttl.toByte(),
            hopCount = hopCount.toByte(),
            messageId = messageId,
            senderId = senderId,
            payloadLength = payloadBytes.size.toShort()
        )

        val headerBytes = header.toByteArray()
        return headerBytes + payloadBytes
    }

    /**
     * Convert to a map for sending to Flutter
     */
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "senderId" to senderId,
            "senderNickname" to senderNickname,
            "content" to content,
            "type" to type.value,
            "timestamp" to timestamp,
            "channel" to channel,
            "isEncrypted" to isEncrypted,
            "status" to status.value,
            // Phase 2: Routing fields
            "ttl" to ttl,
            "hopCount" to hopCount,
            "messageId" to messageId.toString(),
            "isForwarded" to isForwarded
        )
    }
}

