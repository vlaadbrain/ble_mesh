import Foundation
import CoreBluetooth

/// Manages peripheral connections
class BleConnectionManager: NSObject {
    private let tag = "BleConnectionManager"

    private var centralManager: CBCentralManager?

    // Thread-safe dictionaries for connections
    private let queue = DispatchQueue(label: "com.ble_mesh.connectionmanager")
    private var connectedPeripherals: [String: CBPeripheral] = [:]
    private var connectingPeripherals: [String: CBPeripheral] = [:]
    private var connectionTimers: [String: Timer] = [:]

    // Callbacks
    var onPeripheralConnected: ((String, CBPeripheral) -> Void)?
    var onPeripheralDisconnected: ((String) -> Void)?
    var onServicesDiscovered: ((String, CBPeripheral) -> Void)?
    var onCharacteristicDiscovered: ((String, CBCharacteristic) -> Void)?
    var onCharacteristicValueUpdated: ((String, UUID, Data) -> Void)?
    var onCharacteristicWritten: ((String, UUID) -> Void)?
    var onConnectionError: ((String, String) -> Void)?

    /// Initialize with central manager
    func initialize(centralManager: CBCentralManager) {
        self.centralManager = centralManager
    }

    /// Connect to a peripheral
    func connectToPeripheral(_ peripheral: CBPeripheral) {
        let identifier = peripheral.identifier.uuidString

        queue.async { [weak self] in
            guard let self = self else { return }

            // Check if already connected or connecting
            if self.connectedPeripherals[identifier] != nil {
                print("[\(self.tag)] Already connected to peripheral: \(identifier)")
                return
            }

            if self.connectingPeripherals[identifier] != nil {
                print("[\(self.tag)] Already connecting to peripheral: \(identifier)")
                return
            }

            // Check max connections
            if self.connectedPeripherals.count >= BleConstants.maxConnections {
                print("[\(self.tag)] Max connections reached, cannot connect to: \(identifier)")
                DispatchQueue.main.async {
                    self.onConnectionError?(identifier, "Max connections reached")
                }
                return
            }

            print("[\(self.tag)] Connecting to peripheral: \(identifier)")
            self.connectingPeripherals[identifier] = peripheral

            // Set peripheral delegate
            peripheral.delegate = self

            // Connect
            DispatchQueue.main.async {
                self.centralManager?.connect(peripheral, options: nil)
            }

            // Set connection timeout
            let timer = Timer.scheduledTimer(withTimeInterval: BleConstants.connectionTimeoutMs, repeats: false) { [weak self] _ in
                guard let self = self else { return }

                self.queue.async {
                    if self.connectingPeripherals[identifier] != nil {
                        print("[\(self.tag)] Connection timeout for peripheral: \(identifier)")
                        self.disconnectPeripheral(identifier)

                        DispatchQueue.main.async {
                            self.onConnectionError?(identifier, "Connection timeout")
                        }
                    }
                }
            }

            self.connectionTimers[identifier] = timer
        }
    }

