package com.ble_mesh

import com.ble_mesh.models.Message
import com.ble_mesh.models.MessageHeader
import com.ble_mesh.models.MessageType
import com.ble_mesh.models.DeliveryStatus
import org.junit.Test
import org.junit.Assert.*

/**
 * Unit tests for Message serialization/deserialization
 */
class MessageSerializationTest {

    @Test
    fun testMessageSerialization() {
        // Create a test message
        val message = Message(
            senderId = "AA:BB:CC:DD:EE:FF",
            senderNickname = "Alice",
            content = "Hello, World!",
            type = MessageType.PUBLIC,
            status = DeliveryStatus.SENT,
            ttl = 7,
            hopCount = 0,
            messageId = 123456789L,
            isForwarded = false
        )

        // Serialize to bytes
        val bytes = message.toByteArray()

        // Verify size (20 bytes header + payload)
        val expectedSize = MessageHeader.HEADER_SIZE + "Hello, World!".toByteArray().size
        assertEquals("Message should be header + payload size", expectedSize, bytes.size)

        // Verify header is present (first 20 bytes)
        assertTrue("Should have at least header size", bytes.size >= MessageHeader.HEADER_SIZE)

        // Verify first byte is protocol version
        assertEquals("First byte should be protocol version", MessageHeader.PROTOCOL_VERSION, bytes[0])
    }

    @Test
    fun testMessageDeserialization() {
        // Create a test message
        val originalMessage = Message(
            senderId = "11:22:33:44:55:66",
            senderNickname = "Bob",
            content = "Test message",
            type = MessageType.PRIVATE,
            status = DeliveryStatus.DELIVERED,
            ttl = 5,
            hopCount = 2,
            messageId = 987654321L,
            isForwarded = true
        )

        // Serialize and deserialize
        val bytes = originalMessage.toByteArray()
        val deserializedMessage = Message.fromByteArray(bytes, "Bob")

        // Verify message is not null
        assertNotNull("Deserialized message should not be null", deserializedMessage)

        // Verify all routing fields match
        assertEquals("Sender ID should match", originalMessage.senderId, deserializedMessage!!.senderId)
        assertEquals("Content should match", originalMessage.content, deserializedMessage.content)
        assertEquals("Type should match", originalMessage.type, deserializedMessage.type)
        assertEquals("TTL should match", originalMessage.ttl, deserializedMessage.ttl)
        assertEquals("Hop count should match", originalMessage.hopCount, deserializedMessage.hopCount)
        assertEquals("Message ID should match", originalMessage.messageId, deserializedMessage.messageId)
        assertEquals("Is forwarded should match", originalMessage.isForwarded, deserializedMessage.isForwarded)
    }

    @Test
    fun testRoundTripSerialization() {
        // Test multiple messages to ensure consistency
        val testCases = listOf(
            Triple("Hello", MessageType.PUBLIC, 7),
            Triple("Private message", MessageType.PRIVATE, 5),
            Triple("Channel broadcast", MessageType.CHANNEL, 3),
            Triple("System notification", MessageType.SYSTEM, 1)
        )

        testCases.forEachIndexed { index, (content, type, ttl) ->
            val message = Message(
                senderId = "AA:BB:CC:DD:EE:FF",
                senderNickname = "TestUser$index",
                content = content,
                type = type,
                status = DeliveryStatus.SENT,
                ttl = ttl,
                hopCount = 0,
                messageId = MessageHeader.generateMessageId(),
                isForwarded = false
            )

            val bytes = message.toByteArray()
            val deserialized = Message.fromByteArray(bytes, "TestUser$index")

            assertNotNull("Test case $index: Deserialized message should not be null", deserialized)
            assertEquals("Test case $index: Content should match", content, deserialized!!.content)
            assertEquals("Test case $index: Type should match", type, deserialized.type)
            assertEquals("Test case $index: TTL should match", ttl, deserialized.ttl)
        }
    }

