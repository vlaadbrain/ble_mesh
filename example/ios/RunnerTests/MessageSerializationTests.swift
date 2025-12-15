import XCTest
@testable import ble_mesh

/**
 * Unit tests for Message serialization/deserialization
 */
class MessageSerializationTests: XCTestCase {

    func testMessageSerialization() {
        // Create a test message
        let message = Message(
            senderId: "AA:BB:CC:DD:EE:FF",
            senderNickname: "Alice",
            content: "Hello, World!",
            type: .publicMessage,
            status: .sent,
            ttl: 7,
            hopCount: 0,
            messageId: 123456789,
            isForwarded: false
        )

        // Serialize to data
        let data = message.toData()

        // Verify size (20 bytes header + payload)
        let payloadSize = "Hello, World!".data(using: .utf8)!.count
        let expectedSize = MessageHeader.headerSize + payloadSize
        XCTAssertEqual(data.count, expectedSize, "Message should be header + payload size")

        // Verify header is present (first 20 bytes)
        XCTAssertGreaterThanOrEqual(data.count, MessageHeader.headerSize, "Should have at least header size")

        // Verify first byte is protocol version
        XCTAssertEqual(data[0], MessageHeader.protocolVersion, "First byte should be protocol version")
    }

    func testMessageDeserialization() {
        // Create a test message
        let originalMessage = Message(
            senderId: "11:22:33:44:55:66",
            senderNickname: "Bob",
            content: "Test message",
            type: .privateMessage,
            status: .delivered,
            ttl: 5,
            hopCount: 2,
            messageId: 987654321,
            isForwarded: true
        )

        // Serialize and deserialize
        let data = originalMessage.toData()
        let deserializedMessage = Message.fromData(data, senderNickname: "Bob")

        // Verify message is not nil
        XCTAssertNotNil(deserializedMessage, "Deserialized message should not be nil")

        // Verify all routing fields match
        XCTAssertEqual(deserializedMessage!.senderId, originalMessage.senderId, "Sender ID should match")
        XCTAssertEqual(deserializedMessage!.content, originalMessage.content, "Content should match")
        XCTAssertEqual(deserializedMessage!.type, originalMessage.type, "Type should match")
        XCTAssertEqual(deserializedMessage!.ttl, originalMessage.ttl, "TTL should match")
        XCTAssertEqual(deserializedMessage!.hopCount, originalMessage.hopCount, "Hop count should match")
        XCTAssertEqual(deserializedMessage!.messageId, originalMessage.messageId, "Message ID should match")
        XCTAssertEqual(deserializedMessage!.isForwarded, originalMessage.isForwarded, "Is forwarded should match")
    }

    func testRoundTripSerialization() {
        // Test multiple messages to ensure consistency
        let testCases: [(String, MessageType, Int)] = [
            ("Hello", .publicMessage, 7),
            ("Private message", .privateMessage, 5),
            ("Channel broadcast", .channel, 3),
            ("System notification", .system, 1)
        ]

        for (index, testCase) in testCases.enumerated() {
            let (content, type, ttl) = testCase
            let message = Message(
                senderId: "AA:BB:CC:DD:EE:FF",
                senderNickname: "TestUser\(index)",
                content: content,
                type: type,
                status: .sent,
                ttl: ttl,
                hopCount: 0,
                messageId: MessageHeader.generateMessageId(),
                isForwarded: false
            )

            let data = message.toData()
            let deserialized = Message.fromData(data, senderNickname: "TestUser\(index)")

            XCTAssertNotNil(deserialized, "Test case \(index): Deserialized message should not be nil")
            XCTAssertEqual(deserialized!.content, content, "Test case \(index): Content should match")
            XCTAssertEqual(deserialized!.type, type, "Test case \(index): Type should match")
            XCTAssertEqual(deserialized!.ttl, ttl, "Test case \(index): TTL should match")
        }
    }

    func testEmptyMessage() {
        // Test message with empty content
        let message = Message(
            senderId: "AA:BB:CC:DD:EE:FF",
            senderNickname: "Alice",
            content: "",
            type: .publicMessage,
            status: .sent,
            ttl: 7,
            hopCount: 0,
            messageId: MessageHeader.generateMessageId(),
            isForwarded: false
        )

        let data = message.toData()
        let deserialized = Message.fromData(data, senderNickname: "Alice")

        XCTAssertNotNil(deserialized, "Deserialized message should not be nil")
        XCTAssertEqual(deserialized!.content, "", "Empty content should be preserved")
    }

    func testLongMessage() {
        // Test message with long content
        let longContent = String(repeating: "A", count: 200)  // 200 characters
        let message = Message(
            senderId: "AA:BB:CC:DD:EE:FF",
            senderNickname: "Alice",
            content: longContent,
            type: .publicMessage,
            status: .sent,
            ttl: 7,
            hopCount: 0,
            messageId: MessageHeader.generateMessageId(),
            isForwarded: false
        )

        let data = message.toData()
        let deserialized = Message.fromData(data, senderNickname: "Alice")

        XCTAssertNotNil(deserialized, "Deserialized message should not be nil")
        XCTAssertEqual(deserialized!.content, longContent, "Long content should be preserved")
        XCTAssertEqual(deserialized!.content.count, 200, "Content length should match")
    }

    func testUnicodeContent() {
        // Test message with Unicode characters
        let unicodeContent = "Hello 世界 🌍 Привет مرحبا"
        let message = Message(
            senderId: "AA:BB:CC:DD:EE:FF",
            senderNickname: "Alice",
            content: unicodeContent,
            type: .publicMessage,
            status: .sent,
            ttl: 7,
            hopCount: 0,
            messageId: MessageHeader.generateMessageId(),
            isForwarded: false
        )

        let data = message.toData()
        let deserialized = Message.fromData(data, senderNickname: "Alice")

        XCTAssertNotNil(deserialized, "Deserialized message should not be nil")
        XCTAssertEqual(deserialized!.content, unicodeContent, "Unicode content should be preserved")
    }

