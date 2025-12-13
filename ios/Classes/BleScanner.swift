import Foundation
import CoreBluetooth

/// Handles BLE scanning for nearby mesh devices
class BleScanner: NSObject {
    private let tag = "BleScanner"

    private var centralManager: CBCentralManager?
    private var isScanning = false
    private var scanTimer: Timer?

    // Callbacks
    var onDeviceDiscovered: ((Peer) -> Void)?
    var onScanError: ((Int, String) -> Void)?

    override init() {
        super.init()
    }

    /// Initialize the central manager
    func initialize() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    /// Get the central manager
    func getCentralManager() -> CBCentralManager? {
        return centralManager
    }

    /// Start scanning for BLE mesh devices
    func startScanning() {
        guard let centralManager = centralManager else {
            print("[\(tag)] Central manager not initialized")
            onScanError?(-1, "Central manager not initialized")
            return
        }

        if isScanning {
            print("[\(tag)] Already scanning")
            return
        }

        guard centralManager.state == .poweredOn else {
            print("[\(tag)] Bluetooth is not powered on")
            onScanError?(-1, "Bluetooth is not powered on")
            return
        }

        // Start scanning for mesh service UUID
        let serviceUUIDs = [BleConstants.meshServiceUUID]
        let options: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ]

        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
        isScanning = true
        print("[\(tag)] Started BLE scanning")

        // Schedule scan stop after scan period
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: BleConstants.scanPeriodMs, repeats: false) { [weak self] _ in
            self?.stopScanning()
        }
    }

    /// Stop scanning for BLE devices
    func stopScanning() {
        guard let centralManager = centralManager else {
            return
        }

        if !isScanning {
            return
        }

        centralManager.stopScan()
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
        print("[\(tag)] Stopped BLE scanning")
    }

    /// Check if currently scanning
    func isScanningActive() -> Bool {
        return isScanning
    }

    /// Clean up resources
    func cleanup() {
        stopScanning()
        centralManager = nil
        onDeviceDiscovered = nil
        onScanError = nil
    }
}

// MARK: - CBCentralManagerDelegate
extension BleScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("[\(tag)] Bluetooth powered on")
        case .poweredOff:
            print("[\(tag)] Bluetooth powered off")
            if isScanning {
                stopScanning()
            }
            onScanError?(-1, "Bluetooth powered off")
        case .unauthorized:
            print("[\(tag)] Bluetooth unauthorized")
            onScanError?(-1, "Bluetooth unauthorized")
        case .unsupported:
            print("[\(tag)] Bluetooth unsupported")
            onScanError?(-1, "Bluetooth unsupported")
        case .resetting:
            print("[\(tag)] Bluetooth resetting")
        case .unknown:
            print("[\(tag)] Bluetooth state unknown")
        @unknown default:
            print("[\(tag)] Bluetooth state unknown")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let rssiValue = RSSI.intValue

        // Filter out devices with very weak signal
        guard rssiValue > -100 else {
            return
        }

        print("[\(tag)] Discovered device: \(peripheral.identifier.uuidString), RSSI: \(rssiValue)")

        // Create peer from peripheral
        let peer = Peer.fromPeripheral(peripheral, rssi: rssiValue)

        // Notify callback
        onDeviceDiscovered?(peer)
    }

    // Connection callbacks are now handled by BleConnectionManager
}

