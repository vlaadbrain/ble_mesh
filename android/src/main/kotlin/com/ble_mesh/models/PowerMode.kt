package com.ble_mesh.models

/**
 * Power mode for battery optimization
 */
enum class PowerMode(val value: Int) {
    PERFORMANCE(0),
    BALANCED(1),
    POWER_SAVER(2),
    ULTRA_LOW_POWER(3);

    companion object {
        fun fromInt(value: Int) = values().firstOrNull { it.value == value } ?: BALANCED
    }
}

