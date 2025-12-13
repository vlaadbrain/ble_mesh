/// Represents a peer in the BLE mesh network
class Peer {
  /// Unique identifier for the peer
  final String id;

  /// Display nickname of the peer
  final String nickname;

  /// Received Signal Strength Indicator (RSSI) in dBm
  final int rssi;

  /// Last time the peer was seen
  final DateTime lastSeen;

  /// Whether the peer is currently connected
  final bool isConnected;

  /// Number of hops to reach this peer (0 = direct connection)
  final int hopCount;

  const Peer({
    required this.id,
    required this.nickname,
    required this.rssi,
    required this.lastSeen,
    required this.isConnected,
    this.hopCount = 0,
  });

  /// Create a Peer from a map (for method channel deserialization)
  factory Peer.fromMap(Map<String, dynamic> map) {
    return Peer(
      id: map['id'] as String,
      nickname: map['nickname'] as String,
      rssi: map['rssi'] as int,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] as int),
      isConnected: map['isConnected'] as bool,
      hopCount: map['hopCount'] as int? ?? 0,
    );
  }

  /// Convert to a map (for method channel serialization)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'rssi': rssi,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'isConnected': isConnected,
      'hopCount': hopCount,
    };
  }

  @override
  String toString() {
    return 'Peer(id: $id, nickname: $nickname, rssi: $rssi, isConnected: $isConnected, hopCount: $hopCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Peer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

