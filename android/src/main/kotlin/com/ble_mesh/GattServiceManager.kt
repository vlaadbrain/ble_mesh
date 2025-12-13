package com.ble_mesh

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.util.Log
import java.util.UUID

/**
 * Manages GATT services and characteristics
 */
class GattServiceManager {
    private val tag = "GattServiceManager"

    // Client Characteristic Configuration Descriptor UUID
    private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    /**
     * Find the mesh service in a GATT connection
     */
    fun findMeshService(gatt: BluetoothGatt): android.bluetooth.BluetoothGattService? {
        return gatt.getService(BleConstants.MESH_SERVICE_UUID)
    }

    /**
     * Find MSG characteristic (bidirectional communication)
     */
    fun findMsgCharacteristic(gatt: BluetoothGatt): BluetoothGattCharacteristic? {
        val service = findMeshService(gatt) ?: return null
        return service.getCharacteristic(BleConstants.MSG_CHARACTERISTIC_UUID)
    }

    /**
     * Find control characteristic
     */
    fun findControlCharacteristic(gatt: BluetoothGatt): BluetoothGattCharacteristic? {
        val service = findMeshService(gatt) ?: return null
        return service.getCharacteristic(BleConstants.CONTROL_CHARACTERISTIC_UUID)
    }

    /**
     * Setup characteristic notifications
     */
    fun setupNotifications(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic
    ): Boolean {
        try {
            // Enable local notifications
            val success = gatt.setCharacteristicNotification(characteristic, true)
            if (!success) {
                Log.e(tag, "Failed to set characteristic notification")
                return false
            }

            // Write to CCCD to enable remote notifications
            val descriptor = characteristic.getDescriptor(CCCD_UUID)
            if (descriptor == null) {
                Log.e(tag, "CCCD descriptor not found")
                return false
            }

            descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            val writeSuccess = gatt.writeDescriptor(descriptor)

            if (writeSuccess) {
                Log.d(tag, "Enabled notifications for characteristic: ${characteristic.uuid}")
            } else {
                Log.e(tag, "Failed to write CCCD descriptor")
            }

            return writeSuccess

        } catch (e: SecurityException) {
            Log.e(tag, "Security exception setting up notifications", e)
            return false
        } catch (e: Exception) {
            Log.e(tag, "Exception setting up notifications", e)
            return false
        }
    }

    /**
     * Write data to a characteristic
     */
    fun writeCharacteristic(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        data: ByteArray
    ): Boolean {
        try {
            characteristic.value = data
            characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT

            val success = gatt.writeCharacteristic(characteristic)
            if (success) {
                Log.d(tag, "Writing ${data.size} bytes to characteristic: ${characteristic.uuid}")
            } else {
                Log.e(tag, "Failed to write characteristic: ${characteristic.uuid}")
            }

            return success

        } catch (e: SecurityException) {
            Log.e(tag, "Security exception writing characteristic", e)
            return false
        } catch (e: Exception) {
            Log.e(tag, "Exception writing characteristic", e)
            return false
        }
    }

    /**
     * Read data from a characteristic
     */
    fun readCharacteristic(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic
    ): Boolean {
        try {
            val success = gatt.readCharacteristic(characteristic)
            if (success) {
                Log.d(tag, "Reading characteristic: ${characteristic.uuid}")
            } else {
                Log.e(tag, "Failed to read characteristic: ${characteristic.uuid}")
            }

            return success

        } catch (e: SecurityException) {
            Log.e(tag, "Security exception reading characteristic", e)
            return false
        } catch (e: Exception) {
            Log.e(tag, "Exception reading characteristic", e)
            return false
        }
    }

    /**
     * Request MTU size
     */
    fun requestMtu(gatt: BluetoothGatt, mtuSize: Int = BleConstants.MTU_SIZE): Boolean {
        try {
            val success = gatt.requestMtu(mtuSize)
            if (success) {
                Log.d(tag, "Requesting MTU size: $mtuSize")
            } else {
                Log.e(tag, "Failed to request MTU")
            }

            return success

        } catch (e: SecurityException) {
            Log.e(tag, "Security exception requesting MTU", e)
            return false
        } catch (e: Exception) {
            Log.e(tag, "Exception requesting MTU", e)
            return false
        }
    }

    /**
     * Check if characteristic supports notifications
     */
    fun supportsNotifications(characteristic: BluetoothGattCharacteristic): Boolean {
        val properties = characteristic.properties
        return (properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
    }

    /**
     * Check if characteristic supports write
     */
    fun supportsWrite(characteristic: BluetoothGattCharacteristic): Boolean {
        val properties = characteristic.properties
        return (properties and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0 ||
                (properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0
    }

    /**
     * Check if characteristic supports read
     */
    fun supportsRead(characteristic: BluetoothGattCharacteristic): Boolean {
        val properties = characteristic.properties
        return (properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0
    }
}

