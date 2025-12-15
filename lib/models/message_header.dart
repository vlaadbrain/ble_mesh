import 'dart:typed_data';
import 'dart:math';

/// Message header for Phase 2 routing
///
/// Binary format (20 bytes total):
/// - Version (1 byte): Protocol version (0x01)
/// - Type (1 byte): Message type
/// - TTL (1 byte): Time-to-live (hops remaining)
/// - Hop Count (1 byte): Number of hops taken
/// - Message ID (8 bytes): Unique message identifier
/// - Sender ID (6 bytes): Original sender MAC address
/// - Payload Length (2 bytes): Length of payload data
class MessageHeader {
  final int version;
  int ttl;
  int hopCount;
  final int type;
  final int messageId;
  final String senderId; // MAC address as string (e.g., "AA:BB:CC:DD:EE:FF")
  final int payloadLength;

  // Constants
  static const int protocolVersion = 0x01;
  static const int headerSize = 20; // bytes

  // Message type constants
  static const int typePublic = 0x01;
  static const int typePrivate = 0x02;
  static const int typeChannel = 0x03;
  static const int typePeerAnnouncement = 0x04;
  static const int typeAcknowledgment = 0x05;
  static const int typeKeyExchange = 0x06;
  static const int typeStoreForward = 0x07;
  static const int typeRoutingUpdate = 0x08;

  MessageHeader({
    this.version = protocolVersion,
    required this.type,
    required this.ttl,
    required this.hopCount,
    required this.messageId,
    required this.senderId,
    required this.payloadLength,
  });

  /// Generate a unique message ID using timestamp + random
  static int generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(0x7FFFFFFF); // Max 32-bit signed int
    return (timestamp << 32) | (random & 0xFFFFFFFF);
  }

  /// Serialize header to bytes (20 bytes, big-endian)
  Uint8List toBytes() {
    final buffer = ByteData(headerSize);
    var offset = 0;

    // Write version (1 byte)
    buffer.setUint8(offset, version);
    offset += 1;

    // Write type (1 byte)
    buffer.setUint8(offset, type);
    offset += 1;

    // Write TTL (1 byte)
    buffer.setUint8(offset, ttl);
    offset += 1;

    // Write hop count (1 byte)
    buffer.setUint8(offset, hopCount);
    offset += 1;

    // Write message ID (8 bytes, big-endian)
    buffer.setInt64(offset, messageId, Endian.big);
    offset += 8;

    // Write sender ID (6 bytes MAC address)
    final senderBytes = _macStringToBytes(senderId);
    for (var i = 0; i < 6; i++) {
      buffer.setUint8(offset + i, senderBytes[i]);
    }
    offset += 6;

    // Write payload length (2 bytes, big-endian)
    buffer.setUint16(offset, payloadLength, Endian.big);

    return buffer.buffer.asUint8List();
  }

  /// Deserialize header from bytes
  ///
  /// Throws [ArgumentError] if data is too small or invalid
  static MessageHeader fromBytes(Uint8List data) {
    if (data.length < headerSize) {
      throw ArgumentError(
        'Data too small for header: ${data.length} < $headerSize',
      );
    }

    final buffer = ByteData.sublistView(data);
    var offset = 0;

    // Read version (1 byte)
    final version = buffer.getUint8(offset);
    offset += 1;

    // Validate version
    if (version != protocolVersion) {
      throw ArgumentError('Unsupported protocol version: $version');
    }

    // Read type (1 byte)
    final type = buffer.getUint8(offset);
    offset += 1;

    // Read TTL (1 byte)
    final ttl = buffer.getUint8(offset);
    offset += 1;

    // Read hop count (1 byte)
    final hopCount = buffer.getUint8(offset);
    offset += 1;

    // Read message ID (8 bytes, big-endian)
    final messageId = buffer.getInt64(offset, Endian.big);
    offset += 8;

    // Read sender ID (6 bytes MAC address)
    final senderBytes = data.sublist(offset, offset + 6);
    final senderId = _macBytesToString(senderBytes);
    offset += 6;

    // Read payload length (2 bytes, big-endian)
    final payloadLength = buffer.getUint16(offset, Endian.big);

    return MessageHeader(
      version: version,
      type: type,
      ttl: ttl,
      hopCount: hopCount,
      messageId: messageId,
      senderId: senderId,
      payloadLength: payloadLength,
    );
  }

  /// Convert MAC address string to bytes
  /// Example: "AA:BB:CC:DD:EE:FF" -> [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
  static Uint8List _macStringToBytes(String mac) {
    final parts = mac.split(':');
    if (parts.length != 6) {
      throw ArgumentError('Invalid MAC address format: $mac');
    }

    final bytes = Uint8List(6);
    for (var i = 0; i < 6; i++) {
      bytes[i] = int.parse(parts[i], radix: 16);
    }
    return bytes;
  }

  /// Convert MAC address bytes to string
  /// Example: [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF] -> "AA:BB:CC:DD:EE:FF"
  static String _macBytesToString(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
  }

  /// Check if message can be forwarded
  /// Message can be forwarded if TTL > 1 (will be > 0 after decrement)
  bool canForward() {
    return ttl > 1;
  }

  /// Decrement TTL and increment hop count for forwarding
  /// Should be called before forwarding message to next hop
  void prepareForForward() {
    if (ttl > 0) {
      ttl -= 1;
    }
    hopCount += 1;
  }

  /// Get message type as string for logging
  String getTypeString() {
    switch (type) {
      case typePublic:
        return 'PUBLIC';
      case typePrivate:
        return 'PRIVATE';
      case typeChannel:
        return 'CHANNEL';
      case typePeerAnnouncement:
        return 'PEER_ANNOUNCEMENT';
      case typeAcknowledgment:
        return 'ACKNOWLEDGMENT';
      case typeKeyExchange:
        return 'KEY_EXCHANGE';
      case typeStoreForward:
        return 'STORE_FORWARD';
      case typeRoutingUpdate:
        return 'ROUTING_UPDATE';
      default:
        return 'UNKNOWN($type)';
    }
  }

  /// Convert to map for debugging/logging
  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'type': type,
      'ttl': ttl,
      'hopCount': hopCount,
      'messageId': messageId.toString(),
      'senderId': senderId,
      'payloadLength': payloadLength,
    };
  }

  /// Create from map (for method channel deserialization)
  factory MessageHeader.fromMap(Map<String, dynamic> map) {
    return MessageHeader(
      version: map['version'] as int? ?? protocolVersion,
      type: map['type'] as int,
      ttl: map['ttl'] as int,
      hopCount: map['hopCount'] as int,
      messageId: int.parse(map['messageId'] as String),
      senderId: map['senderId'] as String,
      payloadLength: map['payloadLength'] as int,
    );
  }

  @override
  String toString() {
    return 'MessageHeader(version=$version, type=${getTypeString()}, ttl=$ttl, '
        'hopCount=$hopCount, messageId=$messageId, senderId=$senderId, '
        'payloadLength=$payloadLength)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageHeader &&
        other.version == version &&
        other.type == type &&
        other.ttl == ttl &&
        other.hopCount == hopCount &&
        other.messageId == messageId &&
        other.senderId == senderId &&
        other.payloadLength == payloadLength;
  }

  @override
  int get hashCode {
    return Object.hash(
      version,
      type,
      ttl,
      hopCount,
      messageId,
      senderId,
      payloadLength,
    );
  }
}

