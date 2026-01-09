import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Session keys for a peer connection
class SessionKeys {
  final SimpleKeyPairData localEphemeralKeyPair; // Our ephemeral X25519 key
  final SimplePublicKey remotePublicKey; // Peer's public key
  final SecretKey sharedSecret; // Derived shared secret
  final DateTime createdAt; // For rotation

  SessionKeys({
    required this.localEphemeralKeyPair,
    required this.remotePublicKey,
    required this.sharedSecret,
    required this.createdAt,
  });

  bool get shouldRotate =>
      DateTime.now().difference(createdAt) > const Duration(hours: 24);
}

/// Manages cryptographic keys for the mesh network
class KeyManager {
  // Identity keys (long-term, stored securely)
  SimpleKeyPairData? _identitySigningKeyPair; // Ed25519
  SimpleKeyPairData? _identityDhKeyPair; // X25519

  // Session keys (ephemeral, per-peer)
  final Map<String, SessionKeys> _sessionKeys = {};

  // Channel keys (derived from passwords)
  final Map<String, SecretKey> _channelKeys = {};

  // Store channel passwords for re-derivation
  final Map<String, String> _channelPasswords = {};

  // Phase 3: Store peer public keys (received via key exchange)
  final Map<String, List<int>> _peerPublicKeys = {};

  // Callback for when a peer public key is received
  void Function(String peerId, List<int> publicKey)? onPeerPublicKeyReceived;

  /// Initialize key manager and load/generate identity keys
  Future<void> initialize() async {
    // Try to load existing keys from secure storage
    await _loadIdentityKeys();

    // Generate new keys if not found
    if (_identitySigningKeyPair == null) {
      final ed25519 = Ed25519();
      final keyPair = await ed25519.newKeyPair();
      _identitySigningKeyPair = await keyPair.extract();
      await _saveIdentityKeys();
    }

    if (_identityDhKeyPair == null) {
      final x25519 = X25519();
      final keyPair = await x25519.newKeyPair();
      _identityDhKeyPair = await keyPair.extract();
      await _saveIdentityKeys();
    }
  }

  /// Get or create session keys for a peer (for encryption - generates ephemeral keys)
  Future<SessionKeys> getSessionKeys(
      String peerId, SimplePublicKey peerPublicKey) async {
    // Check if we have existing session keys
    if (_sessionKeys.containsKey(peerId)) {
      final keys = _sessionKeys[peerId]!;
      if (!keys.shouldRotate) {
        return keys;
      }
    }

    // Generate ephemeral key pair
    final algorithm = X25519();
    final localKeyPair = await algorithm.newKeyPair();

    // Perform ECDH key exchange
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: peerPublicKey,
    );

    // Extract key pair data
    final localKeyPairData = await localKeyPair.extract();

    // Store session keys
    final sessionKeys = SessionKeys(
      localEphemeralKeyPair: localKeyPairData,
      remotePublicKey: peerPublicKey,
      sharedSecret: sharedSecret,
      createdAt: DateTime.now(),
    );

