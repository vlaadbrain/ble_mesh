import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:ble_mesh/services/key_manager.dart';
import 'package:ble_mesh/services/encryption_service.dart';
import 'package:ble_mesh/models/encrypted_message.dart';

void main() {
  group('EncryptionService', () {
    late KeyManager senderKeyManager;
    late KeyManager recipientKeyManager;
    late EncryptionService senderEncryptionService;
    late EncryptionService recipientEncryptionService;

    setUp(() async {
      senderKeyManager = KeyManager();
      recipientKeyManager = KeyManager();
      await senderKeyManager.initialize();
      await recipientKeyManager.initialize();
      senderEncryptionService = EncryptionService(senderKeyManager);
      recipientEncryptionService = EncryptionService(recipientKeyManager);
    });

    tearDown(() {
      senderKeyManager.clearAllKeys();
      recipientKeyManager.clearAllKeys();
    });

    group('Private Message Encryption', () {
      test('should encrypt a private message', () async {
        const recipientId = 'recipient-123';
        const message = 'Hello, this is a secret message!';
        final recipientPublicKey = await recipientKeyManager.getIdentityDhPublicKey();

        final encryptedMessage = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: message,
        );

        expect(encryptedMessage, isNotNull);
        expect(encryptedMessage.ciphertext, isNotEmpty);
        expect(encryptedMessage.nonce, isNotEmpty);
        expect(encryptedMessage.mac, isNotNull);
        expect(encryptedMessage.ephemeralPublicKey, isNotNull);
        expect(encryptedMessage.signatureBytes, isNotNull);
      });

      test('should produce different ciphertext for same message (due to random nonce)', () async {
        const recipientId = 'recipient-123';
        const message = 'Same message twice';
        final recipientPublicKey = await recipientKeyManager.getIdentityDhPublicKey();

        final encrypted1 = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: message,
        );

        final encrypted2 = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: message,
        );

        // Nonces should be different (random)
        expect(encrypted1.nonce, isNot(equals(encrypted2.nonce)));
      });

      test('should encrypt empty message', () async {
        const recipientId = 'recipient-123';
        const message = '';
        final recipientPublicKey = await recipientKeyManager.getIdentityDhPublicKey();

        final encryptedMessage = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: message,
        );

        expect(encryptedMessage, isNotNull);
        expect(encryptedMessage.ciphertext, isEmpty); // Empty plaintext = empty ciphertext
      });

      test('should encrypt long message', () async {
        const recipientId = 'recipient-123';
        final message = 'A' * 10000; // 10KB message
        final recipientPublicKey = await recipientKeyManager.getIdentityDhPublicKey();

        final encryptedMessage = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: message,
        );

        expect(encryptedMessage, isNotNull);
        expect(encryptedMessage.ciphertext.length, equals(10000));
      });

      test('should encrypt message with unicode characters', () async {
        const recipientId = 'recipient-123';
        const message = 'Hello 你好 مرحبا 🎉🔐';
        final recipientPublicKey = await recipientKeyManager.getIdentityDhPublicKey();

        final encryptedMessage = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: message,
        );

        expect(encryptedMessage, isNotNull);
        expect(encryptedMessage.ciphertext, isNotEmpty);
      });
    });

    group('Private Message Decryption', () {
      test('should decrypt a private message (round-trip)', () async {
        const senderId = 'sender-123';
        const recipientId = 'recipient-123';
        const originalMessage = 'Hello, this is a secret message!';

        // Get public keys
        final senderPublicKey = await senderKeyManager.getIdentityDhPublicKey();
        final recipientPublicKey = await recipientKeyManager.getIdentityDhPublicKey();

        // Sender encrypts message for recipient
        final encryptedMessage = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: originalMessage,
        );

        // Recipient decrypts message from sender
        final decryptedMessage = await recipientEncryptionService.decryptPrivateMessage(
          senderId: senderId,
          senderPublicKey: senderPublicKey,
          encryptedMessage: encryptedMessage,
        );

        expect(decryptedMessage, equals(originalMessage));
      });

      test('should decrypt empty message', () async {
        const senderId = 'sender-123';
        const recipientId = 'recipient-123';
        const originalMessage = '';

        final senderPublicKey = await senderKeyManager.getIdentityDhPublicKey();
        final recipientPublicKey = await recipientKeyManager.getIdentityDhPublicKey();

        final encryptedMessage = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: originalMessage,
        );

        final decryptedMessage = await recipientEncryptionService.decryptPrivateMessage(
          senderId: senderId,
          senderPublicKey: senderPublicKey,
          encryptedMessage: encryptedMessage,
        );

        expect(decryptedMessage, equals(originalMessage));
      });

      test('should decrypt long message', () async {
        const senderId = 'sender-123';
        const recipientId = 'recipient-123';
        final originalMessage = 'B' * 10000;

        final senderPublicKey = await senderKeyManager.getIdentityDhPublicKey();
        final recipientPublicKey = await recipientKeyManager.getIdentityDhPublicKey();

        final encryptedMessage = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: originalMessage,
        );

        final decryptedMessage = await recipientEncryptionService.decryptPrivateMessage(
          senderId: senderId,
          senderPublicKey: senderPublicKey,
          encryptedMessage: encryptedMessage,
        );

        expect(decryptedMessage, equals(originalMessage));
      });

      test('should decrypt message with unicode characters', () async {
        const senderId = 'sender-123';
        const recipientId = 'recipient-123';
        const originalMessage = 'Hello 你好 مرحبا 🎉🔐';

        final senderPublicKey = await senderKeyManager.getIdentityDhPublicKey();
        final recipientPublicKey = await recipientKeyManager.getIdentityDhPublicKey();

        final encryptedMessage = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: originalMessage,
        );

        final decryptedMessage = await recipientEncryptionService.decryptPrivateMessage(
          senderId: senderId,
          senderPublicKey: senderPublicKey,
          encryptedMessage: encryptedMessage,
        );

        expect(decryptedMessage, equals(originalMessage));
      });

      test('should fail to decrypt with missing ephemeral public key', () async {
        const senderId = 'sender-123';
        final senderPublicKey = await senderKeyManager.getIdentityDhPublicKey();

        // Create an encrypted message without ephemeral public key
        final encryptedMessage = EncryptedMessage(
          ciphertext: [1, 2, 3],
          nonce: List.generate(12, (i) => i),
          mac: Mac([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
          ephemeralPublicKey: null,
          signatureBytes: null,
        );

        expect(
          () => recipientEncryptionService.decryptPrivateMessage(
            senderId: senderId,
            senderPublicKey: senderPublicKey,
            encryptedMessage: encryptedMessage,
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Missing ephemeral public key'),
          )),
        );
      });
    });

    group('Channel Message Encryption', () {
      test('should encrypt a channel message', () async {
        const channel = 'test-channel';
        const password = 'channel-password';
        const message = 'Hello channel!';

        // First, join the channel (derive key)
        await senderKeyManager.deriveChannelKey(channel, password);

        final encryptedMessage = await senderEncryptionService.encryptChannelMessage(
          channel: channel,
          content: message,
        );

        expect(encryptedMessage, isNotNull);
        expect(encryptedMessage.ciphertext, isNotEmpty);
        expect(encryptedMessage.nonce, isNotEmpty);
        expect(encryptedMessage.mac, isNotNull);
        expect(encryptedMessage.ephemeralPublicKey, isNull); // Not needed for channel messages
        expect(encryptedMessage.signatureBytes, isNotNull);
      });

      test('should fail to encrypt for non-joined channel', () async {
        const channel = 'not-joined-channel';
        const message = 'Hello channel!';

        expect(
          () => senderEncryptionService.encryptChannelMessage(
            channel: channel,
            content: message,
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Channel not joined'),
          )),
        );
      });
    });

    group('Channel Message Decryption', () {
      test('should decrypt a channel message (round-trip)', () async {
        const channel = 'test-channel';
        const password = 'channel-password';
        const originalMessage = 'Hello channel members!';

        // Both sender and recipient join the channel with same password
        await senderKeyManager.deriveChannelKey(channel, password);
        await recipientKeyManager.deriveChannelKey(channel, password);

        // Sender encrypts message
        final encryptedMessage = await senderEncryptionService.encryptChannelMessage(
          channel: channel,
          content: originalMessage,
        );

        // Recipient decrypts message
        final decryptedMessage = await recipientEncryptionService.decryptChannelMessage(
          channel: channel,
          encryptedMessage: encryptedMessage,
        );

        expect(decryptedMessage, equals(originalMessage));
      });

      test('should fail to decrypt with wrong password', () async {
        const channel = 'test-channel';
        const senderPassword = 'correct-password';
        const recipientPassword = 'wrong-password';
        const originalMessage = 'Secret channel message';

        // Sender and recipient join with different passwords
        await senderKeyManager.deriveChannelKey(channel, senderPassword);
        await recipientKeyManager.deriveChannelKey(channel, recipientPassword);

        // Sender encrypts message
        final encryptedMessage = await senderEncryptionService.encryptChannelMessage(
          channel: channel,
          content: originalMessage,
        );

        // Recipient tries to decrypt with wrong key
        expect(
          () => recipientEncryptionService.decryptChannelMessage(
            channel: channel,
            encryptedMessage: encryptedMessage,
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Wrong password'),
          )),
        );
      });

      test('should fail to decrypt for non-joined channel', () async {
        const channel = 'test-channel';
        const password = 'channel-password';
        const message = 'Hello channel!';

        // Only sender joins the channel
        await senderKeyManager.deriveChannelKey(channel, password);

        final encryptedMessage = await senderEncryptionService.encryptChannelMessage(
          channel: channel,
          content: message,
        );

        // Recipient has not joined
        expect(
          () => recipientEncryptionService.decryptChannelMessage(
            channel: channel,
            encryptedMessage: encryptedMessage,
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Channel not joined'),
          )),
        );
      });

      test('should decrypt channel message with unicode characters', () async {
        const channel = 'unicode-channel';
        const password = 'password';
        const originalMessage = 'Channel 频道 قناة 📺';

        await senderKeyManager.deriveChannelKey(channel, password);
        await recipientKeyManager.deriveChannelKey(channel, password);

        final encryptedMessage = await senderEncryptionService.encryptChannelMessage(
          channel: channel,
          content: originalMessage,
        );

        final decryptedMessage = await recipientEncryptionService.decryptChannelMessage(
          channel: channel,
          encryptedMessage: encryptedMessage,
        );

        expect(decryptedMessage, equals(originalMessage));
      });
    });

    group('Serialization Round-Trip', () {
      test('should serialize and deserialize encrypted message correctly', () async {
        const recipientId = 'recipient-123';
        const originalMessage = 'Test message for serialization';
        final recipientPublicKey = await recipientKeyManager.getIdentityDhPublicKey();

        // Encrypt
        final encryptedMessage = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: originalMessage,
        );

        // Serialize to bytes
        final bytes = encryptedMessage.toBytes();
        expect(bytes, isNotEmpty);

        // Deserialize from bytes
        final deserializedMessage = EncryptedMessage.fromBytes(bytes);

        // Verify all fields match
        expect(deserializedMessage.ciphertext, equals(encryptedMessage.ciphertext));
        expect(deserializedMessage.nonce, equals(encryptedMessage.nonce));
        expect(deserializedMessage.mac.bytes, equals(encryptedMessage.mac.bytes));
        expect(deserializedMessage.ephemeralPublicKey, equals(encryptedMessage.ephemeralPublicKey));
        expect(deserializedMessage.signatureBytes, equals(encryptedMessage.signatureBytes));
      });

      test('should decrypt message after serialization round-trip', () async {
        const senderId = 'sender-123';
        const recipientId = 'recipient-123';
        const originalMessage = 'Message surviving serialization';

        final senderPublicKey = await senderKeyManager.getIdentityDhPublicKey();
        final recipientPublicKey = await recipientKeyManager.getIdentityDhPublicKey();

        // Encrypt
        final encryptedMessage = await senderEncryptionService.encryptPrivateMessage(
          recipientId: recipientId,
          recipientPublicKey: recipientPublicKey,
          content: originalMessage,
        );

        // Serialize and deserialize (simulating network transmission)
        final bytes = encryptedMessage.toBytes();
        final receivedMessage = EncryptedMessage.fromBytes(bytes);

        // Decrypt
        final decryptedMessage = await recipientEncryptionService.decryptPrivateMessage(
          senderId: senderId,
          senderPublicKey: senderPublicKey,
          encryptedMessage: receivedMessage,
        );

        expect(decryptedMessage, equals(originalMessage));
      });
    });
  });
}

