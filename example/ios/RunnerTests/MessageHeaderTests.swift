import XCTest
@testable import ble_mesh

/**
 * Unit tests for MessageHeader serialization/deserialization
 */
class MessageHeaderTests: XCTestCase {

    func testHeaderSerialization() {
        // Create a test header
        let messageId = MessageHeader.generateMessageId()
        let senderId = "AA:BB:CC:DD:EE:FF"
        let header = MessageHeader(
            type: MessageHeader.typePublic,
            ttl: 7,
            hopCount: 0,
            messageId: messageId,
            senderId: senderId,
            payloadLength: 13
        )

        // Serialize to data
        let data = header.toData()

        // Verify size
        XCTAssertEqual(data.count, MessageHeader.headerSize, "Header should be 20 bytes")

        // Verify first byte is protocol version
        XCTAssertEqual(data[0], MessageHeader.protocolVersion, "First byte should be protocol version")

        // Verify second byte is message type
        XCTAssertEqual(data[1], MessageHeader.typePublic, "Second byte should be message type")

        // Verify TTL
        XCTAssertEqual(data[2], 7, "Third byte should be TTL")

        // Verify hop count
        XCTAssertEqual(data[3], 0, "Fourth byte should be hop count")
    }

    func testHeaderDeserialization() throws {
        // Create a test header
        let messageId: Int64 = 123456789
        let senderId = "11:22:33:44:55:66"
        let header = MessageHeader(
            type: MessageHeader.typeChannel,
            ttl: 5,
            hopCount: 2,
            messageId: messageId,
            senderId: senderId,
            payloadLength: 100
        )

        // Serialize and deserialize
        let data = header.toData()
        let deserialized = try MessageHeader.fromData(data)

        // Verify all fields match
        XCTAssertEqual(header.version, deserialized.version, "Version should match")
        XCTAssertEqual(header.type, deserialized.type, "Type should match")
        XCTAssertEqual(header.ttl, deserialized.ttl, "TTL should match")
        XCTAssertEqual(header.hopCount, deserialized.hopCount, "Hop count should match")
        XCTAssertEqual(header.messageId, deserialized.messageId, "Message ID should match")
        XCTAssertEqual(header.senderId, deserialized.senderId, "Sender ID should match")
        XCTAssertEqual(header.payloadLength, deserialized.payloadLength, "Payload length should match")
    }

    func testRoundTripSerialization() throws {
        // Test multiple headers to ensure consistency
        let testCases: [(UInt8, String, UInt8)] = [
            (MessageHeader.typePublic, "AA:BB:CC:DD:EE:FF", 7),
            (MessageHeader.typePrivate, "11:22:33:44:55:66", 5),
            (MessageHeader.typeChannel, "FF:EE:DD:CC:BB:AA", 3),
            (MessageHeader.typePeerAnnouncement, "00:11:22:33:44:55", 1)
        ]

        for (index, testCase) in testCases.enumerated() {
            let (type, senderId, ttl) = testCase
            let header = MessageHeader(
                type: type,
                ttl: ttl,
                hopCount: 0,
                messageId: MessageHeader.generateMessageId(),
                senderId: senderId,
                payloadLength: UInt16(index * 10)
            )

            let data = header.toData()
            let deserialized = try MessageHeader.fromData(data)

            XCTAssertEqual(header.type, deserialized.type, "Test case \(index): Type should match")
            XCTAssertEqual(header.ttl, deserialized.ttl, "Test case \(index): TTL should match")
            XCTAssertEqual(header.senderId, deserialized.senderId, "Test case \(index): Sender ID should match")
            XCTAssertEqual(header.payloadLength, deserialized.payloadLength, "Test case \(index): Payload length should match")
        }
    }

