import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ble_mesh_method_channel.dart';
import 'models/peer.dart';
import 'models/message.dart';
import 'models/mesh_event.dart';
import 'models/power_mode.dart';

abstract class BleMeshPlatform extends PlatformInterface {
  /// Constructs a BleMeshPlatform.
  BleMeshPlatform() : super(token: _token);

  static final Object _token = Object();

  static BleMeshPlatform _instance = MethodChannelBleMesh();

  /// The default instance of [BleMeshPlatform] to use.
  ///
  /// Defaults to [MethodChannelBleMesh].
  static BleMeshPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BleMeshPlatform] when
  /// they register themselves.
  static set instance(BleMeshPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Initialize the mesh network
  Future<void> initialize({
    String? nickname,
    bool enableEncryption = true,
    PowerMode powerMode = PowerMode.balanced,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Start mesh networking (scanning and advertising)
  Future<void> startMesh() {
    throw UnimplementedError('startMesh() has not been implemented.');
  }

  /// Stop mesh networking
  Future<void> stopMesh() {
    throw UnimplementedError('stopMesh() has not been implemented.');
  }

  /// Send a public message to all peers
  Future<void> sendPublicMessage(String message) {
    throw UnimplementedError('sendPublicMessage() has not been implemented.');
  }

  /// Get list of connected peers
  Future<List<Peer>> getConnectedPeers() {
    throw UnimplementedError('getConnectedPeers() has not been implemented.');
  }

  /// Stream of received messages
  Stream<Message> get messageStream {
    throw UnimplementedError('messageStream has not been implemented.');
  }

  /// Stream of peer connection events
  Stream<Peer> get peerConnectedStream {
    throw UnimplementedError('peerConnectedStream has not been implemented.');
  }

  /// Stream of peer disconnection events
  Stream<Peer> get peerDisconnectedStream {
    throw UnimplementedError('peerDisconnectedStream has not been implemented.');
  }

  /// Stream of mesh events
  Stream<MeshEvent> get meshEventStream {
    throw UnimplementedError('meshEventStream has not been implemented.');
  }

  /// Start discovering nearby peers without auto-connecting
  Future<void> startDiscovery() {
    throw UnimplementedError('startDiscovery() has not been implemented.');
  }

  /// Stop peer discovery
  Future<void> stopDiscovery() {
    throw UnimplementedError('stopDiscovery() has not been implemented.');
  }

  /// Get list of discovered peers (not necessarily connected)
  Future<List<Peer>> getDiscoveredPeers() {
    throw UnimplementedError('getDiscoveredPeers() has not been implemented.');
  }

  /// Stream of discovered peers
  /// Emits a peer whenever a new peer is discovered or an existing peer is re-discovered
  Stream<Peer> get discoveredPeersStream {
    throw UnimplementedError('discoveredPeersStream has not been implemented.');
  }

  /// Connect to a peer by sender UUID
  ///
  /// [senderId] - The stable sender UUID of the peer to connect to
  /// Returns true if connection initiated successfully
  Future<bool> connectToPeer(String senderId) {
    throw UnimplementedError('connectToPeer() has not been implemented.');
  }

  /// Disconnect from a peer by sender UUID
  ///
  /// [senderId] - The stable sender UUID of the peer to disconnect from
  /// Returns true if disconnection initiated successfully
  Future<bool> disconnectFromPeer(String senderId) {
    throw UnimplementedError('disconnectFromPeer() has not been implemented.');
  }

  /// Get connection state of a specific peer
  Future<String?> getPeerConnectionState(String senderId) {
    throw UnimplementedError('getPeerConnectionState() has not been implemented.');
  }

  /// Block a peer by sender UUID
  ///
  /// [senderId] - The sender UUID to block
  /// Returns true if the peer was blocked successfully
  ///
  /// Blocked peers:
  /// - Cannot connect to this device
  /// - Will be disconnected if currently connected
  /// - Will not appear in discovery results
  /// - Their messages will be ignored and not forwarded
  ///
  /// The blocklist persists across app restarts.
  Future<bool> blockPeer(String senderId) {
    throw UnimplementedError('blockPeer() has not been implemented.');
  }

  /// Unblock a previously blocked peer
  ///
  /// [senderId] - The sender UUID to unblock
  /// Returns true if the peer was unblocked successfully
  Future<bool> unblockPeer(String senderId) {
    throw UnimplementedError('unblockPeer() has not been implemented.');
  }

  /// Check if a peer is currently blocked
  ///
  /// [senderId] - The sender UUID to check
  /// Returns true if the peer is blocked
  Future<bool> isPeerBlocked(String senderId) {
    throw UnimplementedError('isPeerBlocked() has not been implemented.');
  }

  /// Get list of all blocked peer sender UUIDs
  ///
  /// Returns a list of blocked sender UUIDs
  Future<List<String>> getBlockedPeers() {
    throw UnimplementedError('getBlockedPeers() has not been implemented.');
  }

  /// Clear the entire blocklist
  ///
  /// Removes all peers from the blocklist
  Future<void> clearBlocklist() {
    throw UnimplementedError('clearBlocklist() has not been implemented.');
  }
}
