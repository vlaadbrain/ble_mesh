import Foundation

/// Type of message
enum MessageType: Int {
    case publicMessage = 0
    case privateMessage = 1
    case channel = 2
    case system = 3
}

/// Delivery status of a message
enum DeliveryStatus: Int {
    case pending = 0
    case sent = 1
    case delivered = 2
    case failed = 3
}

/// Represents a message in the mesh network
struct Message {
    let id: String
    let senderId: String
    let senderNickname: String
    let content: String
    let type: MessageType
    let timestamp: Date
    let channel: String?
    let isEncrypted: Bool
    let status: DeliveryStatus

    init(
        id: String = UUID().uuidString,
        senderId: String,
        senderNickname: String,
        content: String,
        type: MessageType = .publicMessage,
        timestamp: Date = Date(),
        channel: String? = nil,
        isEncrypted: Bool = false,
        status: DeliveryStatus = .pending
    ) {
        self.id = id
        self.senderId = senderId
        self.senderNickname = senderNickname
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.channel = channel
        self.isEncrypted = isEncrypted
        self.status = status
    }

    /// Convert to a dictionary for sending to Flutter
    func toMap() -> [String: Any?] {
        return [
            "id": id,
            "senderId": senderId,
            "senderNickname": senderNickname,
            "content": content,
            "type": type.rawValue,
            "timestamp": Int64(timestamp.timeIntervalSince1970 * 1000),
            "channel": channel,
            "isEncrypted": isEncrypted,
            "status": status.rawValue
        ]
    }
}

