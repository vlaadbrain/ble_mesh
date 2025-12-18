import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ble_mesh/services/device_id_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Clear all shared preferences before each test
    SharedPreferences.setMockInitialValues({});
  });

  group('DeviceIdManager', () {
    test('generates UUID on first call', () async {
      final deviceId = await DeviceIdManager.getOrCreateDeviceId();

      // UUID should be 36 characters (including hyphens)
      expect(deviceId.length, 36);
      expect(deviceId, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')));
    });

    test('returns same UUID on subsequent calls', () async {
      final deviceId1 = await DeviceIdManager.getOrCreateDeviceId();
      final deviceId2 = await DeviceIdManager.getOrCreateDeviceId();
      final deviceId3 = await DeviceIdManager.getOrCreateDeviceId();

      expect(deviceId1, deviceId2);
      expect(deviceId2, deviceId3);
    });

    test('generates unique UUIDs for different test runs', () async {
      final deviceId1 = await DeviceIdManager.getOrCreateDeviceId();

      // Reset and generate new ID
      await DeviceIdManager.resetDeviceId();
      final deviceId2 = await DeviceIdManager.getOrCreateDeviceId();

      expect(deviceId1, isNot(deviceId2));
    });

    test('compact ID is 6 bytes', () async {
      final compactId = await DeviceIdManager.getCompactId();

      expect(compactId.length, 6);
    });

    test('compact ID string has correct format', () async {
      final compactIdString = await DeviceIdManager.getCompactIdString();

      // Format: XX:XX:XX:XX:XX:XX
      expect(compactIdString, matches(RegExp(r'^[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}$')));
    });

    test('compact ID is consistent across calls', () async {
      final compactId1 = await DeviceIdManager.getCompactId();
      final compactId2 = await DeviceIdManager.getCompactId();

      expect(compactId1, compactId2);
    });

    test('compactIdFromUuid extracts first 6 bytes correctly', () {
      final uuid = '550e8400-e29b-41d4-a716-446655440000';
      final compactId = DeviceIdManager.compactIdFromUuid(uuid);

      expect(compactId.length, 6);
      expect(compactId[0], 0x55);
      expect(compactId[1], 0x0e);
      expect(compactId[2], 0x84);
      expect(compactId[3], 0x00);
      expect(compactId[4], 0xe2);
      expect(compactId[5], 0x9b);
    });

    test('compactIdToString formats bytes correctly', () {
      final bytes = Uint8List.fromList([0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]);
      final compactIdString = DeviceIdManager.compactIdToString(bytes);

      expect(compactIdString, '55:0E:84:00:E2:9B');
    });

    test('compactIdStringToBytes parses string correctly', () {
      final compactIdString = '55:0E:84:00:E2:9B';
      final bytes = DeviceIdManager.compactIdStringToBytes(compactIdString);

      expect(bytes.length, 6);
      expect(bytes[0], 0x55);
      expect(bytes[1], 0x0e);
      expect(bytes[2], 0x84);
      expect(bytes[3], 0x00);
      expect(bytes[4], 0xe2);
      expect(bytes[5], 0x9b);
    });

    test('round-trip conversion preserves data', () {
      final uuid = '550e8400-e29b-41d4-a716-446655440000';

      // UUID -> bytes
      final bytes = DeviceIdManager.compactIdFromUuid(uuid);

      // bytes -> string
      final compactIdString = DeviceIdManager.compactIdToString(bytes);

      // string -> bytes
      final bytesAgain = DeviceIdManager.compactIdStringToBytes(compactIdString);

      expect(bytesAgain, bytes);
    });

    test('resetDeviceId clears stored ID', () async {
      final deviceId1 = await DeviceIdManager.getOrCreateDeviceId();
      expect(await DeviceIdManager.hasDeviceId(), true);

      await DeviceIdManager.resetDeviceId();
      expect(await DeviceIdManager.hasDeviceId(), false);

      final deviceId2 = await DeviceIdManager.getOrCreateDeviceId();
      expect(deviceId1, isNot(deviceId2));
    });

    test('hasDeviceId returns correct status', () async {
      expect(await DeviceIdManager.hasDeviceId(), false);

      await DeviceIdManager.getOrCreateDeviceId();
      expect(await DeviceIdManager.hasDeviceId(), true);

      await DeviceIdManager.resetDeviceId();
      expect(await DeviceIdManager.hasDeviceId(), false);
    });

    test('compactIdFromUuid throws on invalid UUID', () {
      expect(
        () => DeviceIdManager.compactIdFromUuid('invalid-uuid'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => DeviceIdManager.compactIdFromUuid(''),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => DeviceIdManager.compactIdFromUuid('12345'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('compactIdToString throws on invalid length', () {
      expect(
        () => DeviceIdManager.compactIdToString(Uint8List(5)),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => DeviceIdManager.compactIdToString(Uint8List(7)),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => DeviceIdManager.compactIdToString(Uint8List(0)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('compactIdStringToBytes throws on invalid format', () {
      expect(
        () => DeviceIdManager.compactIdStringToBytes('AA:BB:CC:DD:EE'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => DeviceIdManager.compactIdStringToBytes('AA:BB:CC:DD:EE:FF:GG'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => DeviceIdManager.compactIdStringToBytes('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles various UUID formats', () {
      final testUuids = [
        '550e8400-e29b-41d4-a716-446655440000',
        '00000000-0000-0000-0000-000000000000',
        'ffffffff-ffff-ffff-ffff-ffffffffffff',
        'abcdef12-3456-7890-abcd-ef1234567890',
      ];

      for (final uuid in testUuids) {
        final compactId = DeviceIdManager.compactIdFromUuid(uuid);
        expect(compactId.length, 6);

        final compactIdString = DeviceIdManager.compactIdToString(compactId);
        expect(compactIdString, matches(RegExp(r'^[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}$')));

        final bytesAgain = DeviceIdManager.compactIdStringToBytes(compactIdString);
        expect(bytesAgain, compactId);
      }
    });

    test('compact ID is derived from UUID consistently', () async {
      final deviceId = await DeviceIdManager.getOrCreateDeviceId();
      final compactId1 = await DeviceIdManager.getCompactId();

      // Manually compute compact ID from UUID
      final compactId2 = DeviceIdManager.compactIdFromUuid(deviceId);

      expect(compactId1, compactId2);
    });

    test('compact ID string is derived from compact ID consistently', () async {
      final compactId = await DeviceIdManager.getCompactId();
      final compactIdString1 = await DeviceIdManager.getCompactIdString();

      // Manually compute string from bytes
      final compactIdString2 = DeviceIdManager.compactIdToString(compactId);

      expect(compactIdString1, compactIdString2);
    });
  });
}

