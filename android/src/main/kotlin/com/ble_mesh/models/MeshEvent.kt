package com.ble_mesh.models

/**
 * Type of mesh event
 */
enum class MeshEventType(val value: Int) {
    MESH_STARTED(0),
    MESH_STOPPED(1),
    PEER_DISCOVERED(2),
    PEER_CONNECTED(3),
    PEER_DISCONNECTED(4),
    MESSAGE_RECEIVED(5),
    ERROR(6);

    companion object {
        fun fromInt(value: Int) = values().firstOrNull { it.value == value } ?: ERROR
    }
}

/**
 * Represents an event in the mesh network
 */
data class MeshEvent(
    val type: MeshEventType,
    val message: String? = null,
    val data: Map<String, Any>? = null
) {
    /**
     * Convert to a map for sending to Flutter
     */
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "type" to type.value,
            "message" to message,
            "data" to data
        )
    }
}

