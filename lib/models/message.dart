/// Type of message
enum MessageType {
  /// Public message broadcast to all peers
  public,

  /// Private encrypted message to a specific peer
  private,

  /// Message sent to a channel
  channel,

  /// System message
  system,
}

/// Delivery status of a message
enum DeliveryStatus {
  /// Message is pending transmission
  pending,

  /// Message has been sent
  sent,

  /// Message has been delivered to recipient
  delivered,

  /// Message delivery failed
  failed,
}

/// Represents a message in the mesh network
class Message {
  /// Unique identifier for the message
  final String id;

  /// ID of the sender peer
  final String senderId;

  /// Nickname of the sender
  final String senderNickname;

  /// Message content
  final String content;

  /// Type of message
  final MessageType type;

  /// Timestamp when message was created
  final DateTime timestamp;

  /// Channel name (if type is channel)
  final String? channel;

  /// Whether the message is encrypted
  final bool isEncrypted;

  /// Delivery status
  final DeliveryStatus status;

  /// Phase 2: Time-to-live (hops remaining)
  final int ttl;

  /// Phase 2: Number of hops taken
  final int hopCount;

  /// Phase 2: Unique message ID for routing
  final String messageId;

  /// Phase 2: Whether this message was forwarded
  final bool isForwarded;

  /// Phase 3: Encrypted message data (for private/channel messages)
  final List<int>? encryptedData;

  /// Phase 3: Sender's public key (for key exchange)
  final List<int>? senderPublicKey;

  const Message({
    required this.id,
    required this.senderId,
    required this.senderNickname,
    required this.content,
    required this.type,
    required this.timestamp,
    this.channel,
    this.isEncrypted = false,
    this.status = DeliveryStatus.pending,
    // Phase 2: Routing fields with defaults
    this.ttl = 7,
    this.hopCount = 0,
    required this.messageId,
    this.isForwarded = false,
    // Phase 3: Encryption fields
    this.encryptedData,
    this.senderPublicKey,
  });

  /// Create a Message from a map (for method channel deserialization)
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      senderId: map['senderId'] as String,
      senderNickname: map['senderNickname'] as String,
      content: map['content'] as String,
      type: MessageType.values[map['type'] as int],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      channel: map['channel'] as String?,
      isEncrypted: map['isEncrypted'] as bool? ?? false,
      status: DeliveryStatus.values[map['status'] as int? ?? 0],
      // Phase 2: Routing fields
      ttl: map['ttl'] as int? ?? 7,
      hopCount: map['hopCount'] as int? ?? 0,
      messageId: map['messageId'] as String? ?? map['id'] as String,
      isForwarded: map['isForwarded'] as bool? ?? false,
      // Phase 3: Encryption fields
      encryptedData: map['encryptedData'] as List<int>?,
      senderPublicKey: map['senderPublicKey'] as List<int>?,
    );
  }

  /// Convert to a map (for method channel serialization)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderNickname': senderNickname,
      'content': content,
      'type': type.index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'channel': channel,
      'isEncrypted': isEncrypted,
      'status': status.index,
      // Phase 2: Routing fields
      'ttl': ttl,
      'hopCount': hopCount,
      'messageId': messageId,
      'isForwarded': isForwarded,
      // Phase 3: Encryption fields
      'encryptedData': encryptedData,
      'senderPublicKey': senderPublicKey,
    };
  }

  /// Create a copy with updated fields
  Message copyWith({
    String? id,
    String? senderId,
    String? senderNickname,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    String? channel,
    bool? isEncrypted,
    DeliveryStatus? status,
    int? ttl,
    int? hopCount,
    String? messageId,
    bool? isForwarded,
    List<int>? encryptedData,
    List<int>? senderPublicKey,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderNickname: senderNickname ?? this.senderNickname,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      channel: channel ?? this.channel,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      status: status ?? this.status,
      ttl: ttl ?? this.ttl,
      hopCount: hopCount ?? this.hopCount,
      messageId: messageId ?? this.messageId,
      isForwarded: isForwarded ?? this.isForwarded,
      encryptedData: encryptedData ?? this.encryptedData,
      senderPublicKey: senderPublicKey ?? this.senderPublicKey,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, from: $senderNickname, type: $type, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

