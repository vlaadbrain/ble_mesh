import Foundation
import CoreBluetooth

/// Manages the peripheral server for providing mesh services to connected centrals
class BlePeripheralServer: NSObject {
    private let tag = "BlePeripheralServer"

    private var peripheralManager: CBPeripheralManager?
    private var meshService: CBMutableService?
    private var msgCharacteristic: CBMutableCharacteristic?
    private var controlCharacteristic: CBMutableCharacteristic?

    private var connectedCentrals = Set<CBCentral>()
    private var subscribedCentrals = Set<CBCentral>()

    // Callbacks
    var onCharacteristicWriteRequest: ((CBCentral, Data) -> Void)?
    var onCharacteristicReadRequest: ((CBCentral) -> Data?)?
    var onCentralConnected: ((CBCentral) -> Void)?
    var onCentralDisconnected: ((CBCentral) -> Void)?

    override init() {
        super.init()
    }

    /// Start the peripheral server
    func start() -> Bool {
        if peripheralManager != nil {
            print("[\(tag)] Peripheral server already started")
            return true
        }

        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)

        // Service will be added when peripheral manager is powered on
        return true
    }

    /// Stop the peripheral server
    func stop() {
        guard let peripheralManager = peripheralManager else {
            return
        }

        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        self.peripheralManager = nil

        connectedCentrals.removeAll()
        subscribedCentrals.removeAll()

        print("[\(tag)] Peripheral server stopped")
    }

    /// Send notification to a connected central
    func sendNotification(to central: CBCentral, data: Data) -> Bool {
        guard let peripheralManager = peripheralManager,
              let msgCharacteristic = msgCharacteristic else {
            print("[\(tag)] Peripheral manager or MSG characteristic not available")
            return false
        }

        guard subscribedCentrals.contains(central) else {
            print("[\(tag)] Central not subscribed to notifications")
            return false
        }

        let success = peripheralManager.updateValue(data, for: msgCharacteristic, onSubscribedCentrals: [central])

        if success {
            print("[\(tag)] Sent notification to central, size: \(data.count) bytes")
        } else {
            print("[\(tag)] Failed to send notification - queue full, will retry")
        }

        return success
    }

    /// Send notification to all subscribed centrals
    func sendNotificationToAll(data: Data) -> Bool {
        guard let peripheralManager = peripheralManager,
              let msgCharacteristic = msgCharacteristic else {
            print("[\(tag)] Peripheral manager or MSG characteristic not available")
            return false
        }

        guard !subscribedCentrals.isEmpty else {
            print("[\(tag)] No centrals subscribed to notifications")
            return false
        }

        let success = peripheralManager.updateValue(data, for: msgCharacteristic, onSubscribedCentrals: Array(subscribedCentrals))

        if success {
            print("[\(tag)] Sent notification to \(subscribedCentrals.count) centrals")
        } else {
            print("[\(tag)] Failed to send notification - queue full")
        }

        return success
    }

    /// Get list of connected centrals
    func getConnectedCentrals() -> [CBCentral] {
        return Array(connectedCentrals)
    }

    /// Create the mesh service with MSG characteristics
    private func createMeshService() {
        // Create MSG characteristic (central writes/reads/subscribes to this)
        msgCharacteristic = CBMutableCharacteristic(
            type: BleConstants.msgCharacteristicUUID,
            properties: [.write, .writeWithoutResponse, .read, .notify],
            value: nil,
            permissions: [.writeable, .readable]
        )

        // Create control characteristic (for future use)
        controlCharacteristic = CBMutableCharacteristic(
            type: BleConstants.controlCharacteristicUUID,
            properties: [.read, .write],
            value: nil,
            permissions: [.readable, .writeable]
        )

        // Create the service
        meshService = CBMutableService(type: BleConstants.meshServiceUUID, primary: true)
        meshService?.characteristics = [
            msgCharacteristic!,
            controlCharacteristic!
        ]

        print("[\(tag)] Created mesh service with MSG and Control characteristics")
    }

    /// Add the service to the peripheral manager
    private func addService() {
        guard let peripheralManager = peripheralManager,
              let meshService = meshService else {
            print("[\(tag)] Cannot add service - peripheral manager or service not available")
            return
        }

        peripheralManager.add(meshService)
    }

    /// Clean up resources
    func cleanup() {
        stop()
        onCharacteristicWriteRequest = nil
        onCharacteristicReadRequest = nil
        onCentralConnected = nil
        onCentralDisconnected = nil
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BlePeripheralServer: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("[\(tag)] Bluetooth powered on")
            // Create and add service when powered on
            createMeshService()
            addService()

        case .poweredOff:
            print("[\(tag)] Bluetooth powered off")

        case .unauthorized:
            print("[\(tag)] Bluetooth unauthorized")

        case .unsupported:
            print("[\(tag)] Bluetooth unsupported")

        case .resetting:
            print("[\(tag)] Bluetooth resetting")

        case .unknown:
            print("[\(tag)] Bluetooth state unknown")

        @unknown default:
            print("[\(tag)] Bluetooth state unknown")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("[\(tag)] Failed to add service: \(error.localizedDescription)")
        } else {
            print("[\(tag)] Service added successfully: \(service.uuid)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("[\(tag)] Central subscribed to characteristic: \(characteristic.uuid)")

        if characteristic.uuid == BleConstants.msgCharacteristicUUID {
            subscribedCentrals.insert(central)
            connectedCentrals.insert(central)
            print("[\(tag)] Central \(central.identifier) subscribed to MSG notifications")
            onCentralConnected?(central)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("[\(tag)] Central unsubscribed from characteristic: \(characteristic.uuid)")

        if characteristic.uuid == BleConstants.msgCharacteristicUUID {
            subscribedCentrals.remove(central)
            print("[\(tag)] Central \(central.identifier) unsubscribed from MSG notifications")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("[\(tag)] Received read request for characteristic: \(request.characteristic.uuid)")

        if request.characteristic.uuid == BleConstants.msgCharacteristicUUID {
            // Handle MSG characteristic read
            if let data = onCharacteristicReadRequest?(request.central) {
                if request.offset > data.count {
                    peripheral.respond(to: request, withResult: .invalidOffset)
                    return
                }

                let range = request.offset..<data.count
                request.value = data.subdata(in: range)
                peripheral.respond(to: request, withResult: .success)
            } else {
                request.value = Data()
                peripheral.respond(to: request, withResult: .success)
            }
        } else if request.characteristic.uuid == BleConstants.controlCharacteristicUUID {
            // Handle control characteristic read
            request.value = Data()
            peripheral.respond(to: request, withResult: .success)
        } else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("[\(tag)] Received \(requests.count) write request(s)")

        for request in requests {
            if request.characteristic.uuid == BleConstants.msgCharacteristicUUID {
                // Handle MSG characteristic write (message from central)
                if let value = request.value {
                    print("[\(tag)] Received data from central: \(value.count) bytes")
                    onCharacteristicWriteRequest?(request.central, value)
                }
                peripheral.respond(to: request, withResult: .success)

            } else if request.characteristic.uuid == BleConstants.controlCharacteristicUUID {
                // Handle control characteristic write
                peripheral.respond(to: request, withResult: .success)

            } else {
                peripheral.respond(to: request, withResult: .attributeNotFound)
            }
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("[\(tag)] Peripheral manager is ready to send more data")
        // Can retry failed notifications here if needed
    }
}

