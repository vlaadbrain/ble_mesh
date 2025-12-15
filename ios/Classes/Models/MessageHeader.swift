import Foundation

/**
 * Message header for Phase 2 routing
 *
 * Binary format (20 bytes total):
 * - Version (1 byte): Protocol version (0x01)
 * - Type (1 byte): Message type
 * - TTL (1 byte): Time-to-live (hops remaining)
 * - Hop Count (1 byte): Number of hops taken
 * - Message ID (8 bytes): Unique message identifier
 * - Sender ID (6 bytes): Original sender MAC address
 * - Payload Length (2 bytes): Length of payload data
 */
struct MessageHeader {
    let version: UInt8
    var ttl: UInt8
    var hopCount: UInt8
    let type: UInt8
    let messageId: Int64
    let senderId: String  // MAC address as string (e.g., "AA:BB:CC:DD:EE:FF")
    let payloadLength: UInt16

    // Constants
    static let protocolVersion: UInt8 = 0x01
    static let headerSize = 20  // bytes

    // Message type constants
    static let typePublic: UInt8 = 0x01
    static let typePrivate: UInt8 = 0x02
    static let typeChannel: UInt8 = 0x03
    static let typePeerAnnouncement: UInt8 = 0x04
    static let typeAcknowledgment: UInt8 = 0x05
    static let typeKeyExchange: UInt8 = 0x06
    static let typeStoreForward: UInt8 = 0x07
    static let typeRoutingUpdate: UInt8 = 0x08

    /**
     * Initialize with all fields
     */
    init(version: UInt8 = MessageHeader.protocolVersion,
         type: UInt8,
         ttl: UInt8,
         hopCount: UInt8,
         messageId: Int64,
         senderId: String,
         payloadLength: UInt16) {
        self.version = version
        self.type = type
        self.ttl = ttl
        self.hopCount = hopCount
        self.messageId = messageId
        self.senderId = senderId
        self.payloadLength = payloadLength
    }

