package com.ble_mesh

import com.ble_mesh.models.MessageHeader
import org.junit.Test
import org.junit.Assert.*

/**
 * Unit tests for MessageHeader serialization/deserialization
 */
class MessageHeaderTest {

    @Test
    fun testHeaderSerialization() {
        // Create a test header
        val messageId = MessageHeader.generateMessageId()
        val senderId = "AA:BB:CC:DD:EE:FF"
        val header = MessageHeader(
            version = MessageHeader.PROTOCOL_VERSION,
            type = MessageHeader.TYPE_PUBLIC,
            ttl = 7,
            hopCount = 0,
            messageId = messageId,
            senderId = senderId,
            payloadLength = 13
        )

        // Serialize to bytes
        val bytes = header.toByteArray()

        // Verify size
        assertEquals("Header should be 20 bytes", MessageHeader.HEADER_SIZE, bytes.size)

        // Verify first byte is protocol version
        assertEquals("First byte should be protocol version", MessageHeader.PROTOCOL_VERSION, bytes[0])

        // Verify second byte is message type
        assertEquals("Second byte should be message type", MessageHeader.TYPE_PUBLIC, bytes[1])

        // Verify TTL
        assertEquals("Third byte should be TTL", 7.toByte(), bytes[2])

        // Verify hop count
        assertEquals("Fourth byte should be hop count", 0.toByte(), bytes[3])
    }

    @Test
    fun testHeaderDeserialization() {
        // Create a test header
        val messageId = 123456789L
        val senderId = "11:22:33:44:55:66"
        val header = MessageHeader(
            version = MessageHeader.PROTOCOL_VERSION,
            type = MessageHeader.TYPE_CHANNEL,
            ttl = 5,
            hopCount = 2,
            messageId = messageId,
            senderId = senderId,
            payloadLength = 100
        )

        // Serialize and deserialize
        val bytes = header.toByteArray()
        val deserialized = MessageHeader.fromByteArray(bytes)

        // Verify all fields match
        assertEquals("Version should match", header.version, deserialized.version)
        assertEquals("Type should match", header.type, deserialized.type)
        assertEquals("TTL should match", header.ttl, deserialized.ttl)
        assertEquals("Hop count should match", header.hopCount, deserialized.hopCount)
        assertEquals("Message ID should match", header.messageId, deserialized.messageId)
        assertEquals("Sender ID should match", header.senderId, deserialized.senderId)
        assertEquals("Payload length should match", header.payloadLength, deserialized.payloadLength)
    }

    @Test
    fun testRoundTripSerialization() {
        // Test multiple headers to ensure consistency
        val testCases = listOf(
            Triple(MessageHeader.TYPE_PUBLIC, "AA:BB:CC:DD:EE:FF", 7.toByte()),
            Triple(MessageHeader.TYPE_PRIVATE, "11:22:33:44:55:66", 5.toByte()),
            Triple(MessageHeader.TYPE_CHANNEL, "FF:EE:DD:CC:BB:AA", 3.toByte()),
            Triple(MessageHeader.TYPE_PEER_ANNOUNCEMENT, "00:11:22:33:44:55", 1.toByte())
        )

        testCases.forEachIndexed { index, (type, senderId, ttl) ->
            val header = MessageHeader(
                type = type,
                ttl = ttl,
                hopCount = 0,
                messageId = MessageHeader.generateMessageId(),
                senderId = senderId,
                payloadLength = (index * 10).toShort()
            )

            val bytes = header.toByteArray()
            val deserialized = MessageHeader.fromByteArray(bytes)

            assertEquals("Test case $index: Type should match", header.type, deserialized.type)
            assertEquals("Test case $index: TTL should match", header.ttl, deserialized.ttl)
            assertEquals("Test case $index: Sender ID should match", header.senderId, deserialized.senderId)
            assertEquals("Test case $index: Payload length should match", header.payloadLength, deserialized.payloadLength)
        }
    }

