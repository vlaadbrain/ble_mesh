/// Connection state of a peer
enum PeerConnectionState {
  /// Peer discovered via scanning but not connected
  discovered,

  /// Connection attempt in progress
  connecting,

  /// Peer is connected and ready for communication
  connected,

  /// Disconnection in progress
  disconnecting,

  /// Peer was connected but is now disconnected
  disconnected,
}

/// Represents a peer in the BLE mesh network
class Peer {
  /// Stable sender UUID (6-byte compact format: "AA:BB:CC:DD:EE:FF")
  /// This is the primary identifier for peers across platforms
  /// Null until handshake is completed or extracted from advertisement
  final String? senderId;

  /// Platform-specific connection identifier
  /// Android: MAC address, iOS: CBPeripheral UUID
  /// Used internally for connection management
  final String connectionId;

  /// Display nickname of the peer
  final String nickname;

  /// Received Signal Strength Indicator (RSSI) in dBm
  final int rssi;

  /// Last time the peer was seen
  final DateTime lastSeen;

  /// Current connection state
  final PeerConnectionState connectionState;

  /// Number of hops to reach this peer (0 = direct connection)
  final int hopCount;

  /// Last time a message was forwarded to/from this peer (for routing metrics)
  final DateTime? lastForwardTime;

  /// Whether this peer is blocked
  final bool isBlocked;

  const Peer({
    this.senderId,
    required this.connectionId,
    required this.nickname,
    required this.rssi,
    required this.lastSeen,
    required this.connectionState,
    this.hopCount = 0,
    this.lastForwardTime,
    this.isBlocked = false,
  });

  /// Convenience getter for backward compatibility (returns connectionId)
  String get id => connectionId;

  /// Convenience getter for checking if peer is connectable
  bool get canConnect =>
      senderId != null &&
      connectionState == PeerConnectionState.discovered &&
      !isBlocked;

  /// Create a Peer from a map (for method channel deserialization)
  factory Peer.fromMap(Map<String, dynamic> map) {
    // Parse connection state from string
    final stateStr = map['connectionState'] as String? ?? 'discovered';
    final connectionState = PeerConnectionState.values.firstWhere(
      (e) => e.name == stateStr,
      orElse: () => PeerConnectionState.discovered,
    );

    return Peer(
      senderId: map['senderId'] as String?,
      connectionId: map['connectionId'] as String? ?? map['id'] as String,
      nickname: map['nickname'] as String,
      rssi: map['rssi'] as int,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] as int),
      connectionState: connectionState,
      hopCount: map['hopCount'] as int? ?? 0,
      lastForwardTime: map['lastForwardTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastForwardTime'] as int)
          : null,
      isBlocked: map['isBlocked'] as bool? ?? false,
    );
  }

  /// Convert to a map (for method channel serialization)
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'connectionId': connectionId,
      'id': connectionId, // For backward compatibility
      'nickname': nickname,
      'rssi': rssi,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'connectionState': connectionState.name,
      'hopCount': hopCount,
      'lastForwardTime': lastForwardTime?.millisecondsSinceEpoch,
      'isBlocked': isBlocked,
    };
  }

  @override
  String toString() {
    return 'Peer(senderId: $senderId, connectionId: $connectionId, nickname: $nickname, rssi: $rssi, connectionState: ${connectionState.name}, hopCount: $hopCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // Use senderId for equality if available, otherwise fall back to connectionId
    if (other is Peer) {
      if (senderId != null && other.senderId != null) {
        return senderId == other.senderId;
      }
      return connectionId == other.connectionId;
    }
    return false;
  }

  @override
  int get hashCode => senderId?.hashCode ?? connectionId.hashCode;
}

