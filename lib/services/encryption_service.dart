import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'key_manager.dart';
import '../models/encrypted_message.dart';

/// Handles message encryption and decryption
class EncryptionService {
  final KeyManager _keyManager;

  EncryptionService(this._keyManager);

  /// Encrypt private message for a specific peer
  Future<EncryptedMessage> encryptPrivateMessage({
    required String recipientId,
    required SimplePublicKey recipientPublicKey,
    required String content,
  }) async {
    // Get or create session keys
    final sessionKeys =
        await _keyManager.getSessionKeys(recipientId, recipientPublicKey);

    // Derive encryption key from shared secret using HKDF
    final algorithm = Chacha20.poly1305Aead();
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );

    final encryptionKey = await hkdf.deriveKey(
      secretKey: sessionKeys.sharedSecret,
      info: utf8.encode('ble_mesh_private_message'),
      nonce: [],
    );

    // Encrypt message
    final secretBox = await algorithm.encrypt(
      utf8.encode(content),
      secretKey: encryptionKey,
    );

    // Sign encrypted message
    final dataToSign = [
      ...secretBox.cipherText,
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
    ];
    final signature = await _keyManager.sign(dataToSign);

    // Extract public key for key exchange
    final localPublicKey =
        await sessionKeys.localEphemeralKeyPair.extractPublicKey();

    return EncryptedMessage(
      ciphertext: secretBox.cipherText,
      nonce: secretBox.nonce,
      mac: secretBox.mac,
      ephemeralPublicKey: localPublicKey.bytes,
      signatureBytes: signature.bytes,
    );
  }

  /// Decrypt private message from a peer
  Future<String> decryptPrivateMessage({
    required String senderId,
    required SimplePublicKey senderPublicKey,
    required EncryptedMessage encryptedMessage,
  }) async {
    // Verify signature first
    if (encryptedMessage.signatureBytes != null) {
      final dataToVerify = [
        ...encryptedMessage.ciphertext,
        ...encryptedMessage.nonce,
        ...encryptedMessage.mac.bytes,
      ];

      final signature = Signature(
        encryptedMessage.signatureBytes!,
        publicKey: senderPublicKey,
      );

      final isValid = await _keyManager.verify(
        dataToVerify,
        signature,
        senderPublicKey,
      );

      if (!isValid) {
        throw Exception('Invalid signature');
      }
    }

    // Reconstruct sender's ephemeral public key
    if (encryptedMessage.ephemeralPublicKey == null) {
      throw Exception('Missing ephemeral public key for private message');
    }

    final senderEphemeralPublicKey = SimplePublicKey(
      encryptedMessage.ephemeralPublicKey!,
      type: KeyPairType.x25519,
    );

    // Get session keys (will perform ECDH)
    final sessionKeys =
        await _keyManager.getSessionKeys(senderId, senderEphemeralPublicKey);

    // Derive decryption key using HKDF
    final algorithm = Chacha20.poly1305Aead();
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );

    final decryptionKey = await hkdf.deriveKey(
      secretKey: sessionKeys.sharedSecret,
      info: utf8.encode('ble_mesh_private_message'),
      nonce: [],
    );

    // Decrypt message
    final secretBox = SecretBox(
      encryptedMessage.ciphertext,
      nonce: encryptedMessage.nonce,
      mac: encryptedMessage.mac,
    );

    final clearText = await algorithm.decrypt(
      secretBox,
      secretKey: decryptionKey,
    );

    return utf8.decode(clearText);
  }

  /// Encrypt channel message
  Future<EncryptedMessage> encryptChannelMessage({
    required String channel,
    required String content,
  }) async {
    // Get channel password
    final password = _keyManager.getChannelPassword(channel);
    if (password == null) {
      throw Exception('Channel not joined: $channel');
    }

    // Get channel key
    final channelKey = await _keyManager.deriveChannelKey(channel, password);

    // Encrypt with Chacha20-Poly1305
    final algorithm = Chacha20.poly1305Aead();
    final secretBox = await algorithm.encrypt(
      utf8.encode(content),
      secretKey: channelKey,
    );

    // Sign with identity key
    final dataToSign = [
      ...secretBox.cipherText,
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
    ];
    final signature = await _keyManager.sign(dataToSign);

    return EncryptedMessage(
      ciphertext: secretBox.cipherText,
      nonce: secretBox.nonce,
      mac: secretBox.mac,
      ephemeralPublicKey: null, // Not needed for channel messages
      signatureBytes: signature.bytes,
    );
  }

  /// Decrypt channel message
  Future<String> decryptChannelMessage({
    required String channel,
    required EncryptedMessage encryptedMessage,
    SimplePublicKey? senderPublicKey,
  }) async {
    // Verify signature if available
    if (encryptedMessage.signatureBytes != null && senderPublicKey != null) {
      final dataToVerify = [
        ...encryptedMessage.ciphertext,
        ...encryptedMessage.nonce,
        ...encryptedMessage.mac.bytes,
      ];

      final signature = Signature(
        encryptedMessage.signatureBytes!,
        publicKey: senderPublicKey,
      );

      final isValid = await _keyManager.verify(
        dataToVerify,
        signature,
        senderPublicKey,
      );

      if (!isValid) {
        throw Exception('Invalid signature');
      }
    }

    // Get channel password
    final password = _keyManager.getChannelPassword(channel);
    if (password == null) {
      throw Exception('Channel not joined: $channel');
    }

    // Get channel key
    final channelKey = await _keyManager.deriveChannelKey(channel, password);

    // Decrypt message
    final algorithm = Chacha20.poly1305Aead();
    final secretBox = SecretBox(
      encryptedMessage.ciphertext,
      nonce: encryptedMessage.nonce,
      mac: encryptedMessage.mac,
    );

    try {
      final clearText = await algorithm.decrypt(
        secretBox,
        secretKey: channelKey,
      );
      return utf8.decode(clearText);
    } catch (e) {
      throw Exception('Failed to decrypt channel message. Wrong password?');
    }
  }
}

