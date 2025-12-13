package com.ble_mesh

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Manages GATT connections to peer devices
 */
class BleConnectionManager(private val context: Context) {
    private val tag = "BleConnectionManager"

    // Map of device address to GATT connection
    private val gattConnections = ConcurrentHashMap<String, BluetoothGatt>()

    // Map of device address to connection state
    private val connectionStates = ConcurrentHashMap<String, Int>()

    private val handler = Handler(Looper.getMainLooper())

    // Callbacks
    var onDeviceConnected: ((String, BluetoothGatt) -> Unit)? = null
    var onDeviceDisconnected: ((String) -> Unit)? = null
    var onServicesDiscovered: ((String, BluetoothGatt) -> Unit)? = null
    var onCharacteristicRead: ((String, UUID, ByteArray) -> Unit)? = null
    var onCharacteristicWrite: ((String, UUID) -> Unit)? = null
    var onCharacteristicChanged: ((String, UUID, ByteArray) -> Unit)? = null
    var onConnectionError: ((String, String) -> Unit)? = null

    /**
     * Connect to a device
     */
    fun connectToDevice(device: BluetoothDevice) {
        val address = device.address

        // Check if already connected or connecting
        val currentState = connectionStates[address] ?: BluetoothProfile.STATE_DISCONNECTED
        if (currentState == BluetoothProfile.STATE_CONNECTED ||
            currentState == BluetoothProfile.STATE_CONNECTING) {
            Log.d(tag, "Device $address already connected or connecting")
            return
        }

        // Check max connections
        if (gattConnections.size >= BleConstants.MAX_CONNECTIONS) {
            Log.w(tag, "Max connections reached, cannot connect to $address")
            onConnectionError?.invoke(address, "Max connections reached")
            return
        }

        try {
            Log.d(tag, "Connecting to device: $address")
            connectionStates[address] = BluetoothProfile.STATE_CONNECTING

            val gatt = device.connectGatt(
                context,
                false, // autoConnect = false for faster connection
                createGattCallback(address),
                BluetoothDevice.TRANSPORT_LE
            )

            gattConnections[address] = gatt

            // Set connection timeout
            handler.postDelayed({
                if (connectionStates[address] == BluetoothProfile.STATE_CONNECTING) {
                    Log.w(tag, "Connection timeout for device: $address")
                    disconnectDevice(address)
                    onConnectionError?.invoke(address, "Connection timeout")
                }
            }, BleConstants.CONNECTION_TIMEOUT_MS)

        } catch (e: SecurityException) {
            Log.e(tag, "Security exception connecting to device: $address", e)
            connectionStates.remove(address)
            onConnectionError?.invoke(address, "Security exception: ${e.message}")
        } catch (e: Exception) {
            Log.e(tag, "Exception connecting to device: $address", e)
            connectionStates.remove(address)
            onConnectionError?.invoke(address, "Exception: ${e.message}")
        }
    }

    /**
     * Disconnect from a device
     */
    fun disconnectDevice(address: String) {
        try {
            val gatt = gattConnections[address]
            if (gatt != null) {
                Log.d(tag, "Disconnecting device: $address")
                gatt.disconnect()
                // Don't close immediately, wait for callback
            } else {
                Log.d(tag, "Device $address not connected")
            }
        } catch (e: SecurityException) {
            Log.e(tag, "Security exception disconnecting device: $address", e)
        } catch (e: Exception) {
            Log.e(tag, "Exception disconnecting device: $address", e)
        }
    }

    /**
     * Close GATT connection
     */
    private fun closeGatt(address: String) {
        try {
            val gatt = gattConnections.remove(address)
            gatt?.close()
            connectionStates.remove(address)
            Log.d(tag, "Closed GATT for device: $address")
        } catch (e: Exception) {
            Log.e(tag, "Exception closing GATT for device: $address", e)
        }
    }

    /**
     * Get GATT connection for a device
     */
    fun getGatt(address: String): BluetoothGatt? {
        return gattConnections[address]
    }

    /**
     * Check if device is connected
     */
    fun isConnected(address: String): Boolean {
        return connectionStates[address] == BluetoothProfile.STATE_CONNECTED
    }

    /**
     * Get all connected device addresses
     */
    fun getConnectedDevices(): List<String> {
        return connectionStates.filter { it.value == BluetoothProfile.STATE_CONNECTED }
            .map { it.key }
    }

    /**
     * Disconnect all devices
     */
    fun disconnectAll() {
        val addresses = gattConnections.keys.toList()
        addresses.forEach { disconnectDevice(it) }
    }

    /**
     * Clean up resources
     */
    fun cleanup() {
        handler.removeCallbacksAndMessages(null)
        disconnectAll()

        // Close all GATT connections
        gattConnections.keys.toList().forEach { closeGatt(it) }

        onDeviceConnected = null
        onDeviceDisconnected = null
        onServicesDiscovered = null
        onCharacteristicRead = null
        onCharacteristicWrite = null
        onCharacteristicChanged = null
        onConnectionError = null
    }

