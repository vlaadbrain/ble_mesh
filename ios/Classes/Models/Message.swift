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
    // Phase 2: Routing fields
    let ttl: Int
    let hopCount: Int
    let messageId: Int64
    let isForwarded: Bool

    init(
        id: String = UUID().uuidString,
        senderId: String,
        senderNickname: String,
        content: String,
        type: MessageType = .publicMessage,
        timestamp: Date = Date(),
        channel: String? = nil,
        isEncrypted: Bool = false,
        status: DeliveryStatus = .pending,
        // Phase 2: Routing fields with defaults
        ttl: Int = 7,
        hopCount: Int = 0,
        messageId: Int64 = MessageHeader.generateMessageId(),
        isForwarded: Bool = false
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
        self.ttl = ttl
        self.hopCount = hopCount
        self.messageId = messageId
        self.isForwarded = isForwarded
    }

    /// Serialize message to Data (header + payload)
    func toData() -> Data {
        guard let payloadData = content.data(using: .utf8) else {
            return Data()
        }

        let header = MessageHeader(
            type: headerTypeFromMessageType(type),
            ttl: UInt8(ttl),
            hopCount: UInt8(hopCount),
            messageId: messageId,
            senderId: senderId,
            payloadLength: UInt16(payloadData.count)
        )

        let headerData = header.toData()
        return headerData + payloadData
    }

    /// Parse message from Data (header + payload)
    static func fromData(_ data: Data, senderNickname: String = "Unknown") -> Message? {
        do {
            // Parse header
            let header = try MessageHeader.fromData(data)

            // Extract payload
            let payloadData = data.subdata(in: MessageHeader.headerSize..<data.count)
            guard let content = String(data: payloadData, encoding: .utf8) else {
                return nil
            }

            // Create message
            return Message(
                id: String(header.messageId),
                senderId: header.senderId,
                senderNickname: senderNickname,
                content: content,
                type: messageTypeFromHeaderType(header.type),
                timestamp: Date(),
                channel: nil,
                isEncrypted: false,
                status: .delivered,
                ttl: Int(header.ttl),
                hopCount: Int(header.hopCount),
                messageId: header.messageId,
                isForwarded: header.hopCount > 0
            )
        } catch {
            print("Failed to parse message from data: \(error)")
            return nil
        }
    }

    /// Convert MessageHeader type to MessageType
    private static func messageTypeFromHeaderType(_ headerType: UInt8) -> MessageType {
        switch headerType {
        case MessageHeader.typePublic:
            return .publicMessage
        case MessageHeader.typePrivate:
            return .privateMessage
        case MessageHeader.typeChannel:
            return .channel
        default:
            return .publicMessage
        }
    }

    /// Convert MessageType to MessageHeader type
    private func headerTypeFromMessageType(_ messageType: MessageType) -> UInt8 {
        switch messageType {
        case .publicMessage:
            return MessageHeader.typePublic
        case .privateMessage:
            return MessageHeader.typePrivate
        case .channel:
            return MessageHeader.typeChannel
        case .system:
            return MessageHeader.typePublic
        }
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
            "status": status.rawValue,
            // Phase 2: Routing fields
            "ttl": ttl,
            "hopCount": hopCount,
            "messageId": String(messageId),
            "isForwarded": isForwarded
        ]
    }
}

