import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:ble_mesh/services/key_manager.dart';

void main() {
  group('KeyManager', () {
    late KeyManager keyManager;

    setUp(() async {
      keyManager = KeyManager();
      await keyManager.initialize();
    });

    tearDown(() {
      keyManager.clearAllKeys();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        final km = KeyManager();
        await km.initialize();
        // Should not throw
        expect(km, isNotNull);
      });

      test('should generate identity signing key on initialization', () async {
        final publicKey = await keyManager.getIdentitySigningPublicKey();
        expect(publicKey, isNotNull);
        expect(publicKey.bytes, isNotEmpty);
      });

      test('should generate identity DH key on initialization', () async {
        final publicKey = await keyManager.getIdentityDhPublicKey();
        expect(publicKey, isNotNull);
        expect(publicKey.bytes, isNotEmpty);
        expect(publicKey.bytes.length, equals(32)); // X25519 public key is 32 bytes
      });
    });

    group('Peer Public Key Storage', () {
      const testPeerId = 'test-peer-123';
      final testPublicKey = List<int>.generate(32, (i) => i);

      test('should store peer public key', () {
        keyManager.storePeerPublicKey(testPeerId, testPublicKey);
        expect(keyManager.hasPeerPublicKey(testPeerId), isTrue);
      });

      test('should retrieve stored peer public key', () {
        keyManager.storePeerPublicKey(testPeerId, testPublicKey);
        final retrieved = keyManager.getPeerPublicKey(testPeerId);
        expect(retrieved, isNotNull);
        expect(retrieved, equals(testPublicKey));
      });

      test('should return null for non-existent peer', () {
        final retrieved = keyManager.getPeerPublicKey('non-existent-peer');
        expect(retrieved, isNull);
      });

      test('should return false for hasPeerPublicKey on non-existent peer', () {
        expect(keyManager.hasPeerPublicKey('non-existent-peer'), isFalse);
      });

      test('should overwrite existing peer public key', () {
        final newPublicKey = List<int>.generate(32, (i) => i + 100);
        keyManager.storePeerPublicKey(testPeerId, testPublicKey);
        keyManager.storePeerPublicKey(testPeerId, newPublicKey);

        final retrieved = keyManager.getPeerPublicKey(testPeerId);
        expect(retrieved, equals(newPublicKey));
      });

      test('should remove peer public key', () {
        keyManager.storePeerPublicKey(testPeerId, testPublicKey);
        expect(keyManager.hasPeerPublicKey(testPeerId), isTrue);

        keyManager.removePeerPublicKey(testPeerId);
        expect(keyManager.hasPeerPublicKey(testPeerId), isFalse);
        expect(keyManager.getPeerPublicKey(testPeerId), isNull);
      });

      test('should get all stored peer public keys', () {
        const peerId1 = 'peer-1';
        const peerId2 = 'peer-2';
        final key1 = List<int>.generate(32, (i) => i);
        final key2 = List<int>.generate(32, (i) => i + 50);

        keyManager.storePeerPublicKey(peerId1, key1);
        keyManager.storePeerPublicKey(peerId2, key2);

        final allKeys = keyManager.getAllPeerPublicKeys();
        expect(allKeys.length, equals(2));
        expect(allKeys[peerId1], equals(key1));
        expect(allKeys[peerId2], equals(key2));
      });

      test('should trigger callback when peer public key is stored', () {
        String? receivedPeerId;
        List<int>? receivedKey;

        keyManager.onPeerPublicKeyReceived = (peerId, publicKey) {
          receivedPeerId = peerId;
          receivedKey = publicKey;
        };

        keyManager.storePeerPublicKey(testPeerId, testPublicKey);

        expect(receivedPeerId, equals(testPeerId));
        expect(receivedKey, equals(testPublicKey));
      });

      test('should store a defensive copy of the public key', () {
        final mutableKey = List<int>.generate(32, (i) => i);
        keyManager.storePeerPublicKey(testPeerId, mutableKey);

        // Modify the original list
        mutableKey[0] = 255;

        // The stored key should not be affected
        final retrieved = keyManager.getPeerPublicKey(testPeerId);
        expect(retrieved![0], equals(0)); // Original value, not 255
      });
    });

    group('Session Keys', () {
      test('should create session keys for a peer', () async {
        // Generate a test peer public key
        final x25519 = X25519();
        final peerKeyPair = await x25519.newKeyPair();
        final peerPublicKey = await peerKeyPair.extractPublicKey();

        final sessionKeys = await keyManager.getSessionKeys('peer-1', peerPublicKey);

        expect(sessionKeys, isNotNull);
        expect(sessionKeys.sharedSecret, isNotNull);
        expect(sessionKeys.localEphemeralKeyPair, isNotNull);
        expect(sessionKeys.remotePublicKey, equals(peerPublicKey));
      });

      test('should return cached session keys for same peer', () async {
        final x25519 = X25519();
        final peerKeyPair = await x25519.newKeyPair();
        final peerPublicKey = await peerKeyPair.extractPublicKey();

        final sessionKeys1 = await keyManager.getSessionKeys('peer-1', peerPublicKey);
        final sessionKeys2 = await keyManager.getSessionKeys('peer-1', peerPublicKey);

        // Should return the same session keys (cached)
        expect(sessionKeys1.createdAt, equals(sessionKeys2.createdAt));
      });

      test('should create different session keys for different peers', () async {
        final x25519 = X25519();

        final peer1KeyPair = await x25519.newKeyPair();
        final peer1PublicKey = await peer1KeyPair.extractPublicKey();

        final peer2KeyPair = await x25519.newKeyPair();
        final peer2PublicKey = await peer2KeyPair.extractPublicKey();

        final sessionKeys1 = await keyManager.getSessionKeys('peer-1', peer1PublicKey);
        final sessionKeys2 = await keyManager.getSessionKeys('peer-2', peer2PublicKey);

        // Should have different shared secrets
        final secret1Bytes = await sessionKeys1.sharedSecret.extractBytes();
        final secret2Bytes = await sessionKeys2.sharedSecret.extractBytes();

        expect(secret1Bytes, isNot(equals(secret2Bytes)));
      });
    });

    group('Channel Key Derivation', () {
      test('should derive channel key from password', () async {
        final channelKey = await keyManager.deriveChannelKey('test-channel', 'password123');

        expect(channelKey, isNotNull);
        final keyBytes = await channelKey.extractBytes();
        expect(keyBytes.length, equals(32)); // 256-bit key
      });

      test('should return same key for same channel and password', () async {
        final key1 = await keyManager.deriveChannelKey('test-channel', 'password123');
        final key2 = await keyManager.deriveChannelKey('test-channel', 'password123');

        final bytes1 = await key1.extractBytes();
        final bytes2 = await key2.extractBytes();

        expect(bytes1, equals(bytes2));
      });

      test('should return different keys for different passwords', () async {
        final key1 = await keyManager.deriveChannelKey('test-channel', 'password1');
        final key2 = await keyManager.deriveChannelKey('test-channel', 'password2');

        final bytes1 = await key1.extractBytes();
        final bytes2 = await key2.extractBytes();

        expect(bytes1, isNot(equals(bytes2)));
      });

      test('should return different keys for different channels', () async {
        final key1 = await keyManager.deriveChannelKey('channel-1', 'password');
        final key2 = await keyManager.deriveChannelKey('channel-2', 'password');

        final bytes1 = await key1.extractBytes();
        final bytes2 = await key2.extractBytes();

        expect(bytes1, isNot(equals(bytes2)));
      });

      test('should store channel password for later retrieval', () async {
        await keyManager.deriveChannelKey('test-channel', 'secret-password');

        final password = keyManager.getChannelPassword('test-channel');
        expect(password, equals('secret-password'));
      });
    });

    group('Signing and Verification', () {
      test('should sign data', () async {
        final data = [1, 2, 3, 4, 5];
        final signature = await keyManager.sign(data);

        expect(signature, isNotNull);
        expect(signature.bytes, isNotEmpty);
      });

      test('should produce different signatures for different data', () async {
        final data1 = [1, 2, 3, 4, 5];
        final data2 = [5, 4, 3, 2, 1];

        final signature1 = await keyManager.sign(data1);
        final signature2 = await keyManager.sign(data2);

        expect(signature1.bytes, isNot(equals(signature2.bytes)));
      });
    });

    group('Clear All Keys', () {
      test('should clear all keys', () async {
        // Add some keys
        keyManager.storePeerPublicKey('peer-1', List<int>.generate(32, (i) => i));
        await keyManager.deriveChannelKey('channel-1', 'password');

        // Verify keys exist
        expect(keyManager.hasPeerPublicKey('peer-1'), isTrue);
        expect(keyManager.getChannelPassword('channel-1'), isNotNull);

        // Clear all keys
        keyManager.clearAllKeys();

        // Verify keys are cleared
        expect(keyManager.hasPeerPublicKey('peer-1'), isFalse);
        expect(keyManager.getChannelPassword('channel-1'), isNull);
        expect(keyManager.getAllPeerPublicKeys(), isEmpty);
      });
    });

    group('Session Key Rotation', () {
      test('should identify keys that need rotation', () async {
        // This test verifies the shouldRotate property
        final x25519 = X25519();
        final peerKeyPair = await x25519.newKeyPair();
        final peerPublicKey = await peerKeyPair.extractPublicKey();

        final sessionKeys = await keyManager.getSessionKeys('peer-1', peerPublicKey);

        // New keys should not need rotation
        expect(sessionKeys.shouldRotate, isFalse);
      });
    });
  });
}

