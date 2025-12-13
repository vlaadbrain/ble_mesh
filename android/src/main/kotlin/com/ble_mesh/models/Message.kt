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
    val status: DeliveryStatus = DeliveryStatus.PENDING
) {
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
            "status" to status.value
        )
    }
}

