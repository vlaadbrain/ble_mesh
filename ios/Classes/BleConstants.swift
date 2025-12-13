import Foundation
import CoreBluetooth

/// Constants for BLE mesh networking
class BleConstants {
    // Service UUID for BLE mesh (must match Android)
    static let meshServiceUUID = CBUUID(string: "00001234-0000-1000-8000-00805F9B34FB")

    // Characteristic UUIDs
    static let msgCharacteristicUUID = CBUUID(string: "00001235-0000-1000-8000-00805F9B34FB")
    static let controlCharacteristicUUID = CBUUID(string: "00001237-0000-1000-8000-00805F9B34FB")

    // Scan settings
    static let scanPeriodMs: TimeInterval = 10.0 // 10 seconds
    static let scanIntervalBalancedMs: TimeInterval = 5.0 // 5 seconds between scans
    static let scanIntervalPowerSaverMs: TimeInterval = 15.0 // 15 seconds between scans

    // Connection settings
    static let maxConnections = 7
    static let connectionTimeoutMs: TimeInterval = 30.0 // 30 seconds

    // Message settings
    static let maxMessageSize = 512 // bytes
    static let mtuSize = 512 // Maximum Transmission Unit
}

