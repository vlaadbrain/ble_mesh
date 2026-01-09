import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:ble_mesh/models/encrypted_message.dart';

void main() {
  group('EncryptedMessage', () {
    group('Constructor', () {
      test('should create EncryptedMessage with all fields', () {
        final message = EncryptedMessage(
          ciphertext: [1, 2, 3, 4, 5],
          nonce: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
          mac: Mac([100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]),
          ephemeralPublicKey: List.generate(32, (i) => i),
          signatureBytes: List.generate(64, (i) => i + 100),
          signingPublicKey: List.generate(32, (i) => i + 200),
        );

        expect(message.ciphertext, equals([1, 2, 3, 4, 5]));
        expect(message.nonce, hasLength(12));
        expect(message.mac.bytes, hasLength(16));
        expect(message.ephemeralPublicKey, hasLength(32));
        expect(message.signatureBytes, hasLength(64));
        expect(message.signingPublicKey, hasLength(32));
      });

      test('should create EncryptedMessage with optional fields as null', () {
        final message = EncryptedMessage(
          ciphertext: [1, 2, 3],
          nonce: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
          mac: Mac([100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]),
          ephemeralPublicKey: null,
          signatureBytes: null,
          signingPublicKey: null,
        );

        expect(message.ephemeralPublicKey, isNull);
        expect(message.signatureBytes, isNull);
        expect(message.signingPublicKey, isNull);
      });
    });

    group('Serialization (toBytes)', () {
      test('should serialize message with all fields', () {
        final message = EncryptedMessage(
          ciphertext: [1, 2, 3, 4, 5],
          nonce: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
          mac: Mac([100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]),
          ephemeralPublicKey: List.generate(32, (i) => i),
          signatureBytes: List.generate(64, (i) => i + 100),
        );

        final bytes = message.toBytes();
        expect(bytes, isNotEmpty);
        // Verify we can read it back
        final deserialized = EncryptedMessage.fromBytes(bytes);
        expect(deserialized.ciphertext, equals(message.ciphertext));
      });

      test('should serialize message without optional fields', () {
        final message = EncryptedMessage(
          ciphertext: [1, 2, 3],
          nonce: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
          mac: Mac([100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]),
          ephemeralPublicKey: null,
          signatureBytes: null,
        );

        final bytes = message.toBytes();
        expect(bytes, isNotEmpty);

        final deserialized = EncryptedMessage.fromBytes(bytes);
        expect(deserialized.ephemeralPublicKey, isNull);
        expect(deserialized.signatureBytes, isNull);
      });

      test('should serialize empty ciphertext', () {
        final message = EncryptedMessage(
          ciphertext: [],
          nonce: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
          mac: Mac([100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]),
        );

        final bytes = message.toBytes();
        final deserialized = EncryptedMessage.fromBytes(bytes);
        expect(deserialized.ciphertext, isEmpty);
      });

      test('should serialize large ciphertext', () {
        final largeCiphertext = List.generate(10000, (i) => i % 256);
        final message = EncryptedMessage(
          ciphertext: largeCiphertext,
          nonce: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
          mac: Mac([100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]),
        );

        final bytes = message.toBytes();
        final deserialized = EncryptedMessage.fromBytes(bytes);
        expect(deserialized.ciphertext, equals(largeCiphertext));
      });
    });

    group('Deserialization (fromBytes)', () {
      test('should deserialize message with all fields', () {
        final original = EncryptedMessage(
          ciphertext: [1, 2, 3, 4, 5, 6, 7, 8],
          nonce: List.generate(12, (i) => i + 20),
          mac: Mac(List.generate(16, (i) => i + 50)),
          ephemeralPublicKey: List.generate(32, (i) => i + 100),
          signatureBytes: List.generate(64, (i) => i + 150),
        );

        final bytes = original.toBytes();
        final deserialized = EncryptedMessage.fromBytes(bytes);

        expect(deserialized.ciphertext, equals(original.ciphertext));
        expect(deserialized.nonce, equals(original.nonce));
        expect(deserialized.mac.bytes, equals(original.mac.bytes));
        expect(deserialized.ephemeralPublicKey, equals(original.ephemeralPublicKey));
        expect(deserialized.signatureBytes, equals(original.signatureBytes));
      });

      test('should deserialize message without ephemeral key', () {
        final original = EncryptedMessage(
          ciphertext: [1, 2, 3],
          nonce: List.generate(12, (i) => i),
          mac: Mac(List.generate(16, (i) => i)),
          ephemeralPublicKey: null,
          signatureBytes: List.generate(64, (i) => i),
        );

        final bytes = original.toBytes();
        final deserialized = EncryptedMessage.fromBytes(bytes);

        expect(deserialized.ephemeralPublicKey, isNull);
        expect(deserialized.signatureBytes, isNotNull);
      });

      test('should deserialize message without signature', () {
        final original = EncryptedMessage(
          ciphertext: [1, 2, 3],
          nonce: List.generate(12, (i) => i),
          mac: Mac(List.generate(16, (i) => i)),
          ephemeralPublicKey: List.generate(32, (i) => i),
          signatureBytes: null,
        );

        final bytes = original.toBytes();
        final deserialized = EncryptedMessage.fromBytes(bytes);

        expect(deserialized.ephemeralPublicKey, isNotNull);
        expect(deserialized.signatureBytes, isNull);
      });
    });

    group('getSignature', () {
      test('should return Signature when signatureBytes is present', () {
        final signatureBytes = List.generate(64, (i) => i);
        final message = EncryptedMessage(
          ciphertext: [1, 2, 3],
          nonce: List.generate(12, (i) => i),
          mac: Mac(List.generate(16, (i) => i)),
          signatureBytes: signatureBytes,
        );

        final publicKey = SimplePublicKey(
          List.generate(32, (i) => i),
          type: KeyPairType.ed25519,
        );

        final signature = message.getSignature(publicKey);
        expect(signature, isNotNull);
        expect(signature!.bytes, equals(signatureBytes));
        expect(signature.publicKey, equals(publicKey));
      });

      test('should return null when signatureBytes is null', () {
        final message = EncryptedMessage(
          ciphertext: [1, 2, 3],
          nonce: List.generate(12, (i) => i),
          mac: Mac(List.generate(16, (i) => i)),
          signatureBytes: null,
        );

        final publicKey = SimplePublicKey(
          List.generate(32, (i) => i),
          type: KeyPairType.ed25519,
        );

        final signature = message.getSignature(publicKey);
        expect(signature, isNull);
      });
    });

    group('toString', () {
      test('should return readable string representation', () {
        final message = EncryptedMessage(
          ciphertext: List.generate(100, (i) => i),
          nonce: List.generate(12, (i) => i),
          mac: Mac(List.generate(16, (i) => i)),
          ephemeralPublicKey: List.generate(32, (i) => i),
          signatureBytes: List.generate(64, (i) => i),
        );

        final str = message.toString();
        expect(str, contains('EncryptedMessage'));
        expect(str, contains('100 bytes'));
        expect(str, contains('hasEphemeralKey: true'));
        expect(str, contains('hasSignature: true'));
      });

      test('should show false for missing optional fields', () {
        final message = EncryptedMessage(
          ciphertext: [1, 2, 3],
          nonce: List.generate(12, (i) => i),
          mac: Mac(List.generate(16, (i) => i)),
          ephemeralPublicKey: null,
          signatureBytes: null,
        );

        final str = message.toString();
        expect(str, contains('hasEphemeralKey: false'));
        expect(str, contains('hasSignature: false'));
      });
    });

    group('Binary Format Integrity', () {
      test('should preserve byte order in serialization', () {
        // Test with specific byte values to ensure endianness is correct
        final message = EncryptedMessage(
          ciphertext: [0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD],
          nonce: List.generate(12, (i) => 0xAA),
          mac: Mac(List.generate(16, (i) => 0xBB)),
          ephemeralPublicKey: List.generate(32, (i) => 0xCC),
          signatureBytes: List.generate(64, (i) => 0xDD),
        );

        final bytes = message.toBytes();
        final deserialized = EncryptedMessage.fromBytes(bytes);

        expect(deserialized.ciphertext, equals([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD]));
        expect(deserialized.nonce, everyElement(equals(0xAA)));
        expect(deserialized.mac.bytes, everyElement(equals(0xBB)));
        expect(deserialized.ephemeralPublicKey, everyElement(equals(0xCC)));
        expect(deserialized.signatureBytes, everyElement(equals(0xDD)));
      });

      test('should handle maximum length values correctly', () {
        // Test with ciphertext length that tests 32-bit integer encoding
        final largeCiphertext = List.generate(65536, (i) => i % 256);
        final message = EncryptedMessage(
          ciphertext: largeCiphertext,
          nonce: List.generate(12, (i) => i),
          mac: Mac(List.generate(16, (i) => i)),
        );

        final bytes = message.toBytes();
        final deserialized = EncryptedMessage.fromBytes(bytes);

        expect(deserialized.ciphertext.length, equals(65536));
        expect(deserialized.ciphertext, equals(largeCiphertext));
      });
    });

    group('Edge Cases', () {
      test('should handle minimum valid nonce length', () {
        final message = EncryptedMessage(
          ciphertext: [1],
          nonce: [1], // Minimum length
          mac: Mac([1]),
        );

        final bytes = message.toBytes();
        final deserialized = EncryptedMessage.fromBytes(bytes);

        expect(deserialized.nonce, equals([1]));
      });

      test('should handle minimum valid MAC length', () {
        final message = EncryptedMessage(
          ciphertext: [1],
          nonce: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
          mac: Mac([1]), // Minimum length
        );

        final bytes = message.toBytes();
        final deserialized = EncryptedMessage.fromBytes(bytes);

        expect(deserialized.mac.bytes, equals([1]));
      });

      test('should serialize and deserialize with only required fields', () {
        final message = EncryptedMessage(
          ciphertext: [1, 2, 3],
          nonce: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
          mac: Mac([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
        );

        final bytes = message.toBytes();
        final deserialized = EncryptedMessage.fromBytes(bytes);

        expect(deserialized.ciphertext, equals([1, 2, 3]));
        expect(deserialized.ephemeralPublicKey, isNull);
        expect(deserialized.signatureBytes, isNull);
      });
    });
  });
}