    /**
     * Create GATT callback for a device
     */
    private fun createGattCallback(expectedAddress: String): BluetoothGattCallback {
        return object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                super.onConnectionStateChange(gatt, status, newState)

                // IMPORTANT: Always use the actual device address from the GATT connection
                // not the closure variable, to avoid device address mismatches
                val actualAddress = gatt.device.address

                // Log if there's a mismatch (shouldn't happen, but good for debugging)
                if (actualAddress != expectedAddress) {
                    Log.w(tag, "Address mismatch! Expected: $expectedAddress, Actual: $actualAddress")
                }

                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        Log.d(tag, "Device connected: $actualAddress")
                        connectionStates[actualAddress] = BluetoothProfile.STATE_CONNECTED

                        // Refresh GATT cache to prevent stale service/characteristic data
                        refreshGattCache(gatt)

                        // Discover services
                        try {
                            handler.postDelayed({
                                gatt.discoverServices()
                            }, 600) // Small delay before service discovery
                        } catch (e: SecurityException) {
                            Log.e(tag, "Security exception discovering services", e)
                            onConnectionError?.invoke(actualAddress, "Security exception")
                        }

                        onDeviceConnected?.invoke(actualAddress, gatt)
                    }

                    BluetoothProfile.STATE_DISCONNECTED -> {
                        Log.d(tag, "Device disconnected: $actualAddress, status: $status")
                        connectionStates[actualAddress] = BluetoothProfile.STATE_DISCONNECTED

                        onDeviceDisconnected?.invoke(actualAddress)

                        // Close and cleanup
                        closeGatt(actualAddress)

                        if (status != BluetoothGatt.GATT_SUCCESS) {
                            onConnectionError?.invoke(actualAddress, "Disconnected with status: $status")
                        }
                    }
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                super.onServicesDiscovered(gatt, status)

                val actualAddress = gatt.device.address

                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(tag, "Services discovered for device: $actualAddress")

                    // Log all discovered services and characteristics for debugging
                    gatt.services?.forEach { service ->
                        Log.d(tag, "  Service: ${service.uuid}")
                        service.characteristics?.forEach { char ->
                            Log.d(tag, "    Characteristic: ${char.uuid}")
                        }
                    }

                    onServicesDiscovered?.invoke(actualAddress, gatt)
                } else {
                    Log.e(tag, "Service discovery failed for device: $actualAddress, status: $status")
                    onConnectionError?.invoke(actualAddress, "Service discovery failed")
                }
            }

            override fun onCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int
            ) {
                super.onCharacteristicRead(gatt, characteristic, status)

                val actualAddress = gatt.device.address

                if (status == BluetoothGatt.GATT_SUCCESS) {
                    val data = characteristic.value
                    Log.d(tag, "Characteristic read from $actualAddress: ${characteristic.uuid}, size: ${data?.size ?: 0}")
                    if (data != null) {
                        onCharacteristicRead?.invoke(actualAddress, characteristic.uuid, data)
                    }
                } else {
                    Log.e(tag, "Characteristic read failed from $actualAddress: ${characteristic.uuid}, status: $status")
                }
            }

            override fun onCharacteristicWrite(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int
            ) {
                super.onCharacteristicWrite(gatt, characteristic, status)

                val actualAddress = gatt.device.address

                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(tag, "Characteristic write success to $actualAddress: ${characteristic.uuid}")
                    onCharacteristicWrite?.invoke(actualAddress, characteristic.uuid)
                } else {
                    Log.e(tag, "Characteristic write failed to $actualAddress: ${characteristic.uuid}, status: $status")
                }
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic
            ) {
                super.onCharacteristicChanged(gatt, characteristic)

                val actualAddress = gatt.device.address
                val data = characteristic.value

                Log.d(tag, "Characteristic changed from $actualAddress: ${characteristic.uuid}, size: ${data?.size ?: 0}")
                if (data != null) {
                    onCharacteristicChanged?.invoke(actualAddress, characteristic.uuid, data)
                }
            }

            override fun onDescriptorWrite(
                gatt: BluetoothGatt,
                descriptor: BluetoothGattDescriptor,
                status: Int
            ) {
                super.onDescriptorWrite(gatt, descriptor, status)

                val actualAddress = gatt.device.address

                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(tag, "Descriptor write success for $actualAddress: ${descriptor.uuid}")
                } else {
                    Log.e(tag, "Descriptor write failed for $actualAddress: ${descriptor.uuid}, status: $status")
                }
            }
        }
    }

    /**
     * Refresh GATT cache to force fresh service discovery
     * This uses reflection to call the hidden refresh() method
     */
    private fun refreshGattCache(gatt: BluetoothGatt): Boolean {
        try {
            val refreshMethod = gatt.javaClass.getMethod("refresh")
            val success = refreshMethod.invoke(gatt) as? Boolean ?: false
            if (success) {
                Log.d(tag, "GATT cache refreshed for device: ${gatt.device.address}")
            } else {
                Log.w(tag, "Failed to refresh GATT cache for device: ${gatt.device.address}")
            }
            return success
        } catch (e: Exception) {
            Log.w(tag, "Could not refresh GATT cache (reflection failed): ${e.message}")
            return false
        }
    }
}