    /// Disconnect from a peripheral
    func disconnectPeripheral(_ identifier: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Cancel timeout timer
            self.connectionTimers[identifier]?.invalidate()
            self.connectionTimers.removeValue(forKey: identifier)

            let peripheral = self.connectedPeripherals[identifier] ?? self.connectingPeripherals[identifier]

            if let peripheral = peripheral {
                print("[\(self.tag)] Disconnecting peripheral: \(identifier)")

                DispatchQueue.main.async {
                    self.centralManager?.cancelPeripheralConnection(peripheral)
                }
            }

            self.connectingPeripherals.removeValue(forKey: identifier)
            self.connectedPeripherals.removeValue(forKey: identifier)
        }
    }

    /// Get connected peripheral
    func getConnectedPeripheral(_ identifier: String) -> CBPeripheral? {
        return queue.sync {
            return connectedPeripherals[identifier]
        }
    }

    /// Check if peripheral is connected
    func isConnected(_ identifier: String) -> Bool {
        return queue.sync {
            return connectedPeripherals[identifier] != nil
        }
    }

    /// Get all connected peripheral identifiers
    func getConnectedPeripherals() -> [String] {
        return queue.sync {
            return Array(connectedPeripherals.keys)
        }
    }

    /// Disconnect all peripherals
    func disconnectAll() {
        let identifiers = queue.sync { Array(connectedPeripherals.keys) }
        identifiers.forEach { disconnectPeripheral($0) }
    }

    /// Handle peripheral connected
    func handlePeripheralConnected(_ peripheral: CBPeripheral) {
        let identifier = peripheral.identifier.uuidString

        queue.async { [weak self] in
            guard let self = self else { return }

            // Cancel timeout timer
            self.connectionTimers[identifier]?.invalidate()
            self.connectionTimers.removeValue(forKey: identifier)

            // Move from connecting to connected
            self.connectingPeripherals.removeValue(forKey: identifier)
            self.connectedPeripherals[identifier] = peripheral

            print("[\(self.tag)] Peripheral connected: \(identifier)")

            DispatchQueue.main.async {
                self.onPeripheralConnected?(identifier, peripheral)
            }

            // Discover services
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                peripheral.discoverServices([BleConstants.meshServiceUUID])
            }
        }
    }

    /// Handle peripheral disconnected
    func handlePeripheralDisconnected(_ peripheral: CBPeripheral, error: Error?) {
        let identifier = peripheral.identifier.uuidString

        queue.async { [weak self] in
            guard let self = self else { return }

            // Cancel timeout timer
            self.connectionTimers[identifier]?.invalidate()
            self.connectionTimers.removeValue(forKey: identifier)

            self.connectingPeripherals.removeValue(forKey: identifier)
            self.connectedPeripherals.removeValue(forKey: identifier)

            print("[\(self.tag)] Peripheral disconnected: \(identifier)")

            DispatchQueue.main.async {
                self.onPeripheralDisconnected?(identifier)
            }

            if let error = error {
                print("[\(self.tag)] Disconnection error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.onConnectionError?(identifier, error.localizedDescription)
                }
            }
        }
    }

    /// Clean up resources
    func cleanup() {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Cancel all timers
            self.connectionTimers.values.forEach { $0.invalidate() }
            self.connectionTimers.removeAll()

            // Disconnect all
            let peripherals = Array(self.connectedPeripherals.values) + Array(self.connectingPeripherals.values)

            DispatchQueue.main.async {
                peripherals.forEach { peripheral in
                    self.centralManager?.cancelPeripheralConnection(peripheral)
                }
            }

            self.connectedPeripherals.removeAll()
            self.connectingPeripherals.removeAll()
        }

        onPeripheralConnected = nil
        onPeripheralDisconnected = nil
        onServicesDiscovered = nil
        onCharacteristicDiscovered = nil
        onCharacteristicValueUpdated = nil
        onCharacteristicWritten = nil
        onConnectionError = nil
    }
}

// MARK: - CBPeripheralDelegate
extension BleConnectionManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let identifier = peripheral.identifier.uuidString

        if let error = error {
            print("[\(tag)] Service discovery error: \(error.localizedDescription)")
            onConnectionError?(identifier, "Service discovery failed: \(error.localizedDescription)")
            return
        }

        print("[\(tag)] Services discovered for peripheral: \(identifier)")
        onServicesDiscovered?(identifier, peripheral)

        // Discover characteristics for mesh service
        if let service = peripheral.services?.first(where: { $0.uuid == BleConstants.meshServiceUUID }) {
            peripheral.discoverCharacteristics([
                BleConstants.txCharacteristicUUID,
                BleConstants.rxCharacteristicUUID,
                BleConstants.controlCharacteristicUUID
            ], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let identifier = peripheral.identifier.uuidString

        if let error = error {
            print("[\(tag)] Characteristic discovery error: \(error.localizedDescription)")
            onConnectionError?(identifier, "Characteristic discovery failed: \(error.localizedDescription)")
            return
        }

        print("[\(tag)] Characteristics discovered for peripheral: \(identifier)")

        service.characteristics?.forEach { characteristic in
            print("[\(tag)] Found characteristic: \(characteristic.uuid)")
            onCharacteristicDiscovered?(identifier, characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let identifier = peripheral.identifier.uuidString

        if let error = error {
            print("[\(tag)] Characteristic update error: \(error.localizedDescription)")
            return
        }

        if let data = characteristic.value {
            print("[\(tag)] Characteristic value updated: \(characteristic.uuid), size: \(data.count)")
            onCharacteristicValueUpdated?(identifier, characteristic.uuid, data)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let identifier = peripheral.identifier.uuidString

        if let error = error {
            print("[\(tag)] Characteristic write error: \(error.localizedDescription)")
            onConnectionError?(identifier, "Write failed: \(error.localizedDescription)")
            return
        }

        print("[\(tag)] Characteristic write success: \(characteristic.uuid)")
        onCharacteristicWritten?(identifier, characteristic.uuid)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let identifier = peripheral.identifier.uuidString

        if let error = error {
            print("[\(tag)] Notification state update error: \(error.localizedDescription)")
            return
        }

        if characteristic.isNotifying {
            print("[\(tag)] Notifications enabled for characteristic: \(characteristic.uuid)")
        } else {
            print("[\(tag)] Notifications disabled for characteristic: \(characteristic.uuid)")
        }
    }
}