    @Test
    fun testEmptyMessage() {
        // Test message with empty content
        val message = Message(
            senderId = "AA:BB:CC:DD:EE:FF",
            senderNickname = "Alice",
            content = "",
            type = MessageType.PUBLIC,
            status = DeliveryStatus.SENT,
            ttl = 7,
            hopCount = 0,
            messageId = MessageHeader.generateMessageId(),
            isForwarded = false
        )

        val bytes = message.toByteArray()
        val deserialized = Message.fromByteArray(bytes, "Alice")

        assertNotNull("Deserialized message should not be null", deserialized)
        assertEquals("Empty content should be preserved", "", deserialized!!.content)
    }

    @Test
    fun testLongMessage() {
        // Test message with long content
        val longContent = "A".repeat(200)  // 200 characters
        val message = Message(
            senderId = "AA:BB:CC:DD:EE:FF",
            senderNickname = "Alice",
            content = longContent,
            type = MessageType.PUBLIC,
            status = DeliveryStatus.SENT,
            ttl = 7,
            hopCount = 0,
            messageId = MessageHeader.generateMessageId(),
            isForwarded = false
        )

        val bytes = message.toByteArray()
        val deserialized = Message.fromByteArray(bytes, "Alice")

        assertNotNull("Deserialized message should not be null", deserialized)
        assertEquals("Long content should be preserved", longContent, deserialized!!.content)
        assertEquals("Content length should match", 200, deserialized.content.length)
    }

    @Test
    fun testUnicodeContent() {
        // Test message with Unicode characters
        val unicodeContent = "Hello 世界 🌍 Привет مرحبا"
        val message = Message(
            senderId = "AA:BB:CC:DD:EE:FF",
            senderNickname = "Alice",
            content = unicodeContent,
            type = MessageType.PUBLIC,
            status = DeliveryStatus.SENT,
            ttl = 7,
            hopCount = 0,
            messageId = MessageHeader.generateMessageId(),
            isForwarded = false
        )

        val bytes = message.toByteArray()
        val deserialized = Message.fromByteArray(bytes, "Alice")

        assertNotNull("Deserialized message should not be null", deserialized)
        assertEquals("Unicode content should be preserved", unicodeContent, deserialized!!.content)
    }

    @Test
    fun testForwardedMessage() {
        // Test message that has been forwarded
        val message = Message(
            senderId = "AA:BB:CC:DD:EE:FF",
            senderNickname = "Alice",
            content = "Forwarded message",
            type = MessageType.PUBLIC,
            status = DeliveryStatus.SENT,
            ttl = 5,
            hopCount = 2,  // Forwarded 2 times
            messageId = MessageHeader.generateMessageId(),
            isForwarded = true
        )

        val bytes = message.toByteArray()
        val deserialized = Message.fromByteArray(bytes, "Alice")

        assertNotNull("Deserialized message should not be null", deserialized)
        assertEquals("Hop count should match", 2, deserialized!!.hopCount)
        assertTrue("Should be marked as forwarded", deserialized.isForwarded)
    }

    @Test
    fun testMessageWithDifferentTTL() {
        // Test messages with different TTL values
        val ttlValues = listOf(1, 3, 5, 7, 10)

        ttlValues.forEach { ttl ->
            val message = Message(
                senderId = "AA:BB:CC:DD:EE:FF",
                senderNickname = "Alice",
                content = "TTL test",
                type = MessageType.PUBLIC,
                status = DeliveryStatus.SENT,
                ttl = ttl,
                hopCount = 0,
                messageId = MessageHeader.generateMessageId(),
                isForwarded = false
            )

            val bytes = message.toByteArray()
            val deserialized = Message.fromByteArray(bytes, "Alice")

            assertNotNull("Deserialized message should not be null", deserialized)
            assertEquals("TTL=$ttl should be preserved", ttl, deserialized!!.ttl)
        }
    }

