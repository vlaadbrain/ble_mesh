import 'ble_mesh_platform_interface.dart';
import 'models/peer.dart';
import 'models/message.dart';
import 'models/mesh_event.dart';
import 'models/power_mode.dart';

// Export models for easy access
export 'models/peer.dart';
export 'models/message.dart';
export 'models/mesh_event.dart';
export 'models/power_mode.dart';

/// Main class for interacting with the BLE mesh network
class BleMesh {
  /// Get the platform version (for testing)
  Future<String?> getPlatformVersion() {
    return BleMeshPlatform.instance.getPlatformVersion();
  }

  /// Initialize the mesh network
  ///
  /// [nickname] - Optional display name for this device
  /// [enableEncryption] - Enable end-to-end encryption (default: true)
  /// [powerMode] - Power optimization mode (default: balanced)
  Future<void> initialize({
    String? nickname,
    bool enableEncryption = true,
    PowerMode powerMode = PowerMode.balanced,
  }) {
    return BleMeshPlatform.instance.initialize(
      nickname: nickname,
      enableEncryption: enableEncryption,
      powerMode: powerMode,
    );
  }

  /// Start mesh networking (scanning and advertising)
  ///
  /// This will begin scanning for nearby peers and advertising this device.
  /// Requires Bluetooth to be enabled and appropriate permissions granted.
  Future<void> startMesh() {
    return BleMeshPlatform.instance.startMesh();
  }

  /// Stop mesh networking
  ///
  /// Stops all scanning, advertising, and disconnects from peers.
  Future<void> stopMesh() {
    return BleMeshPlatform.instance.stopMesh();
  }

  /// Send a public message to all connected peers
  ///
  /// [message] - The message content to broadcast
  Future<void> sendPublicMessage(String message) {
    return BleMeshPlatform.instance.sendPublicMessage(message);
  }

  /// Get list of currently connected peers
  Future<List<Peer>> getConnectedPeers() {
    return BleMeshPlatform.instance.getConnectedPeers();
  }

  /// Stream of received messages
  ///
  /// Listen to this stream to receive all incoming messages.
  Stream<Message> get messageStream {
    return BleMeshPlatform.instance.messageStream;
  }

  /// Stream of peer connection events
  ///
  /// Emits a [Peer] whenever a new peer connects to the mesh.
  Stream<Peer> get peerConnectedStream {
    return BleMeshPlatform.instance.peerConnectedStream;
  }

  /// Stream of peer disconnection events
  ///
  /// Emits a [Peer] whenever a peer disconnects from the mesh.
  Stream<Peer> get peerDisconnectedStream {
    return BleMeshPlatform.instance.peerDisconnectedStream;
  }

  /// Stream of mesh events
  ///
  /// Emits [MeshEvent] for various mesh network events.
  Stream<MeshEvent> get meshEventStream {
    return BleMeshPlatform.instance.meshEventStream;
  }

  /// Start discovering nearby peers
  ///
  /// Begins scanning for BLE mesh devices without automatically connecting.
  /// Listen to [discoveredPeersStream] to receive discovered peers.
  ///
  /// Note: This is separate from [startMesh]. You can discover peers without
  /// starting the full mesh network (advertising + auto-connect).
  Future<void> startDiscovery() {
    return BleMeshPlatform.instance.startDiscovery();
  }

  /// Stop discovering peers
  ///
  /// Stops the BLE scanning started by [startDiscovery].
  Future<void> stopDiscovery() {
    return BleMeshPlatform.instance.stopDiscovery();
  }

  /// Get list of currently discovered peers
  ///
  /// Returns all peers that have been discovered via scanning, regardless
  /// of their connection state. Use [getConnectedPeers] to get only
  /// connected peers.
  Future<List<Peer>> getDiscoveredPeers() {
    return BleMeshPlatform.instance.getDiscoveredPeers();
  }

  /// Stream of discovered peers
  ///
  /// Emits whenever a peer is discovered or re-discovered during scanning.
  /// Peers may be emitted multiple times as they're re-discovered.
  ///
  /// Use this stream to:
  /// - Display available peers to the user
  /// - Decide which peers to connect to
  /// - Monitor peer RSSI changes
  ///
  /// Example:
  /// ```dart
  /// bleMesh.discoveredPeersStream.listen((peer) {
  ///   print('Found: ${peer.nickname} at ${peer.rssi} dBm');
  ///   if (peer.rssi > -70 && peer.senderId != null) {
  ///     // Connect to peers with good signal
  ///     bleMesh.connectToPeer(peer.senderId!);
  ///   }
  /// });
  /// ```
  Stream<Peer> get discoveredPeersStream {
    return BleMeshPlatform.instance.discoveredPeersStream;
  }