    @Test
    fun testPrepareForForward() {
        val header = MessageHeader(
            type = MessageHeader.TYPE_PUBLIC,
            ttl = 7,
            hopCount = 0,
            messageId = 12345L,
            senderId = "AA:BB:CC:DD:EE:FF",
            payloadLength = 10
        )

        // Initial state
        assertEquals("Initial TTL should be 7", 7.toByte(), header.ttl)
        assertEquals("Initial hop count should be 0", 0.toByte(), header.hopCount)
        assertTrue("Should be able to forward", header.canForward())

        // After preparing for forward
        header.prepareForForward()
        assertEquals("TTL should be decremented to 6", 6.toByte(), header.ttl)
        assertEquals("Hop count should be incremented to 1", 1.toByte(), header.hopCount)
        assertTrue("Should still be able to forward", header.canForward())

        // Forward multiple times
        repeat(5) {
            header.prepareForForward()
        }
        assertEquals("TTL should be 1 after 6 forwards", 1.toByte(), header.ttl)
        assertEquals("Hop count should be 6", 6.toByte(), header.hopCount)
        assertFalse("Should not be able to forward (TTL=1)", header.canForward())
    }

    @Test
    fun testCanForward() {
        // TTL > 1: Can forward
        val header1 = MessageHeader(
            type = MessageHeader.TYPE_PUBLIC,
            ttl = 2,
            hopCount = 0,
            messageId = 1L,
            senderId = "AA:BB:CC:DD:EE:FF",
            payloadLength = 10
        )
        assertTrue("TTL=2 should be able to forward", header1.canForward())

        // TTL = 1: Cannot forward (would become 0)
        val header2 = MessageHeader(
            type = MessageHeader.TYPE_PUBLIC,
            ttl = 1,
            hopCount = 0,
            messageId = 2L,
            senderId = "AA:BB:CC:DD:EE:FF",
            payloadLength = 10
        )
        assertFalse("TTL=1 should not be able to forward", header2.canForward())

        // TTL = 0: Cannot forward
        val header3 = MessageHeader(
            type = MessageHeader.TYPE_PUBLIC,
            ttl = 0,
            hopCount = 5,
            messageId = 3L,
            senderId = "AA:BB:CC:DD:EE:FF",
            payloadLength = 10
        )
        assertFalse("TTL=0 should not be able to forward", header3.canForward())
    }

    @Test
    fun testMessageIdGeneration() {
        // Generate multiple IDs and ensure they're unique
        val ids = mutableSetOf<Long>()
        repeat(1000) {
            val id = MessageHeader.generateMessageId()
            assertFalse("Message ID should be unique", ids.contains(id))
            ids.add(id)
        }
        assertEquals("Should have generated 1000 unique IDs", 1000, ids.size)
    }

    @Test
    fun testGetTypeString() {
        val types = mapOf(
            MessageHeader.TYPE_PUBLIC to "PUBLIC",
            MessageHeader.TYPE_PRIVATE to "PRIVATE",
            MessageHeader.TYPE_CHANNEL to "CHANNEL",
            MessageHeader.TYPE_PEER_ANNOUNCEMENT to "PEER_ANNOUNCEMENT",
            MessageHeader.TYPE_ACKNOWLEDGMENT to "ACKNOWLEDGMENT",
            MessageHeader.TYPE_KEY_EXCHANGE to "KEY_EXCHANGE",
            MessageHeader.TYPE_STORE_FORWARD to "STORE_FORWARD",
            MessageHeader.TYPE_ROUTING_UPDATE to "ROUTING_UPDATE"
        )

        types.forEach { (type, expectedString) ->
            val header = MessageHeader(
                type = type,
                ttl = 7,
                hopCount = 0,
                messageId = 1L,
                senderId = "AA:BB:CC:DD:EE:FF",
                payloadLength = 10
            )
            assertEquals("Type string should match", expectedString, header.getTypeString())
        }
    }

    @Test(expected = IllegalArgumentException::class)
    fun testDeserializeTooSmall() {
        // Try to deserialize data that's too small
        val smallData = ByteArray(10)
        MessageHeader.fromByteArray(smallData)
    }

