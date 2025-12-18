/// Type of mesh event
enum MeshEventType {
  /// Mesh networking has started
  meshStarted,

  /// Mesh networking has stopped
  meshStopped,

  /// A new peer was discovered
  peerDiscovered,

  /// A peer connected
  peerConnected,

  /// A peer disconnected
  peerDisconnected,

  /// A message was received
  messageReceived,

  /// Message forwarding metrics updated (Phase 2)
  forwardingMetrics,

  /// An error occurred
  error,
}

/// Represents an event in the mesh network
class MeshEvent {
  /// Type of event
  final MeshEventType type;

  /// Optional message describing the event
  final String? message;

  /// Optional additional data
  final Map<String, dynamic>? data;

  const MeshEvent({
    required this.type,
    this.message,
    this.data,
  });

  /// Create a MeshEvent from a map (for method channel deserialization)
  factory MeshEvent.fromMap(Map<String, dynamic> map) {
    return MeshEvent(
      type: MeshEventType.values[map['type'] as int],
      message: map['message'] as String?,
      data: map['data'] as Map<String, dynamic>?,
    );
  }

  /// Convert to a map (for method channel serialization)
  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'message': message,
      'data': data,
    };
  }

  @override
  String toString() {
    return 'MeshEvent(type: $type, message: $message, data: $data)';
  }

  /// Create a forwarding metrics event (Phase 2)
  ///
  /// [messagesForwarded] - Total number of messages forwarded
  /// [messagesCached] - Total number of messages in cache
  /// [cacheHits] - Number of duplicate messages detected
  /// [cacheMisses] - Number of new messages processed
  factory MeshEvent.forwardingMetrics({
    required int messagesForwarded,
    required int messagesCached,
    int? cacheHits,
    int? cacheMisses,
  }) {
    return MeshEvent(
      type: MeshEventType.forwardingMetrics,
      message: 'Forwarding metrics updated',
      data: {
        'messagesForwarded': messagesForwarded,
        'messagesCached': messagesCached,
        if (cacheHits != null) 'cacheHits': cacheHits,
        if (cacheMisses != null) 'cacheMisses': cacheMisses,
      },
    );
  }

  /// Get messages forwarded count from forwarding metrics event
  int? get messagesForwarded => data?['messagesForwarded'] as int?;

  /// Get messages cached count from forwarding metrics event
  int? get messagesCached => data?['messagesCached'] as int?;

  /// Get cache hits count from forwarding metrics event
  int? get cacheHits => data?['cacheHits'] as int?;

  /// Get cache misses count from forwarding metrics event
  int? get cacheMisses => data?['cacheMisses'] as int?;
}