    @Test
    fun testMessageTypes() {
        // Test all message types
        val types = listOf(
            MessageType.PUBLIC,
            MessageType.PRIVATE,
            MessageType.CHANNEL,
            MessageType.SYSTEM
        )

        types.forEach { type ->
            val message = Message(
                senderId = "AA:BB:CC:DD:EE:FF",
                senderNickname = "Alice",
                content = "Type test",
                type = type,
                status = DeliveryStatus.SENT,
                ttl = 7,
                hopCount = 0,
                messageId = MessageHeader.generateMessageId(),
                isForwarded = false
            )

            val bytes = message.toByteArray()
            val deserialized = Message.fromByteArray(bytes, "Alice")

            assertNotNull("Deserialized message should not be null", deserialized)
            assertEquals("Type $type should be preserved", type, deserialized!!.type)
        }
    }

    @Test
    fun testInvalidData() {
        // Test deserialization with invalid data (too small)
        val invalidData = ByteArray(10)
        val message = Message.fromByteArray(invalidData, "Alice")

        assertNull("Should return null for invalid data", message)
    }

    @Test
    fun testCorruptedHeader() {
        // Create a valid message, then corrupt the header
        val message = Message(
            senderId = "AA:BB:CC:DD:EE:FF",
            senderNickname = "Alice",
            content = "Test",
            type = MessageType.PUBLIC,
            status = DeliveryStatus.SENT,
            ttl = 7,
            hopCount = 0,
            messageId = MessageHeader.generateMessageId(),
            isForwarded = false
        )

        val bytes = message.toByteArray()

        // Corrupt the version byte
        bytes[0] = 0x99.toByte()

        val deserialized = Message.fromByteArray(bytes, "Alice")

        assertNull("Should return null for corrupted header", deserialized)
    }

    @Test
    fun testMessageIdUniqueness() {
        // Test that different messages get different IDs
        val ids = mutableSetOf<Long>()

        repeat(100) {
            val message = Message(
                senderId = "AA:BB:CC:DD:EE:FF",
                senderNickname = "Alice",
                content = "Test $it",
                type = MessageType.PUBLIC,
                status = DeliveryStatus.SENT,
                ttl = 7,
                hopCount = 0,
                messageId = MessageHeader.generateMessageId(),
                isForwarded = false
            )

            ids.add(message.messageId)
        }

        assertEquals("All message IDs should be unique", 100, ids.size)
    }

    @Test
    fun testSpecialCharacters() {
        // Test message with special characters
        val specialContent = "Line1\nLine2\tTabbed\r\nWindows\"Quotes\"'Single'"
        val message = Message(
            senderId = "AA:BB:CC:DD:EE:FF",
            senderNickname = "Alice",
            content = specialContent,
            type = MessageType.PUBLIC,
            status = DeliveryStatus.SENT,
            ttl = 7,
            hopCount = 0,
            messageId = MessageHeader.generateMessageId(),
            isForwarded = false
        )

        val bytes = message.toByteArray()
        val deserialized = Message.fromByteArray(bytes, "Alice")

        assertNotNull("Deserialized message should not be null", deserialized)
        assertEquals("Special characters should be preserved", specialContent, deserialized!!.content)
    }

    @Test
    fun testToMap() {
        // Test that toMap includes routing fields
        val message = Message(
            senderId = "AA:BB:CC:DD:EE:FF",
            senderNickname = "Alice",
            content = "Test",
            type = MessageType.PUBLIC,
            status = DeliveryStatus.SENT,
            ttl = 7,
            hopCount = 2,
            messageId = 123456789L,
            isForwarded = true
        )

        val map = message.toMap()

        assertEquals("Map should contain ttl", 7, map["ttl"])
        assertEquals("Map should contain hopCount", 2, map["hopCount"])
        assertEquals("Map should contain messageId", "123456789", map["messageId"])
        assertEquals("Map should contain isForwarded", true, map["isForwarded"])
    }

