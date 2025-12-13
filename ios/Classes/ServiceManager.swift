import Foundation
import CoreBluetooth

/// Manages GATT services and characteristics
class ServiceManager {
    private let tag = "ServiceManager"

    /// Find the mesh service in a peripheral
    func findMeshService(_ peripheral: CBPeripheral) -> CBService? {
        return peripheral.services?.first { $0.uuid == BleConstants.meshServiceUUID }
    }

    /// Find MSG characteristic (write to/receive from peer)
    func findMsgCharacteristic(_ peripheral: CBPeripheral) -> CBCharacteristic? {
        guard let service = findMeshService(peripheral) else { return nil }
        return service.characteristics?.first { $0.uuid == BleConstants.msgCharacteristicUUID }
    }

    /// Find control characteristic
    func findControlCharacteristic(_ peripheral: CBPeripheral) -> CBCharacteristic? {
        guard let service = findMeshService(peripheral) else { return nil }
        return service.characteristics?.first { $0.uuid == BleConstants.controlCharacteristicUUID }
    }

    /// Setup notifications for a characteristic
    func setupNotifications(_ peripheral: CBPeripheral, characteristic: CBCharacteristic) -> Bool {
        guard supportsNotifications(characteristic) else {
            print("[\(tag)] Characteristic does not support notifications: \(characteristic.uuid)")
            return false
        }

        peripheral.setNotifyValue(true, for: characteristic)
        print("[\(tag)] Enabled notifications for characteristic: \(characteristic.uuid)")
        return true
    }

    /// Disable notifications for a characteristic
    func disableNotifications(_ peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        peripheral.setNotifyValue(false, for: characteristic)
        print("[\(tag)] Disabled notifications for characteristic: \(characteristic.uuid)")
    }

    /// Write data to a characteristic
    func writeCharacteristic(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data, withResponse: Bool = true) -> Bool {
        guard supportsWrite(characteristic) else {
            print("[\(tag)] Characteristic does not support write: \(characteristic.uuid)")
            return false
        }

        let writeType: CBCharacteristicWriteType = withResponse ? .withResponse : .withoutResponse
        peripheral.writeValue(data, for: characteristic, type: writeType)

        print("[\(tag)] Writing \(data.count) bytes to characteristic: \(characteristic.uuid)")
        return true
    }

    /// Read data from a characteristic
    func readCharacteristic(_ peripheral: CBPeripheral, characteristic: CBCharacteristic) -> Bool {
        guard supportsRead(characteristic) else {
            print("[\(tag)] Characteristic does not support read: \(characteristic.uuid)")
            return false
        }

        peripheral.readValue(for: characteristic)
        print("[\(tag)] Reading characteristic: \(characteristic.uuid)")
        return true
    }

    /// Check if characteristic supports notifications
    func supportsNotifications(_ characteristic: CBCharacteristic) -> Bool {
        return characteristic.properties.contains(.notify) ||
               characteristic.properties.contains(.indicate)
    }

    /// Check if characteristic supports write
    func supportsWrite(_ characteristic: CBCharacteristic) -> Bool {
        return characteristic.properties.contains(.write) ||
               characteristic.properties.contains(.writeWithoutResponse)
    }

    /// Check if characteristic supports read
    func supportsRead(_ characteristic: CBCharacteristic) -> Bool {
        return characteristic.properties.contains(.read)
    }

    /// Get characteristic properties as string
    func getPropertiesString(_ characteristic: CBCharacteristic) -> String {
        var properties: [String] = []

        if characteristic.properties.contains(.read) { properties.append("read") }
        if characteristic.properties.contains(.write) { properties.append("write") }
        if characteristic.properties.contains(.writeWithoutResponse) { properties.append("writeWithoutResponse") }
        if characteristic.properties.contains(.notify) { properties.append("notify") }
        if characteristic.properties.contains(.indicate) { properties.append("indicate") }

        return properties.joined(separator: ", ")
    }
}