    @Test(expected = IllegalArgumentException::class)
    fun testInvalidProtocolVersion() {
        // Create a header with invalid version
        val header = MessageHeader(
            version = 0x99.toByte(),  // Invalid version
            type = MessageHeader.TYPE_PUBLIC,
            ttl = 7,
            hopCount = 0,
            messageId = 1L,
            senderId = "AA:BB:CC:DD:EE:FF",
            payloadLength = 10
        )
        val bytes = header.toByteArray()

        // Try to deserialize - should throw exception
        MessageHeader.fromByteArray(bytes)
    }

    @Test
    fun testMacAddressFormats() {
        // Test different MAC address formats
        val macAddresses = listOf(
            "AA:BB:CC:DD:EE:FF",
            "00:11:22:33:44:55",
            "FF:FF:FF:FF:FF:FF",
            "00:00:00:00:00:00"
        )

        macAddresses.forEach { mac ->
            val header = MessageHeader(
                type = MessageHeader.TYPE_PUBLIC,
                ttl = 7,
                hopCount = 0,
                messageId = 1L,
                senderId = mac,
                payloadLength = 10
            )

            val bytes = header.toByteArray()
            val deserialized = MessageHeader.fromByteArray(bytes)

            assertEquals("MAC address should match: $mac", mac, deserialized.senderId)
        }
    }

    @Test
    fun testToMap() {
        val header = MessageHeader(
            type = MessageHeader.TYPE_PUBLIC,
            ttl = 7,
            hopCount = 2,
            messageId = 123456789L,
            senderId = "AA:BB:CC:DD:EE:FF",
            payloadLength = 100
        )

        val map = header.toMap()

        assertEquals("Map should contain version", 1, map["version"])
        assertEquals("Map should contain type", 1, map["type"])
        assertEquals("Map should contain ttl", 7, map["ttl"])
        assertEquals("Map should contain hopCount", 2, map["hopCount"])
        assertEquals("Map should contain messageId", "123456789", map["messageId"])
        assertEquals("Map should contain senderId", "AA:BB:CC:DD:EE:FF", map["senderId"])
        assertEquals("Map should contain payloadLength", 100, map["payloadLength"])
    }

    @Test
    fun testKeyExchangeTypeRoundTrip() {
        // Test that TYPE_KEY_EXCHANGE (used for SYSTEM messages) serializes correctly
        val header = MessageHeader(
            type = MessageHeader.TYPE_KEY_EXCHANGE,
            ttl = 1,
            hopCount = 0,
            messageId = MessageHeader.generateMessageId(),
            senderId = "AA:BB:CC:DD:EE:FF",
            payloadLength = 32
        )

        val bytes = header.toByteArray()
        val deserialized = MessageHeader.fromByteArray(bytes)

        assertEquals("TYPE_KEY_EXCHANGE should be preserved", MessageHeader.TYPE_KEY_EXCHANGE, deserialized.type)
        assertEquals("Type string should be KEY_EXCHANGE", "KEY_EXCHANGE", deserialized.getTypeString())
    }

    @Test
    fun testAllMessageTypeConstants() {
        // Verify all message type constants have expected values
        assertEquals("TYPE_PUBLIC should be 0x01", 0x01.toByte(), MessageHeader.TYPE_PUBLIC)
        assertEquals("TYPE_PRIVATE should be 0x02", 0x02.toByte(), MessageHeader.TYPE_PRIVATE)
        assertEquals("TYPE_CHANNEL should be 0x03", 0x03.toByte(), MessageHeader.TYPE_CHANNEL)
        assertEquals("TYPE_PEER_ANNOUNCEMENT should be 0x04", 0x04.toByte(), MessageHeader.TYPE_PEER_ANNOUNCEMENT)
        assertEquals("TYPE_ACKNOWLEDGMENT should be 0x05", 0x05.toByte(), MessageHeader.TYPE_ACKNOWLEDGMENT)
        assertEquals("TYPE_KEY_EXCHANGE should be 0x06", 0x06.toByte(), MessageHeader.TYPE_KEY_EXCHANGE)
        assertEquals("TYPE_STORE_FORWARD should be 0x07", 0x07.toByte(), MessageHeader.TYPE_STORE_FORWARD)
        assertEquals("TYPE_ROUTING_UPDATE should be 0x08", 0x08.toByte(), MessageHeader.TYPE_ROUTING_UPDATE)
    }
}

