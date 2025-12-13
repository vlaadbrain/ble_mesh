import Foundation
import CoreBluetooth

/// Handles BLE advertising to make device discoverable
class BleAdvertiser: NSObject {
    private let tag = "BleAdvertiser"

    private var peripheralManager: CBPeripheralManager?
    private var isAdvertising = false
    private var deviceName: String = "BleMesh"

    // Callbacks
    var onAdvertisingStarted: (() -> Void)?
    var onAdvertisingFailed: ((Int, String) -> Void)?

    override init() {
        super.init()
    }

    /// Initialize the peripheral manager
    func initialize() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Start BLE advertising
    func startAdvertising(deviceName: String = "BleMesh") {
        guard let peripheralManager = peripheralManager else {
            print("[\(tag)] Peripheral manager not initialized")
            onAdvertisingFailed?(-1, "Peripheral manager not initialized")
            return
        }

        if isAdvertising {
            print("[\(tag)] Already advertising")
            return
        }

        guard peripheralManager.state == .poweredOn else {
            print("[\(tag)] Bluetooth is not powered on")
            onAdvertisingFailed?(-1, "Bluetooth is not powered on")
            return
        }

        self.deviceName = deviceName

        // Create advertisement data
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [BleConstants.meshServiceUUID],
            CBAdvertisementDataLocalNameKey: deviceName
        ]

        // Start advertising
        peripheralManager.startAdvertising(advertisementData)
        print("[\(tag)] Started BLE advertising with name: \(deviceName)")
    }

    /// Stop BLE advertising
    func stopAdvertising() {
        guard let peripheralManager = peripheralManager else {
            return
        }

        if !isAdvertising {
            return
        }

        peripheralManager.stopAdvertising()
        isAdvertising = false
        print("[\(tag)] Stopped BLE advertising")
    }

    /// Check if currently advertising
    func isAdvertisingActive() -> Bool {
        return isAdvertising
    }

    /// Clean up resources
    func cleanup() {
        stopAdvertising()
        peripheralManager = nil
        onAdvertisingStarted = nil
        onAdvertisingFailed = nil
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BleAdvertiser: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("[\(tag)] Bluetooth powered on")
        case .poweredOff:
            print("[\(tag)] Bluetooth powered off")
            if isAdvertising {
                stopAdvertising()
            }
            onAdvertisingFailed?(-1, "Bluetooth powered off")
        case .unauthorized:
            print("[\(tag)] Bluetooth unauthorized")
            onAdvertisingFailed?(-1, "Bluetooth unauthorized")
        case .unsupported:
            print("[\(tag)] Bluetooth unsupported")
            onAdvertisingFailed?(-1, "Bluetooth unsupported")
        case .resetting:
            print("[\(tag)] Bluetooth resetting")
        case .unknown:
            print("[\(tag)] Bluetooth state unknown")
        @unknown default:
            print("[\(tag)] Bluetooth state unknown")
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("[\(tag)] Advertising failed: \(error.localizedDescription)")
            isAdvertising = false
            onAdvertisingFailed?(-1, error.localizedDescription)
        } else {
            isAdvertising = true
            print("[\(tag)] Advertising started successfully")
            onAdvertisingStarted?()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("[\(tag)] Central subscribed to characteristic: \(characteristic.uuid)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("[\(tag)] Central unsubscribed from characteristic: \(characteristic.uuid)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("[\(tag)] Received read request for characteristic: \(request.characteristic.uuid)")
        // Handle read request (to be implemented in Phase 1 Task #6)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("[\(tag)] Received write requests")
        // Handle write requests (to be implemented in Phase 1 Task #6)
    }
}