    func testPrepareForForward() {
        var header = MessageHeader(
            type: MessageHeader.typePublic,
            ttl: 7,
            hopCount: 0,
            messageId: 12345,
            senderId: "AA:BB:CC:DD:EE:FF",
            payloadLength: 10
        )

        // Initial state
        XCTAssertEqual(header.ttl, 7, "Initial TTL should be 7")
        XCTAssertEqual(header.hopCount, 0, "Initial hop count should be 0")
        XCTAssertTrue(header.canForward(), "Should be able to forward")

        // After preparing for forward
        header.prepareForForward()
        XCTAssertEqual(header.ttl, 6, "TTL should be decremented to 6")
        XCTAssertEqual(header.hopCount, 1, "Hop count should be incremented to 1")
        XCTAssertTrue(header.canForward(), "Should still be able to forward")

        // Forward multiple times
        for _ in 0..<5 {
            header.prepareForForward()
        }
        XCTAssertEqual(header.ttl, 1, "TTL should be 1 after 6 forwards")
        XCTAssertEqual(header.hopCount, 6, "Hop count should be 6")
        XCTAssertFalse(header.canForward(), "Should not be able to forward (TTL=1)")
    }

    func testCanForward() {
        // TTL > 1: Can forward
        let header1 = MessageHeader(
            type: MessageHeader.typePublic,
            ttl: 2,
            hopCount: 0,
            messageId: 1,
            senderId: "AA:BB:CC:DD:EE:FF",
            payloadLength: 10
        )
        XCTAssertTrue(header1.canForward(), "TTL=2 should be able to forward")

        // TTL = 1: Cannot forward (would become 0)
        let header2 = MessageHeader(
            type: MessageHeader.typePublic,
            ttl: 1,
            hopCount: 0,
            messageId: 2,
            senderId: "AA:BB:CC:DD:EE:FF",
            payloadLength: 10
        )
        XCTAssertFalse(header2.canForward(), "TTL=1 should not be able to forward")

        // TTL = 0: Cannot forward
        let header3 = MessageHeader(
            type: MessageHeader.typePublic,
            ttl: 0,
            hopCount: 5,
            messageId: 3,
            senderId: "AA:BB:CC:DD:EE:FF",
            payloadLength: 10
        )
        XCTAssertFalse(header3.canForward(), "TTL=0 should not be able to forward")
    }

    func testMessageIdGeneration() {
        // Generate multiple IDs and ensure they're unique
        var ids = Set<Int64>()
        for _ in 0..<1000 {
            let id = MessageHeader.generateMessageId()
            XCTAssertFalse(ids.contains(id), "Message ID should be unique")
            ids.insert(id)
        }
        XCTAssertEqual(ids.count, 1000, "Should have generated 1000 unique IDs")
    }

    func testGetTypeString() {
        let types: [(UInt8, String)] = [
            (MessageHeader.typePublic, "PUBLIC"),
            (MessageHeader.typePrivate, "PRIVATE"),
            (MessageHeader.typeChannel, "CHANNEL"),
            (MessageHeader.typePeerAnnouncement, "PEER_ANNOUNCEMENT"),
            (MessageHeader.typeAcknowledgment, "ACKNOWLEDGMENT"),
            (MessageHeader.typeKeyExchange, "KEY_EXCHANGE"),
            (MessageHeader.typeStoreForward, "STORE_FORWARD"),
            (MessageHeader.typeRoutingUpdate, "ROUTING_UPDATE")
        ]

        for (type, expectedString) in types {
            let header = MessageHeader(
                type: type,
                ttl: 7,
                hopCount: 0,
                messageId: 1,
                senderId: "AA:BB:CC:DD:EE:FF",
                payloadLength: 10
            )
            XCTAssertEqual(header.getTypeString(), expectedString, "Type string should match")
        }
    }

    func testDeserializeTooSmall() {
        // Try to deserialize data that's too small
        let smallData = Data(repeating: 0, count: 10)
        XCTAssertThrowsError(try MessageHeader.fromData(smallData)) { error in
            guard case MessageHeaderError.dataTooSmall = error else {
                XCTFail("Expected dataTooSmall error")
                return
            }
        }
    }

