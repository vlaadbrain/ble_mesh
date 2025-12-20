import Foundation
import CoreBluetooth

/// Connection state of a peer
enum PeerConnectionState: String {
    case discovered
    case connecting
    case connected
    case disconnecting
    case disconnected
}

/// Represents a peer in the BLE mesh network
struct Peer {
    let senderId: String?           // Stable UUID identifier (6-byte compact format)
    let connectionId: String        // CBPeripheral UUID for connections
    let nickname: String
    let rssi: Int
    let lastSeen: Date
    let connectionState: PeerConnectionState
    let hopCount: Int
    let lastForwardTime: Date?
    let isBlocked: Bool
    let peripheral: CBPeripheral?

    init(
        senderId: String? = nil,
        connectionId: String,
        nickname: String,
        rssi: Int = 0,
        lastSeen: Date = Date(),
        connectionState: PeerConnectionState = .discovered,
        hopCount: Int = 0,
        lastForwardTime: Date? = nil,
        isBlocked: Bool = false,
        peripheral: CBPeripheral? = nil
    ) {
        self.senderId = senderId
        self.connectionId = connectionId
        self.nickname = nickname
        self.rssi = rssi
        self.lastSeen = lastSeen
        self.connectionState = connectionState
        self.hopCount = hopCount
        self.lastForwardTime = lastForwardTime
        self.isBlocked = isBlocked
        self.peripheral = peripheral
    }

    /// Convenience property for backward compatibility (returns connectionId)
    var id: String {
        return connectionId
    }

    /// Check if peer can be connected to
    var canConnect: Bool {
        return senderId != nil &&
               connectionState == .discovered &&
               !isBlocked
    }

    /// Convert to a dictionary for sending to Flutter
    func toMap() -> [String: Any] {
        var map: [String: Any] = [
            "connectionId": connectionId,
            "id": connectionId,  // For backward compatibility
            "nickname": nickname,
            "rssi": rssi,
            "lastSeen": Int64(lastSeen.timeIntervalSince1970 * 1000),
            "connectionState": connectionState.rawValue,
            "hopCount": hopCount,
            "isBlocked": isBlocked
        ]

        if let senderId = senderId {
            map["senderId"] = senderId
        }

        if let lastForwardTime = lastForwardTime {
            map["lastForwardTime"] = Int64(lastForwardTime.timeIntervalSince1970 * 1000)
        }

        return map
    }

    /// Create a Peer from a CBPeripheral
    static func fromPeripheral(
        _ peripheral: CBPeripheral,
        rssi: Int = 0,
        senderId: String? = nil
    ) -> Peer {
        return Peer(
            senderId: senderId,
            connectionId: peripheral.identifier.uuidString,
            nickname: peripheral.name ?? "Unknown",
            rssi: rssi,
            connectionState: .discovered,
            peripheral: peripheral
        )
    }
}

