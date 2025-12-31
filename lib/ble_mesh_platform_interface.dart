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

  /// Phase 3: Send an encrypted private message to a specific peer
  Future<void> sendPrivateMessage({
    required String peerId,
    required List<int> encryptedData,
    required List<int> senderPublicKey,
  }) {
    throw UnimplementedError('sendPrivateMessage() has not been implemented.');
  }

  /// Phase 3: Share our public key with a peer
  Future<void> sharePublicKey({
    required String peerId,
    required List<int> publicKey,
  }) {
    throw UnimplementedError('sharePublicKey() has not been implemented.');
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
}
