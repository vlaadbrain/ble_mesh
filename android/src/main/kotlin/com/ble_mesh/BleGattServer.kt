package com.ble_mesh

import android.bluetooth.*
import android.content.Context
import android.util.Log
import java.util.UUID

/**
 * Manages the GATT server for providing mesh services to connected clients
 */
class BleGattServer(private val context: Context) {
    private val tag = "BleGattServer"

    private val bluetoothManager: BluetoothManager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

    private var gattServer: BluetoothGattServer? = null
    private val connectedDevices = mutableSetOf<BluetoothDevice>()

    // Callbacks
    var onCharacteristicWriteRequest: ((device: BluetoothDevice, data: ByteArray) -> Unit)? = null
    var onCharacteristicReadRequest: ((device: BluetoothDevice) -> ByteArray?)? = null
    var onDeviceConnected: ((device: BluetoothDevice) -> Unit)? = null
    var onDeviceDisconnected: ((device: BluetoothDevice) -> Unit)? = null

    /**
     * Start the GATT server
     */
    fun start(): Boolean {
        if (gattServer != null) {
            Log.d(tag, "GATT server already started")
            return true
        }

        try {
            gattServer = bluetoothManager.openGattServer(context, gattServerCallback)
            if (gattServer == null) {
                Log.e(tag, "Failed to open GATT server")
                return false
            }

            // Add mesh service
            val service = createMeshService()
            val added = gattServer?.addService(service) ?: false

            if (added) {
                Log.d(tag, "GATT server started successfully")
            } else {
                Log.e(tag, "Failed to add mesh service to GATT server")
                gattServer?.close()
                gattServer = null
            }

            return added
        } catch (e: SecurityException) {
            Log.e(tag, "Security exception starting GATT server", e)
            return false
        } catch (e: Exception) {
            Log.e(tag, "Exception starting GATT server", e)
            return false
        }
    }

    /**
     * Stop the GATT server
     */
    fun stop() {
        try {
            gattServer?.clearServices()
            gattServer?.close()
            gattServer = null
            connectedDevices.clear()
            Log.d(tag, "GATT server stopped")
        } catch (e: SecurityException) {
            Log.e(tag, "Security exception stopping GATT server", e)
        } catch (e: Exception) {
            Log.e(tag, "Exception stopping GATT server", e)
        }
    }

    /**
     * Send notification to a connected device
     */
    fun sendNotification(device: BluetoothDevice, data: ByteArray): Boolean {
        if (gattServer == null) {
            Log.e(tag, "GATT server not started")
            return false
        }

        try {
            val service = gattServer?.getService(BleConstants.MESH_SERVICE_UUID)
            val characteristic = service?.getCharacteristic(BleConstants.MSG_CHARACTERISTIC_UUID)

            if (characteristic == null) {
                Log.e(tag, "MSG characteristic not found")
                return false
            }

            characteristic.value = data
            val success = gattServer?.notifyCharacteristicChanged(device, characteristic, false) ?: false

            if (success) {
                Log.d(tag, "Sent notification to device: ${device.address}, size: ${data.size} bytes")
            } else {
                Log.e(tag, "Failed to send notification to device: ${device.address}")
            }

            return success
        } catch (e: SecurityException) {
            Log.e(tag, "Security exception sending notification", e)
            return false
        } catch (e: Exception) {
            Log.e(tag, "Exception sending notification", e)
            return false
        }
    }

    /**
     * Get list of connected devices
     */
    fun getConnectedDevices(): List<BluetoothDevice> {
        return connectedDevices.toList()
    }