    /**
     * Generate a unique message ID using timestamp + random
     */
    static func generateMessageId() -> Int64 {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)  // milliseconds
        let random = Int64.random(in: 0...Int32.max)
        return (timestamp << 32) | (random & 0xFFFFFFFF)
    }

    /**
     * Serialize header to Data (20 bytes, big-endian)
     */
    func toData() -> Data {
        var data = Data(capacity: MessageHeader.headerSize)

        // Write fields in order (big-endian)
        data.append(version)
        data.append(type)
        data.append(ttl)
        data.append(hopCount)

        // Write message ID (8 bytes, big-endian)
        var messageIdBigEndian = messageId.bigEndian
        data.append(Data(bytes: &messageIdBigEndian, count: 8))

        // Write sender ID (6 bytes MAC address)
        if let senderIdBytes = MessageHeader.macStringToBytes(senderId) {
            data.append(senderIdBytes)
        } else {
            // Invalid MAC address, append zeros
            data.append(Data(repeating: 0, count: 6))
        }

        // Write payload length (2 bytes, big-endian)
        var payloadLengthBigEndian = payloadLength.bigEndian
        data.append(Data(bytes: &payloadLengthBigEndian, count: 2))

        return data
    }

    /**
     * Deserialize header from Data
     *
     * - Parameter data: Data containing the header (must be at least headerSize bytes)
     * - Returns: MessageHeader object or nil if invalid
     * - Throws: MessageHeaderError if data is invalid
     */
    static func fromData(_ data: Data) throws -> MessageHeader {
        guard data.count >= headerSize else {
            throw MessageHeaderError.dataTooSmall(size: data.count, required: headerSize)
        }

        var offset = 0

        // Parse version
        let version = data[offset]
        offset += 1

        // Validate version
        guard version == protocolVersion else {
            throw MessageHeaderError.unsupportedVersion(version: version)
        }

        // Parse type
        let type = data[offset]
        offset += 1

        // Parse TTL
        let ttl = data[offset]
        offset += 1

        // Parse hop count
        let hopCount = data[offset]
        offset += 1

        // Parse message ID (8 bytes, big-endian)
        let messageIdData = data.subdata(in: offset..<offset+8)
        let messageId = messageIdData.withUnsafeBytes { $0.load(as: Int64.self) }.bigEndian
        offset += 8

        // Parse sender ID (6 bytes MAC address)
        let senderIdBytes = data.subdata(in: offset..<offset+6)
        let senderId = MessageHeader.macBytesToString(senderIdBytes)
        offset += 6

        // Parse payload length (2 bytes, big-endian)
        let payloadLengthData = data.subdata(in: offset..<offset+2)
        let payloadLength = payloadLengthData.withUnsafeBytes { $0.load(as: UInt16.self) }.bigEndian

        return MessageHeader(
            version: version,
            type: type,
            ttl: ttl,
            hopCount: hopCount,
            messageId: messageId,
            senderId: senderId,
            payloadLength: payloadLength
        )
    }

    /**
     * Convert MAC address bytes to string format
     * Example: [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF] -> "AA:BB:CC:DD:EE:FF"
     */
    static func macBytesToString(_ bytes: Data) -> String {
        return bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    /**
     * Convert MAC address string to bytes
     * Example: "AA:BB:CC:DD:EE:FF" -> [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
     */
    static func macStringToBytes(_ mac: String) -> Data? {
        let parts = mac.split(separator: ":").map { String($0) }
        guard parts.count == 6 else {
            return nil
        }

        var bytes = Data(capacity: 6)
        for part in parts {
            guard let byte = UInt8(part, radix: 16) else {
                return nil
            }
            bytes.append(byte)
        }

        return bytes
    }

    /**
     * Check if message can be forwarded
     * Message can be forwarded if TTL > 1 (will be > 0 after decrement)
     */
    func canForward() -> Bool {
        return ttl > 1
    }

    /**
     * Decrement TTL and increment hop count for forwarding
     * Should be called before forwarding message to next hop
     */
    mutating func prepareForForward() {
        if ttl > 0 {
            ttl -= 1
        }
        hopCount += 1
    }

    /**
     * Get message type as string for logging
     */
    func getTypeString() -> String {
        switch type {
        case MessageHeader.typePublic:
            return "PUBLIC"
        case MessageHeader.typePrivate:
            return "PRIVATE"
        case MessageHeader.typeChannel:
            return "CHANNEL"
        case MessageHeader.typePeerAnnouncement:
            return "PEER_ANNOUNCEMENT"
        case MessageHeader.typeAcknowledgment:
            return "ACKNOWLEDGMENT"
        case MessageHeader.typeKeyExchange:
            return "KEY_EXCHANGE"
        case MessageHeader.typeStoreForward:
            return "STORE_FORWARD"
        case MessageHeader.typeRoutingUpdate:
            return "ROUTING_UPDATE"
        default:
            return "UNKNOWN(\(type))"
        }
    }

    /**
     * Convert to dictionary for debugging/logging
     */
    func toMap() -> [String: Any] {
        return [
            "version": version,
            "type": type,
            "ttl": ttl,
            "hopCount": hopCount,
            "messageId": String(messageId),
            "senderId": senderId,
            "payloadLength": payloadLength
        ]
    }
}

/**
 * Errors that can occur during MessageHeader parsing
 */
enum MessageHeaderError: Error, CustomStringConvertible {
    case dataTooSmall(size: Int, required: Int)
    case unsupportedVersion(version: UInt8)
    case invalidMacAddress(mac: String)

    var description: String {
        switch self {
        case .dataTooSmall(let size, let required):
            return "Data too small for header: \(size) < \(required)"
        case .unsupportedVersion(let version):
            return "Unsupported protocol version: \(version)"
        case .invalidMacAddress(let mac):
            return "Invalid MAC address format: \(mac)"
        }
    }
}

// MARK: - CustomStringConvertible
extension MessageHeader: CustomStringConvertible {
    var description: String {
        return "MessageHeader(version=\(version), type=\(getTypeString()), ttl=\(ttl), " +
               "hopCount=\(hopCount), messageId=\(messageId), senderId=\(senderId), " +
               "payloadLength=\(payloadLength))"
    }
}