    @Test
    fun testSystemMessageSerializesToKeyExchangeHeaderType() {
        // Verify SYSTEM type messages use TYPE_KEY_EXCHANGE (0x06) in the header
        val message = Message(
            senderId = "AA:BB:CC:DD:EE:FF",
            senderNickname = "Alice",
            content = "Public key data",
            type = MessageType.SYSTEM,
            status = DeliveryStatus.SENT,
            ttl = 1,
            hopCount = 0,
            messageId = MessageHeader.generateMessageId(),
            isForwarded = false
        )

        val bytes = message.toByteArray()

        // Verify header type byte (second byte) is TYPE_KEY_EXCHANGE (0x06)
        assertEquals(
            "SYSTEM message should serialize to TYPE_KEY_EXCHANGE header",
            MessageHeader.TYPE_KEY_EXCHANGE,
            bytes[1]
        )
    }

    @Test
    fun testKeyExchangeHeaderTypeDeserializesToSystem() {
        // Create a message with SYSTEM type, serialize, then deserialize
        val originalMessage = Message(
            senderId = "AA:BB:CC:DD:EE:FF",
            senderNickname = "Alice",
            content = "Key exchange content",
            type = MessageType.SYSTEM,
            status = DeliveryStatus.SENT,
            ttl = 1,
            hopCount = 0,
            messageId = 123456789L,
            isForwarded = false
        )

        val bytes = originalMessage.toByteArray()
        val deserializedMessage = Message.fromByteArray(bytes, "Alice")

        assertNotNull("Deserialized message should not be null", deserializedMessage)
        assertEquals(
            "TYPE_KEY_EXCHANGE header should deserialize to SYSTEM type",
            MessageType.SYSTEM,
            deserializedMessage!!.type
        )
    }

    @Test
    fun testSystemMessageRoundTrip() {
        // Complete round-trip test for SYSTEM message type
        val originalMessage = Message(
            senderId = "11:22:33:44:55:66",
            senderNickname = "KeyExchangePeer",
            content = "",  // Empty content typical for key exchange
            type = MessageType.SYSTEM,
            status = DeliveryStatus.SENT,
            ttl = 1,  // Key exchange shouldn't be forwarded
            hopCount = 0,
            messageId = MessageHeader.generateMessageId(),
            isForwarded = false
        )

        // Serialize
        val bytes = originalMessage.toByteArray()

        // Verify header byte
        assertEquals("Header type should be KEY_EXCHANGE", MessageHeader.TYPE_KEY_EXCHANGE, bytes[1])

        // Deserialize
        val deserializedMessage = Message.fromByteArray(bytes, "KeyExchangePeer")

        // Verify complete round trip
        assertNotNull("Deserialized message should not be null", deserializedMessage)
        assertEquals("Type should be SYSTEM after round trip", MessageType.SYSTEM, deserializedMessage!!.type)
        assertEquals("Sender ID should match", originalMessage.senderId, deserializedMessage.senderId)
        assertEquals("Content should match", originalMessage.content, deserializedMessage.content)
        assertEquals("TTL should match", originalMessage.ttl, deserializedMessage.ttl)
    }

    @Test
    fun testToMapPreservesSystemType() {
        // Verify toMap correctly serializes SYSTEM type for Flutter
        val message = Message(
            senderId = "AA:BB:CC:DD:EE:FF",
            senderNickname = "Alice",
            content = "System message",
            type = MessageType.SYSTEM,
            status = DeliveryStatus.SENT,
            ttl = 1,
            hopCount = 0,
            messageId = 123456789L,
            isForwarded = false
        )

        val map = message.toMap()

        // SYSTEM has value 3 in the MessageType enum
        assertEquals("Map should contain type value 3 for SYSTEM", 3, map["type"])
    }
}

