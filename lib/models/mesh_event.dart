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
}