    func testForwardedMessage() {
        // Test message that has been forwarded
        let message = Message(
            senderId: "AA:BB:CC:DD:EE:FF",
            senderNickname: "Alice",
            content: "Forwarded message",
            type: .publicMessage,
            status: .sent,
            ttl: 5,
            hopCount: 2,  // Forwarded 2 times
            messageId: MessageHeader.generateMessageId(),
            isForwarded: true
        )

        let data = message.toData()
        let deserialized = Message.fromData(data, senderNickname: "Alice")

        XCTAssertNotNil(deserialized, "Deserialized message should not be nil")
        XCTAssertEqual(deserialized!.hopCount, 2, "Hop count should match")
        XCTAssertTrue(deserialized!.isForwarded, "Should be marked as forwarded")
    }

    func testMessageWithDifferentTTL() {
        // Test messages with different TTL values
        let ttlValues = [1, 3, 5, 7, 10]

        for ttl in ttlValues {
            let message = Message(
                senderId: "AA:BB:CC:DD:EE:FF",
                senderNickname: "Alice",
                content: "TTL test",
                type: .publicMessage,
                status: .sent,
                ttl: ttl,
                hopCount: 0,
                messageId: MessageHeader.generateMessageId(),
                isForwarded: false
            )

            let data = message.toData()
            let deserialized = Message.fromData(data, senderNickname: "Alice")

            XCTAssertNotNil(deserialized, "Deserialized message should not be nil")
            XCTAssertEqual(deserialized!.ttl, ttl, "TTL=\(ttl) should be preserved")
        }
    }

    func testMessageTypes() {
        // Test all message types
        let types: [MessageType] = [
            .publicMessage,
            .privateMessage,
            .channel,
            .system
        ]

        for type in types {
            let message = Message(
                senderId: "AA:BB:CC:DD:EE:FF",
                senderNickname: "Alice",
                content: "Type test",
                type: type,
                status: .sent,
                ttl: 7,
                hopCount: 0,
                messageId: MessageHeader.generateMessageId(),
                isForwarded: false
            )

            let data = message.toData()
            let deserialized = Message.fromData(data, senderNickname: "Alice")

            XCTAssertNotNil(deserialized, "Deserialized message should not be nil")
            XCTAssertEqual(deserialized!.type, type, "Type \(type) should be preserved")
        }
    }

    func testInvalidData() {
        // Test deserialization with invalid data (too small)
        let invalidData = Data(repeating: 0, count: 10)
        let message = Message.fromData(invalidData, senderNickname: "Alice")

        XCTAssertNil(message, "Should return nil for invalid data")
    }

    func testCorruptedHeader() {
        // Create a valid message, then corrupt the header
        let message = Message(
            senderId: "AA:BB:CC:DD:EE:FF",
            senderNickname: "Alice",
            content: "Test",
            type: .publicMessage,
            status: .sent,
            ttl: 7,
            hopCount: 0,
            messageId: MessageHeader.generateMessageId(),
            isForwarded: false
        )

        var data = message.toData()

        // Corrupt the version byte
        data[0] = 0x99

        let deserialized = Message.fromData(data, senderNickname: "Alice")

        XCTAssertNil(deserialized, "Should return nil for corrupted header")
    }

    func testMessageIdUniqueness() {
        // Test that different messages get different IDs
        var ids = Set<Int64>()

        for i in 0..<100 {
            let message = Message(
                senderId: "AA:BB:CC:DD:EE:FF",
                senderNickname: "Alice",
                content: "Test \(i)",
                type: .publicMessage,
                status: .sent,
                ttl: 7,
                hopCount: 0,
                messageId: MessageHeader.generateMessageId(),
                isForwarded: false
            )

            ids.insert(message.messageId)
        }

        XCTAssertEqual(ids.count, 100, "All message IDs should be unique")
    }

    func testSpecialCharacters() {
        // Test message with special characters
        let specialContent = "Line1\nLine2\tTabbed\r\nWindows\"Quotes\"'Single'"
        let message = Message(
            senderId: "AA:BB:CC:DD:EE:FF",
            senderNickname: "Alice",
            content: specialContent,
            type: .publicMessage,
            status: .sent,
            ttl: 7,
            hopCount: 0,
            messageId: MessageHeader.generateMessageId(),
            isForwarded: false
        )

        let data = message.toData()
        let deserialized = Message.fromData(data, senderNickname: "Alice")

        XCTAssertNotNil(deserialized, "Deserialized message should not be nil")
        XCTAssertEqual(deserialized!.content, specialContent, "Special characters should be preserved")
    }

    func testToMap() {
        // Test that toMap includes routing fields
        let message = Message(
            senderId: "AA:BB:CC:DD:EE:FF",
            senderNickname: "Alice",
            content: "Test",
            type: .publicMessage,
            status: .sent,
            ttl: 7,
            hopCount: 2,
            messageId: 123456789,
            isForwarded: true
        )

        let map = message.toMap()

        XCTAssertEqual(map["ttl"] as? Int, 7, "Map should contain ttl")
        XCTAssertEqual(map["hopCount"] as? Int, 2, "Map should contain hopCount")
        XCTAssertEqual(map["messageId"] as? String, "123456789", "Map should contain messageId")
        XCTAssertEqual(map["isForwarded"] as? Bool, true, "Map should contain isForwarded")
    }
}

