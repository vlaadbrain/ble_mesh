import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Represents an encrypted message with all necessary metadata
class EncryptedMessage {
  final List<int> ciphertext;
  final List<int> nonce;
  final Mac mac;
  final List<int>? ephemeralPublicKey; // For X25519 key exchange
  final List<int>? signatureBytes; // For authenticity (stored as bytes)
  final List<int>? signingPublicKey; // Sender's Ed25519 signing public key for verification

  EncryptedMessage({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    this.ephemeralPublicKey,
    this.signatureBytes,
    this.signingPublicKey,
  });

  /// Get signature from bytes
  Signature? getSignature(SimplePublicKey publicKey) {
    if (signatureBytes == null) return null;
    return Signature(signatureBytes!, publicKey: publicKey);
  }

  /// Serialize to bytes for transmission
  List<int> toBytes() {
    final buffer = BytesBuilder();

    // Write lengths and data
    // Format: [ciphertext_len(4)][ciphertext][nonce_len(4)][nonce][mac_len(4)][mac]
    //         [has_ephemeral(1)][ephemeral_len(4)][ephemeral][has_sig(1)][sig_len(4)][sig]
    //         [has_signing_key(1)][signing_key_len(4)][signing_key]

    // Ciphertext
    _writeInt32(buffer, ciphertext.length);
    buffer.add(ciphertext);

    // Nonce
    _writeInt32(buffer, nonce.length);
    buffer.add(nonce);

    // MAC
    final macBytes = mac.bytes;
    _writeInt32(buffer, macBytes.length);
    buffer.add(macBytes);

    // Ephemeral public key (optional)
    if (ephemeralPublicKey != null) {
      buffer.addByte(1); // has ephemeral key
      _writeInt32(buffer, ephemeralPublicKey!.length);
      buffer.add(ephemeralPublicKey!);
    } else {
      buffer.addByte(0); // no ephemeral key
    }

    // Signature (optional)
    if (signatureBytes != null) {
      buffer.addByte(1); // has signature
      _writeInt32(buffer, signatureBytes!.length);
      buffer.add(signatureBytes!);
    } else {
      buffer.addByte(0); // no signature
    }

    // Signing public key (optional)
    if (signingPublicKey != null) {
      buffer.addByte(1); // has signing public key
      _writeInt32(buffer, signingPublicKey!.length);
      buffer.add(signingPublicKey!);
    } else {
      buffer.addByte(0); // no signing public key
    }

    return buffer.toBytes();
  }

  /// Deserialize from bytes
  static EncryptedMessage fromBytes(List<int> bytes) {
    final data = Uint8List.fromList(bytes);
    int offset = 0;

    // Read ciphertext
    final ciphertextLen = _readInt32(data, offset);
    offset += 4;
    final ciphertext = data.sublist(offset, offset + ciphertextLen);
    offset += ciphertextLen;

    // Read nonce
    final nonceLen = _readInt32(data, offset);
    offset += 4;
    final nonce = data.sublist(offset, offset + nonceLen);
    offset += nonceLen;

    // Read MAC
    final macLen = _readInt32(data, offset);
    offset += 4;
    final macBytes = data.sublist(offset, offset + macLen);
    offset += macLen;
    final mac = Mac(macBytes);

    // Read ephemeral public key (optional)
    List<int>? ephemeralPublicKey;
    final hasEphemeral = data[offset] == 1;
    offset += 1;
    if (hasEphemeral) {
      final ephemeralLen = _readInt32(data, offset);
      offset += 4;
      ephemeralPublicKey = data.sublist(offset, offset + ephemeralLen);
      offset += ephemeralLen;
    }

    // Read signature (optional)
    List<int>? signatureBytes;
    final hasSignature = data[offset] == 1;
    offset += 1;
    if (hasSignature) {
      final sigLen = _readInt32(data, offset);
      offset += 4;
      signatureBytes = data.sublist(offset, offset + sigLen);
      offset += sigLen;
    }

    // Read signing public key (optional)
    List<int>? signingPublicKey;
    if (offset < data.length) {
      final hasSigningKey = data[offset] == 1;
      offset += 1;
      if (hasSigningKey) {
        final signingKeyLen = _readInt32(data, offset);
        offset += 4;
        signingPublicKey = data.sublist(offset, offset + signingKeyLen);
        offset += signingKeyLen;
      }
    }

    return EncryptedMessage(
      ciphertext: ciphertext,
      nonce: nonce,
      mac: mac,
      ephemeralPublicKey: ephemeralPublicKey,
      signatureBytes: signatureBytes,
      signingPublicKey: signingPublicKey,
    );
  }

  /// Helper to write 32-bit integer (big-endian)
  static void _writeInt32(BytesBuilder buffer, int value) {
    buffer.addByte((value >> 24) & 0xFF);
    buffer.addByte((value >> 16) & 0xFF);
    buffer.addByte((value >> 8) & 0xFF);
    buffer.addByte(value & 0xFF);
  }

  /// Helper to read 32-bit integer (big-endian)
  static int _readInt32(Uint8List data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  @override
  String toString() {
    return 'EncryptedMessage(ciphertext: ${ciphertext.length} bytes, '
        'nonce: ${nonce.length} bytes, mac: ${mac.bytes.length} bytes, '
        'hasEphemeralKey: ${ephemeralPublicKey != null}, '
        'hasSignature: ${signatureBytes != null}, '
        'hasSigningKey: ${signingPublicKey != null})';
  }
}

