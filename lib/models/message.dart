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

