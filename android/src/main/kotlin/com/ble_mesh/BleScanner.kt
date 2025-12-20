package com.ble_mesh

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import com.ble_mesh.models.Peer

/**
 * Handles BLE scanning for nearby mesh devices
 */
class BleScanner(private val context: Context) {
    private val tag = "BleScanner"

    private val bluetoothManager: BluetoothManager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
    private val bluetoothLeScanner: BluetoothLeScanner? = bluetoothAdapter?.bluetoothLeScanner

    private val handler = Handler(Looper.getMainLooper())
    private var isScanning = false
    private var scanCallback: ScanCallback? = null

    // Callback for scan results
    var onDeviceDiscovered: ((Peer) -> Unit)? = null
    var onScanError: ((Int, String) -> Unit)? = null

    /**
     * Start scanning for BLE mesh devices
     */
    fun startScanning() {
        if (isScanning) {
            Log.d(tag, "Already scanning")
            return
        }

        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            Log.e(tag, "Bluetooth is not available or not enabled")
            onScanError?.invoke(-1, "Bluetooth is not available or not enabled")
            return
        }

        if (bluetoothLeScanner == null) {
            Log.e(tag, "BLE scanner is not available")
            onScanError?.invoke(-1, "BLE scanner is not available")
            return
        }

        // Create scan filters to only find mesh devices
        val scanFilters = listOf(
            ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(BleConstants.MESH_SERVICE_UUID))
                .build()
        )

        // Create scan settings
        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
            .setMatchMode(ScanSettings.MATCH_MODE_AGGRESSIVE)
            .setNumOfMatches(ScanSettings.MATCH_NUM_MAX_ADVERTISEMENT)
            .setReportDelay(0)
            .build()

        // Create scan callback
        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                super.onScanResult(callbackType, result)
                handleScanResult(result)
            }

            override fun onBatchScanResults(results: List<ScanResult>) {
                super.onBatchScanResults(results)
                results.forEach { handleScanResult(it) }
            }

            override fun onScanFailed(errorCode: Int) {
                super.onScanFailed(errorCode)
                Log.e(tag, "Scan failed with error code: $errorCode")
                isScanning = false
                onScanError?.invoke(errorCode, "Scan failed with error code: $errorCode")
            }
        }

        try {
            bluetoothLeScanner.startScan(scanFilters, scanSettings, scanCallback)
            isScanning = true
            Log.d(tag, "Started BLE scanning")

            // Schedule scan stop after SCAN_PERIOD_MS
            handler.postDelayed({
                stopScanning()
            }, BleConstants.SCAN_PERIOD_MS)
        } catch (e: SecurityException) {
            Log.e(tag, "Security exception while starting scan", e)
            onScanError?.invoke(-1, "Security exception: ${e.message}")
        } catch (e: Exception) {
            Log.e(tag, "Exception while starting scan", e)
            onScanError?.invoke(-1, "Exception: ${e.message}")
        }
    }

    /**
     * Stop scanning for BLE devices
     */
    fun stopScanning() {
        if (!isScanning) {
            return
        }

        try {
            scanCallback?.let {
                bluetoothLeScanner?.stopScan(it)
                Log.d(tag, "Stopped BLE scanning")
            }
        } catch (e: SecurityException) {
            Log.e(tag, "Security exception while stopping scan", e)
        } catch (e: Exception) {
            Log.e(tag, "Exception while stopping scan", e)
        } finally {
            isScanning = false
            scanCallback = null
        }
    }

    /**
     * Handle a scan result
     */
    private fun handleScanResult(result: ScanResult) {
        val device = result.device
        val rssi = result.rssi

        // Extract senderId from service data
        val serviceData = result.scanRecord?.getServiceData(
            ParcelUuid(BleConstants.MESH_SERVICE_UUID)
        )

        val senderId = if (serviceData != null && serviceData.size >= 6) {
            // Convert first 6 bytes to senderId string
            DeviceIdManager.compactIdToString(serviceData.sliceArray(0..5))
        } else {
            null  // Will be obtained via handshake after connection
        }

        if (senderId != null) {
            Log.d(tag, "Discovered device: ${device.address}, RSSI: $rssi, senderId: $senderId")
        } else {
            Log.d(tag, "Discovered device: ${device.address}, RSSI: $rssi (senderId not in advertisement)")
        }

        // Create peer from device with senderId
        val peer = Peer.fromDevice(device, rssi, senderId)

        // Notify callback
        onDeviceDiscovered?.invoke(peer)
    }

    /**
     * Check if currently scanning
     */
    fun isScanning(): Boolean = isScanning

    /**
     * Clean up resources
     */
    fun cleanup() {
        stopScanning()
        handler.removeCallbacksAndMessages(null)
        onDeviceDiscovered = null
        onScanError = null
    }
}

