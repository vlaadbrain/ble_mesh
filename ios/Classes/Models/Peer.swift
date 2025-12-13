import Foundation
import CoreBluetooth

/// Represents a peer in the BLE mesh network
struct Peer {
    let id: String
    let nickname: String
    let rssi: Int
    let lastSeen: Date
    let isConnected: Bool
    let hopCount: Int
    let peripheral: CBPeripheral?

    init(
        id: String,
        nickname: String,
        rssi: Int = 0,
        lastSeen: Date = Date(),
        isConnected: Bool = false,
        hopCount: Int = 0,
        peripheral: CBPeripheral? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.rssi = rssi
        self.lastSeen = lastSeen
        self.isConnected = isConnected
        self.hopCount = hopCount
        self.peripheral = peripheral
    }

    /// Convert to a dictionary for sending to Flutter
    func toMap() -> [String: Any] {
        return [
            "id": id,
            "nickname": nickname,
            "rssi": rssi,
            "lastSeen": Int64(lastSeen.timeIntervalSince1970 * 1000),
            "isConnected": isConnected,
            "hopCount": hopCount
        ]
    }

    /// Create a Peer from a CBPeripheral
    static func fromPeripheral(_ peripheral: CBPeripheral, rssi: Int = 0) -> Peer {
        return Peer(
            id: peripheral.identifier.uuidString,
            nickname: peripheral.name ?? "Unknown",
            rssi: rssi,
            peripheral: peripheral
        )
    }
}