    _sessionKeys[peerId] = sessionKeys;
    return sessionKeys;
  }

  /// Derive shared secret using our identity DH key (for decryption)
  ///
  /// This is used when receiving a message - we use our identity DH private key
  /// with the sender's ephemeral public key to derive the shared secret.
  Future<SecretKey> deriveSharedSecretForDecryption(
      SimplePublicKey senderEphemeralPublicKey) async {
    if (_identityDhKeyPair == null) {
      throw StateError('Identity DH keys not initialized');
    }

    final algorithm = X25519();

    // Create a SimpleKeyPair from the identity DH key pair data
    final identityKeyPair = SimpleKeyPairData(
      _identityDhKeyPair!.bytes,
      publicKey: await _identityDhKeyPair!.extractPublicKey(),
      type: KeyPairType.x25519,
    );

    // Perform ECDH: our identity DH private + sender's ephemeral public
    return await algorithm.sharedSecretKey(
      keyPair: identityKeyPair,
      remotePublicKey: senderEphemeralPublicKey,
    );
  }

  /// Derive channel key from password
  Future<SecretKey> deriveChannelKey(String channel, String password) async {
    // Check cache first
    final cacheKey = '$channel:$password';
    if (_channelKeys.containsKey(cacheKey)) {
      return _channelKeys[cacheKey]!;
    }

    // Store password for later use
    _channelPasswords[channel] = password;

    // Derive key using Argon2id
    final algorithm = Argon2id(
      memory: 65536, // 64 MB
      parallelism: 2, // Use 2 CPU cores
      iterations: 3, // 3 iterations
      hashLength: 32, // 256-bit key
    );

    // Use channel name as salt
    final salt = utf8.encode(channel);

    final secretKey = await algorithm.deriveKey(
      secretKey: SecretKeyData(utf8.encode(password)),
      nonce: salt,
    );

    _channelKeys[cacheKey] = secretKey;
    return secretKey;
  }

  /// Get channel password for re-derivation
  String? getChannelPassword(String channel) {
    return _channelPasswords[channel];
  }

  /// Sign data with identity key
  Future<Signature> sign(List<int> data) async {
    if (_identitySigningKeyPair == null) {
      throw StateError('Identity keys not initialized');
    }

    final algorithm = Ed25519();
    // Create a SimpleKeyPair from the extracted key pair data using the algorithm
    final keyPair = await algorithm.newKeyPairFromSeed(_identitySigningKeyPair!.bytes);
    return await algorithm.sign(
      data,
      keyPair: keyPair,
    );
  }

  /// Verify signature from peer
  Future<bool> verify(
      List<int> data, Signature signature, SimplePublicKey publicKey) async {
    final algorithm = Ed25519();
    return await algorithm.verify(
      data,
      signature: signature,
    );
  }

  /// Rotate session keys (call periodically)
  Future<void> rotateSessionKeys() async {
    final keysToRotate = <String>[];

    // Find keys that need rotation (older than 24 hours)
    for (final entry in _sessionKeys.entries) {
      if (entry.value.shouldRotate) {
        keysToRotate.add(entry.key);
      }
    }

    // Remove old keys (will be regenerated on next use)
    for (final peerId in keysToRotate) {
      _sessionKeys.remove(peerId);
    }

    //print('Rotated ${keysToRotate.length} session keys');
  }

  /// Get identity signing public key
  Future<SimplePublicKey> getIdentitySigningPublicKey() async {
    if (_identitySigningKeyPair == null) {
      throw StateError('Identity keys not initialized');
    }
    return await _identitySigningKeyPair!.extractPublicKey();
  }

  /// Get identity DH public key
  Future<SimplePublicKey> getIdentityDhPublicKey() async {
    if (_identityDhKeyPair == null) {
      throw StateError('Identity keys not initialized');
    }
    return await _identityDhKeyPair!.extractPublicKey();
  }

  /// Load identity keys from secure storage
  /// TODO: Implement with flutter_secure_storage in Task 3.7
  Future<void> _loadIdentityKeys() async {
    // Placeholder - will be implemented in Task 3.7
    // For now, keys will be generated fresh each time
  }

  /// Save identity keys to secure storage
  /// TODO: Implement with flutter_secure_storage in Task 3.7
  Future<void> _saveIdentityKeys() async {
    // Placeholder - will be implemented in Task 3.7
    // For now, keys are only stored in memory
  }

  /// Clear all keys (for testing or logout)
  void clearAllKeys() {
    _sessionKeys.clear();
    _channelKeys.clear();
    _channelPasswords.clear();
    _peerPublicKeys.clear();
  }

  /// Phase 3: Store a peer's public key received via key exchange
  ///
  /// [peerId] - The ID of the peer
  /// [publicKey] - The peer's public key bytes
  void storePeerPublicKey(String peerId, List<int> publicKey) {
    _peerPublicKeys[peerId] = List<int>.from(publicKey);

    // Notify listeners that a new public key was received
    onPeerPublicKeyReceived?.call(peerId, publicKey);
  }

  /// Phase 3: Get a peer's stored public key
  ///
  /// [peerId] - The ID of the peer
  /// Returns the public key bytes or null if not found
  List<int>? getPeerPublicKey(String peerId) {
    return _peerPublicKeys[peerId];
  }

  /// Phase 3: Check if we have a public key for a peer
  ///
  /// [peerId] - The ID of the peer
  bool hasPeerPublicKey(String peerId) {
    return _peerPublicKeys.containsKey(peerId);
  }

  /// Phase 3: Remove a peer's public key (e.g., when peer disconnects)
  ///
  /// [peerId] - The ID of the peer
  void removePeerPublicKey(String peerId) {
    _peerPublicKeys.remove(peerId);
  }

  /// Phase 3: Get all stored peer public keys
  Map<String, List<int>> getAllPeerPublicKeys() {
    return Map<String, List<int>>.from(_peerPublicKeys);
  }
}