    /**
     * Create the mesh service with MSG characteristic for bidirectional communication
     */
    private fun createMeshService(): BluetoothGattService {
        val service = BluetoothGattService(
            BleConstants.MESH_SERVICE_UUID,
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )

        // MSG Characteristic (bidirectional: clients write to send, subscribe to receive)
        val msgCharacteristic = BluetoothGattCharacteristic(
            BleConstants.MSG_CHARACTERISTIC_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or
            BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or
            BluetoothGattCharacteristic.PROPERTY_READ or
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_WRITE or
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        // Add CCCD descriptor for notifications
        val cccdDescriptor = BluetoothGattDescriptor(
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"), // Standard CCCD UUID
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        msgCharacteristic.addDescriptor(cccdDescriptor)
        service.addCharacteristic(msgCharacteristic)

        // Control Characteristic (optional, for future use)
        val controlCharacteristic = BluetoothGattCharacteristic(
            BleConstants.CONTROL_CHARACTERISTIC_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        service.addCharacteristic(controlCharacteristic)

        Log.d(tag, "Created mesh service with MSG and Control characteristics")
        return service
    }

    /**
     * GATT server callback
     */
    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            super.onConnectionStateChange(device, status, newState)

            try {
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        connectedDevices.add(device)
                        Log.d(tag, "Device connected to GATT server: ${device.address}")
                        onDeviceConnected?.invoke(device)
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        connectedDevices.remove(device)
                        Log.d(tag, "Device disconnected from GATT server: ${device.address}")
                        onDeviceDisconnected?.invoke(device)
                    }
                }
            } catch (e: SecurityException) {
                Log.e(tag, "Security exception in connection state change", e)
            }
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic
        ) {
            super.onCharacteristicReadRequest(device, requestId, offset, characteristic)

            try {
                Log.d(tag, "Characteristic read request from ${device.address}: ${characteristic.uuid}")

                val data = onCharacteristicReadRequest?.invoke(device)

                if (data != null && offset < data.size) {
                    val responseData = data.copyOfRange(offset, data.size)
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        responseData
                    )
                } else {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        byteArrayOf()
                    )
                }
            } catch (e: SecurityException) {
                Log.e(tag, "Security exception in read request", e)
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
            } catch (e: Exception) {
                Log.e(tag, "Exception in read request", e)
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)

            try {
                Log.d(tag, "Characteristic write request from ${device.address}: ${characteristic.uuid}, size: ${value?.size ?: 0} bytes")

                if (characteristic.uuid == BleConstants.MSG_CHARACTERISTIC_UUID && value != null) {
                    onCharacteristicWriteRequest?.invoke(device, value)
                }

                if (responseNeeded) {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        value
                    )
                }
            } catch (e: SecurityException) {
                Log.e(tag, "Security exception in write request", e)
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
                }
            } catch (e: Exception) {
                Log.e(tag, "Exception in write request", e)
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
                }
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value)

            try {
                Log.d(tag, "Descriptor write request from ${device.address}: ${descriptor.uuid}")

                // Handle CCCD (notification enable/disable)
                if (descriptor.uuid.toString() == "00002902-0000-1000-8000-00805f9b34fb") {
                    val enabled = value?.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE) == true
                    Log.d(tag, "Notifications ${if (enabled) "enabled" else "disabled"} for device: ${device.address}")
                }

                if (responseNeeded) {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        value
                    )
                }
            } catch (e: SecurityException) {
                Log.e(tag, "Security exception in descriptor write", e)
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
                }
            } catch (e: Exception) {
                Log.e(tag, "Exception in descriptor write", e)
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
                }
            }
        }

        override fun onDescriptorReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            descriptor: BluetoothGattDescriptor
        ) {
            super.onDescriptorReadRequest(device, requestId, offset, descriptor)

            try {
                Log.d(tag, "Descriptor read request from ${device.address}: ${descriptor.uuid}")

                gattServer?.sendResponse(
                    device,
                    requestId,
                    BluetoothGatt.GATT_SUCCESS,
                    offset,
                    byteArrayOf()
                )
            } catch (e: SecurityException) {
                Log.e(tag, "Security exception in descriptor read", e)
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
            } catch (e: Exception) {
                Log.e(tag, "Exception in descriptor read", e)
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
            }
        }
    }

    /**
     * Clean up resources
     */
    fun cleanup() {
        stop()
        onCharacteristicWriteRequest = null
        onCharacteristicReadRequest = null
        onDeviceConnected = null
        onDeviceDisconnected = null
    }
}

