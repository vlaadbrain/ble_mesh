import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Manages persistent device identity for BLE mesh networking
///
/// Generates and stores a stable UUID-based device identifier that persists
/// across app restarts. This replaces the unreliable MAC address-based
/// identification system.
///
/// Device ID Format:
/// - Full ID: UUID v4 (128-bit), e.g., "550e8400-e29b-41d4-a716-446655440000"
/// - Compact ID: First 6 bytes (48-bit), e.g., [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
/// - String format: "55:0E:84:00:E2:9B" (for display/logging)
class DeviceIdManager {
  static const String _deviceIdKey = 'ble_mesh_device_id';
  static const Uuid _uuidGenerator = Uuid();

  /// Get or create the device UUID
  ///
  /// On first call, generates a new UUID v4 and stores it persistently.
  /// Subsequent calls return the stored UUID.
  ///
  /// Returns: UUID string in format "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? existing = prefs.getString(_deviceIdKey);

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    // Generate new UUID v4
    final newId = _uuidGenerator.v4();
    await prefs.setString(_deviceIdKey, newId);
    return newId;
  }

  /// Get the compact device ID (first 6 bytes of UUID)
  ///
  /// This is used in the MessageHeader senderId field for efficient
  /// binary serialization.
  ///
  /// Returns: 6-byte Uint8List
  static Future<Uint8List> getCompactId() async {
    final uuid = await getOrCreateDeviceId();
    return compactIdFromUuid(uuid);
  }

  /// Get the compact device ID as a formatted string
  ///
  /// Returns: String in format "XX:XX:XX:XX:XX:XX" (e.g., "55:0E:84:00:E2:9B")
  static Future<String> getCompactIdString() async {
    final bytes = await getCompactId();
    return compactIdToString(bytes);
  }

  /// Convert UUID string to compact 6-byte representation
  ///
  /// Takes the first 12 hex characters (after removing hyphens) and converts
  /// them to a 6-byte array.
  ///
  /// Example:
  /// - Input: "550e8400-e29b-41d4-a716-446655440000"
  /// - Output: [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
  static Uint8List compactIdFromUuid(String uuid) {
    // Remove hyphens and take first 12 hex chars (6 bytes)
    final hex = uuid.replaceAll('-', '');
    if (hex.length < 12) {
      throw ArgumentError('Invalid UUID format: $uuid');
    }

    final compactHex = hex.substring(0, 12);
    final bytes = Uint8List(6);

    for (var i = 0; i < 6; i++) {
      final hexByte = compactHex.substring(i * 2, i * 2 + 2);
      bytes[i] = int.parse(hexByte, radix: 16);
    }

    return bytes;
  }

  /// Convert compact ID bytes to string format
  ///
  /// Example:
  /// - Input: [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
  /// - Output: "55:0E:84:00:E2:9B"
  static String compactIdToString(Uint8List bytes) {
    if (bytes.length != 6) {
      throw ArgumentError('Compact ID must be exactly 6 bytes, got ${bytes.length}');
    }

    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  /// Convert compact ID string to bytes
  ///
  /// Example:
  /// - Input: "55:0E:84:00:E2:9B"
  /// - Output: [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
  static Uint8List compactIdStringToBytes(String compactId) {
    final parts = compactId.split(':');
    if (parts.length != 6) {
      throw ArgumentError('Invalid compact ID format: $compactId (expected XX:XX:XX:XX:XX:XX)');
    }

    final bytes = Uint8List(6);
    for (var i = 0; i < 6; i++) {
      bytes[i] = int.parse(parts[i], radix: 16);
    }
    return bytes;
  }

  /// Reset the device ID (for testing or user-initiated reset)
  ///
  /// Deletes the stored UUID. Next call to getOrCreateDeviceId() will
  /// generate a new UUID.
  static Future<void> resetDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
  }

  /// Check if a device ID exists
  static Future<bool> hasDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    return existing != null && existing.isNotEmpty;
  }
}

