package com.ble_mesh

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log

/**
 * Handles BLE advertising to make device discoverable
 */
class BleAdvertiser(private val context: Context) {
    private val tag = "BleAdvertiser"

    private val bluetoothManager: BluetoothManager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
    private val bluetoothLeAdvertiser: BluetoothLeAdvertiser? = bluetoothAdapter?.bluetoothLeAdvertiser

    private var isAdvertising = false
    private var advertiseCallback: AdvertiseCallback? = null

    // Callback for advertising events
    var onAdvertisingStarted: (() -> Unit)? = null
    var onAdvertisingFailed: ((Int, String) -> Unit)? = null

    /**
     * Start BLE advertising
     */
    fun startAdvertising(deviceName: String = "BleMesh") {
        if (isAdvertising) {
            Log.d(tag, "Already advertising")
            return
        }

        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            Log.e(tag, "Bluetooth is not available or not enabled")
            onAdvertisingFailed?.invoke(-1, "Bluetooth is not available or not enabled")
            return
        }

        if (bluetoothLeAdvertiser == null) {
            Log.e(tag, "BLE advertiser is not available")
            onAdvertisingFailed?.invoke(-1, "BLE advertiser is not available")
            return
        }

        // Set device name
        try {
            bluetoothAdapter.name = deviceName
        } catch (e: SecurityException) {
            Log.w(tag, "Cannot set device name: ${e.message}")
        }

        // Create advertise settings
        val advertiseSettings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0) // Advertise indefinitely
            .build()

        // Create advertise data
        val advertiseData = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(ParcelUuid(BleConstants.MESH_SERVICE_UUID))
            .build()

        // Create scan response data
        val scanResponseData = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .build()

        // Create advertise callback
        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                super.onStartSuccess(settingsInEffect)
                isAdvertising = true
                Log.d(tag, "Started BLE advertising")
                onAdvertisingStarted?.invoke()
            }

            override fun onStartFailure(errorCode: Int) {
                super.onStartFailure(errorCode)
                isAdvertising = false
                val errorMessage = when (errorCode) {
                    ADVERTISE_FAILED_DATA_TOO_LARGE -> "Data too large"
                    ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Too many advertisers"
                    ADVERTISE_FAILED_ALREADY_STARTED -> "Already started"
                    ADVERTISE_FAILED_INTERNAL_ERROR -> "Internal error"
                    ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "Feature unsupported"
                    else -> "Unknown error: $errorCode"
                }
                Log.e(tag, "Advertising failed: $errorMessage")
                onAdvertisingFailed?.invoke(errorCode, errorMessage)
            }
        }

        try {
            bluetoothLeAdvertiser.startAdvertising(
                advertiseSettings,
                advertiseData,
                scanResponseData,
                advertiseCallback
            )
        } catch (e: SecurityException) {
            Log.e(tag, "Security exception while starting advertising", e)
            onAdvertisingFailed?.invoke(-1, "Security exception: ${e.message}")
        } catch (e: Exception) {
            Log.e(tag, "Exception while starting advertising", e)
            onAdvertisingFailed?.invoke(-1, "Exception: ${e.message}")
        }
    }

    /**
     * Stop BLE advertising
     */
    fun stopAdvertising() {
        if (!isAdvertising) {
            return
        }

        try {
            advertiseCallback?.let {
                bluetoothLeAdvertiser?.stopAdvertising(it)
                Log.d(tag, "Stopped BLE advertising")
            }
        } catch (e: SecurityException) {
            Log.e(tag, "Security exception while stopping advertising", e)
        } catch (e: Exception) {
            Log.e(tag, "Exception while stopping advertising", e)
        } finally {
            isAdvertising = false
            advertiseCallback = null
        }
    }

    /**
     * Check if currently advertising
     */
    fun isAdvertising(): Boolean = isAdvertising

    /**
     * Clean up resources
     */
    fun cleanup() {
        stopAdvertising()
        onAdvertisingStarted = null
        onAdvertisingFailed = null
    }
}