  /// Connect to a discovered peer
  ///
  /// [senderId] - The sender UUID of the peer (from discoveredPeersStream)
  /// Returns true if connection was initiated successfully
  ///
  /// Listen to [peerConnectedStream] to know when connection completes.
  ///
  /// Example:
  /// ```dart
  /// final peer = // ... from discoveredPeersStream
  /// if (peer.senderId != null) {
  ///   bool success = await bleMesh.connectToPeer(peer.senderId!);
  ///   if (success) {
  ///     print('Connecting to ${peer.nickname}...');
  ///   }
  /// }
  /// ```
  Future<bool> connectToPeer(String senderId) {
    return BleMeshPlatform.instance.connectToPeer(senderId);
  }

  /// Disconnect from a connected peer
  ///
  /// [senderId] - The sender UUID of the peer to disconnect from
  /// Returns true if disconnection was initiated successfully
  ///
  /// Listen to [peerDisconnectedStream] to know when disconnection completes.
  ///
  /// Example:
  /// ```dart
  /// bool success = await bleMesh.disconnectFromPeer(peer.senderId!);
  /// if (success) {
  ///   print('Disconnecting from ${peer.nickname}...');
  /// }
  /// ```
  Future<bool> disconnectFromPeer(String senderId) {
    return BleMeshPlatform.instance.disconnectFromPeer(senderId);
  }

  /// Get the connection state of a peer
  ///
  /// Returns one of: 'discovered', 'connecting', 'connected', 'disconnecting', 'disconnected'
  /// Returns null if peer is not found
  ///
  /// Example:
  /// ```dart
  /// String? state = await bleMesh.getPeerConnectionState(senderId);
  /// print('Peer state: $state');
  /// ```
  Future<String?> getPeerConnectionState(String senderId) {
    return BleMeshPlatform.instance.getPeerConnectionState(senderId);
  }

  // ========== Blocklist Management ==========

  /// Block a peer to prevent all communication
  ///
  /// [senderId] - The sender UUID of the peer to block
  ///
  /// Blocked peers:
  /// - Cannot connect to this device
  /// - Will be disconnected if currently connected
  /// - Will not appear in discovery results
  /// - Their messages will be ignored and not forwarded
  ///
  /// The blocklist persists across app restarts.
  ///
  /// Returns true if the peer was blocked successfully, false if already blocked
  ///
  /// Example:
  /// ```dart
  /// bool success = await bleMesh.blockPeer(peer.senderId!);
  /// if (success) {
  ///   print('Blocked ${peer.nickname}');
  /// }
  /// ```
  Future<bool> blockPeer(String senderId) {
    return BleMeshPlatform.instance.blockPeer(senderId);
  }

  /// Unblock a previously blocked peer
  ///
  /// [senderId] - The sender UUID of the peer to unblock
  ///
  /// Returns true if the peer was unblocked successfully, false if not blocked
  ///
  /// Example:
  /// ```dart
  /// bool success = await bleMesh.unblockPeer(senderId);
  /// if (success) {
  ///   print('Unblocked peer');
  /// }
  /// ```
  Future<bool> unblockPeer(String senderId) {
    return BleMeshPlatform.instance.unblockPeer(senderId);
  }

  /// Check if a peer is currently blocked
  ///
  /// [senderId] - The sender UUID to check
  ///
  /// Returns true if the peer is blocked
  ///
  /// Example:
  /// ```dart
  /// bool isBlocked = await bleMesh.isPeerBlocked(senderId);
  /// if (isBlocked) {
  ///   print('This peer is blocked');
  /// }
  /// ```
  Future<bool> isPeerBlocked(String senderId) {
    return BleMeshPlatform.instance.isPeerBlocked(senderId);
  }

  /// Get list of all blocked peer sender UUIDs
  ///
  /// Returns a list of blocked sender UUIDs
  ///
  /// Example:
  /// ```dart
  /// List<String> blockedPeers = await bleMesh.getBlockedPeers();
  /// print('Blocked ${blockedPeers.length} peers');
  /// ```
  Future<List<String>> getBlockedPeers() {
    return BleMeshPlatform.instance.getBlockedPeers();
  }

  /// Clear the entire blocklist
  ///
  /// Removes all peers from the blocklist
  ///
  /// Example:
  /// ```dart
  /// await bleMesh.clearBlocklist();
  /// print('Blocklist cleared');
  /// ```
  Future<void> clearBlocklist() {
    return BleMeshPlatform.instance.clearBlocklist();
  }
}
