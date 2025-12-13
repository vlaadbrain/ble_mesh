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
}