    func testInvalidProtocolVersion() {
        // Create a header with valid version first
        let header = MessageHeader(
            type: MessageHeader.typePublic,
            ttl: 7,
            hopCount: 0,
            messageId: 1,
            senderId: "AA:BB:CC:DD:EE:FF",
            payloadLength: 10
        )
        var data = header.toData()

        // Modify the version byte to be invalid
        data[0] = 0x99

        // Try to deserialize - should throw exception
        XCTAssertThrowsError(try MessageHeader.fromData(data)) { error in
            guard case MessageHeaderError.unsupportedVersion = error else {
                XCTFail("Expected unsupportedVersion error")
                return
            }
        }
    }

    func testMacAddressFormats() throws {
        // Test different MAC address formats
        let macAddresses = [
            "AA:BB:CC:DD:EE:FF",
            "00:11:22:33:44:55",
            "FF:FF:FF:FF:FF:FF",
            "00:00:00:00:00:00"
        ]

        for mac in macAddresses {
            let header = MessageHeader(
                type: MessageHeader.typePublic,
                ttl: 7,
                hopCount: 0,
                messageId: 1,
                senderId: mac,
                payloadLength: 10
            )

            let data = header.toData()
            let deserialized = try MessageHeader.fromData(data)

            XCTAssertEqual(mac, deserialized.senderId, "MAC address should match: \(mac)")
        }
    }

    func testToMap() {
        let header = MessageHeader(
            type: MessageHeader.typePublic,
            ttl: 7,
            hopCount: 2,
            messageId: 123456789,
            senderId: "AA:BB:CC:DD:EE:FF",
            payloadLength: 100
        )

        let map = header.toMap()

        XCTAssertEqual(map["version"] as? UInt8, 1, "Map should contain version")
        XCTAssertEqual(map["type"] as? UInt8, 1, "Map should contain type")
        XCTAssertEqual(map["ttl"] as? UInt8, 7, "Map should contain ttl")
        XCTAssertEqual(map["hopCount"] as? UInt8, 2, "Map should contain hopCount")
        XCTAssertEqual(map["messageId"] as? String, "123456789", "Map should contain messageId")
        XCTAssertEqual(map["senderId"] as? String, "AA:BB:CC:DD:EE:FF", "Map should contain senderId")
        XCTAssertEqual(map["payloadLength"] as? UInt16, 100, "Map should contain payloadLength")
    }

    func testMacStringToBytes() {
        // Test valid MAC address
        let mac = "AA:BB:CC:DD:EE:FF"
        let bytes = MessageHeader.macStringToBytes(mac)
        XCTAssertNotNil(bytes, "Should convert valid MAC address")
        XCTAssertEqual(bytes?.count, 6, "Should have 6 bytes")

        // Verify bytes
        let expected: [UInt8] = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
        for (index, expectedByte) in expected.enumerated() {
            XCTAssertEqual(bytes?[index], expectedByte, "Byte \(index) should match")
        }

        // Test invalid MAC address
        let invalidMac = "invalid"
        let invalidBytes = MessageHeader.macStringToBytes(invalidMac)
        XCTAssertNil(invalidBytes, "Should return nil for invalid MAC address")
    }

    func testMacBytesToString() {
        // Test bytes to string conversion
        let bytes = Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])
        let mac = MessageHeader.macBytesToString(bytes)
        XCTAssertEqual(mac, "AA:BB:CC:DD:EE:FF", "Should convert bytes to MAC string")

        // Test all zeros
        let zeros = Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        let zeroMac = MessageHeader.macBytesToString(zeros)
        XCTAssertEqual(zeroMac, "00:00:00:00:00:00", "Should convert zero bytes")

        // Test all FFs
        let ffs = Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
        let ffMac = MessageHeader.macBytesToString(ffs)
        XCTAssertEqual(ffMac, "FF:FF:FF:FF:FF:FF", "Should convert FF bytes")
    }
}

