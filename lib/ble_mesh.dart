import 'package:cryptography/cryptography.dart';
import 'ble_mesh_platform_interface.dart';
import 'models/peer.dart';
import 'models/message.dart';
import 'models/mesh_event.dart';
import 'models/power_mode.dart';
import 'services/key_manager.dart';
import 'services/encryption_service.dart';
import 'models/encrypted_message.dart';

// Export models for easy access
export 'models/peer.dart';
export 'models/message.dart';
export 'models/mesh_event.dart';
export 'models/power_mode.dart';

/// Main class for interacting with the BLE mesh network
class BleMesh {
  // Phase 3: Encryption services
  KeyManager? _keyManager;
  EncryptionService? _encryptionService;
  bool _encryptionEnabled = false;
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
  }) async {
    // Phase 3: Initialize encryption services if enabled
    _encryptionEnabled = enableEncryption;
    if (enableEncryption) {
      _keyManager = KeyManager();
      await _keyManager!.initialize();
      _encryptionService = EncryptionService(_keyManager!);
    }

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

  /// Phase 3: Send an encrypted private message to a specific peer
  ///
  /// [peerId] - The ID of the recipient peer
  /// [message] - The message content to send (will be encrypted)
  ///
  /// Throws [StateError] if encryption is not enabled
  /// Throws [Exception] if peer is not found or doesn't have a public key
  Future<void> sendPrivateMessage(String peerId, String message) async {
    if (!_encryptionEnabled || _encryptionService == null || _keyManager == null) {
      throw StateError('Encryption must be enabled to send private messages');
    }

    // First, try to get peer's public key from KeyManager (received via key exchange)
    List<int>? peerPublicKeyBytes = _keyManager!.getPeerPublicKey(peerId);

    // If not found in KeyManager, try to get from connected peers list
    if (peerPublicKeyBytes == null) {
      final peers = await getConnectedPeers();
      final peer = peers.firstWhere(
        (p) => p.id == peerId,
        orElse: () => throw Exception('Peer not found: $peerId'),
      );

      if (peer.publicKey != null && peer.publicKey!.isNotEmpty) {
        peerPublicKeyBytes = peer.publicKey;
      }
    }

    if (peerPublicKeyBytes == null || peerPublicKeyBytes.isEmpty) {
      throw Exception('Peer does not have a public key for encryption. '
          'Please exchange keys first using sharePublicKey().');
    }

    // Convert public key bytes to SimplePublicKey
    final recipientPublicKey = SimplePublicKey(
      peerPublicKeyBytes,
      type: KeyPairType.x25519,
    );

    // Encrypt message
    final encryptedMessage = await _encryptionService!.encryptPrivateMessage(
      recipientId: peerId,
      recipientPublicKey: recipientPublicKey,
      content: message,
    );

    // Get our public key
    final ourPublicKey = await _keyManager!.getIdentityDhPublicKey();

    // Send via platform interface
    await BleMeshPlatform.instance.sendPrivateMessage(
      peerId: peerId,
      encryptedData: encryptedMessage.toBytes(),
      senderPublicKey: ourPublicKey.bytes,
    );
  }

  /// Phase 3: Get our public key for sharing with peers
  ///
  /// Returns the device's public key bytes for encryption
  /// Throws [StateError] if encryption is not enabled
  Future<List<int>> getPublicKey() async {
    if (!_encryptionEnabled || _keyManager == null) {
      throw StateError('Encryption must be enabled to get public key');
    }

    final publicKey = await _keyManager!.getIdentityDhPublicKey();
    return publicKey.bytes;
  }

  /// Phase 3: Share our public key with a specific peer
  ///
  /// [peerId] - The ID of the peer to share the key with
  /// [publicKey] - The public key bytes to share
  ///
  /// Throws [StateError] if encryption is not enabled
  Future<void> sharePublicKey({
    required String peerId,
    required List<int> publicKey,
  }) async {
    if (!_encryptionEnabled) {
      throw StateError('Encryption must be enabled to share public keys');
    }

    await BleMeshPlatform.instance.sharePublicKey(
      peerId: peerId,
      publicKey: publicKey,
    );
  }

  /// Get list of currently connected peers
  Future<List<Peer>> getConnectedPeers() {
    return BleMeshPlatform.instance.getConnectedPeers();
  }

  // Callback for when a peer's public key is received
  void Function(String peerId, List<int> publicKey)? onPeerPublicKeyReceived;

  /// Stream of received messages
  ///
  /// Listen to this stream to receive all incoming messages.
  /// Encrypted messages will be automatically decrypted if encryption is enabled.
  /// System messages with public keys will be intercepted and stored.
  Stream<Message> get messageStream {
    final platformStream = BleMeshPlatform.instance.messageStream;

    // If encryption is not enabled, return the stream as-is
    if (!_encryptionEnabled || _encryptionService == null) {
      return platformStream;
    }

    // Transform the stream to handle encryption-related messages
    return platformStream.asyncMap((message) async {
      print('platformStream has a message ${message.toString()}');
      // Handle system messages with public keys
      if (message.type == MessageType.system && message.senderPublicKey != null) {
      print('system message received: ${message.toString()}');
        await _handlePublicKeyMessage(message);
        // Return the message so UI can optionally display key exchange events
        return message.copyWith(
          content: '[Public key received from ${message.senderNickname}]',
        );
      }

      // If message is not encrypted, return as-is
      if (!message.isEncrypted || message.encryptedData == null) {
        return message;
      }

      try {
        // Decrypt the message
        print('encrypted message received: ${message.toString()}');
        final decryptedContent = await _decryptMessage(message);

        // Return message with decrypted content
        return message.copyWith(
          content: decryptedContent,
          isEncrypted: false, // Mark as decrypted for display
        );
      } catch (e) {
        // If decryption fails, return the message with an error indicator
        return message.copyWith(
          content: '[Decryption failed: $e]',
        );
      }
    });
  }

  /// Handle incoming public key messages
  Future<void> _handlePublicKeyMessage(Message message) async {
    print('_handlePublicKeyMessage: ${message.toString()}');
    if (_keyManager == null || message.senderPublicKey == null) {
      return;
    }

    final senderId = message.senderId;
    final publicKey = message.senderPublicKey!;

    // Store the public key in KeyManager
    _keyManager!.storePeerPublicKey(senderId, publicKey);

    // Notify listeners (e.g., UI) that a public key was received
    onPeerPublicKeyReceived?.call(senderId, publicKey);
  }

  /// Phase 3: Internal method to decrypt an encrypted message
  Future<String> _decryptMessage(Message message) async {
    if (_encryptionService == null || message.encryptedData == null) {
      throw StateError('Encryption service not initialized or no encrypted data');
    }

    // Get sender's public key
    if (message.senderPublicKey == null) {
      throw Exception('Message does not contain sender public key');
    }

    final senderPublicKey = SimplePublicKey(
      message.senderPublicKey!,
      type: KeyPairType.x25519,
    );

    // Decrypt based on message type
    if (message.type == MessageType.private) {
      // Deserialize encrypted message from bytes
      final encryptedMessage = EncryptedMessage.fromBytes(message.encryptedData!);

      return await _encryptionService!.decryptPrivateMessage(
        senderId: message.senderId,
        senderPublicKey: senderPublicKey,
        encryptedMessage: encryptedMessage,
      );
    } else if (message.type == MessageType.channel) {
      // Channel decryption will be implemented in Task 3.3
      throw UnimplementedError('Channel message decryption not yet implemented');
    } else {
      throw Exception('Cannot decrypt message of type: ${message.type}');
    }
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
