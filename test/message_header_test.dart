import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ble_mesh/models/message_header.dart';

void main() {
  group('MessageHeader', () {
    test('serialization creates 20-byte header', () {
      final messageId = MessageHeader.generateMessageId();
      final senderId = '55:0E:84:00:E2:9B'; // Compact device ID
      final header = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 7,
        hopCount: 0,
        messageId: messageId,
        senderId: senderId,
        payloadLength: 13,
      );

      final bytes = header.toBytes();

      expect(bytes.length, MessageHeader.headerSize);
      expect(bytes[0], MessageHeader.protocolVersion);
      expect(bytes[1], MessageHeader.typePublic);
      expect(bytes[2], 7); // TTL
      expect(bytes[3], 0); // hop count
    });

    test('deserialization parses header correctly', () {
      final messageId = 123456789;
      final senderId = 'A1:B2:C3:D4:E5:F6'; // Compact device ID
      final header = MessageHeader(
        type: MessageHeader.typeChannel,
        ttl: 5,
        hopCount: 2,
        messageId: messageId,
        senderId: senderId,
        payloadLength: 100,
      );

      final bytes = header.toBytes();
      final deserialized = MessageHeader.fromBytes(bytes);

      expect(deserialized.version, header.version);
      expect(deserialized.type, header.type);
      expect(deserialized.ttl, header.ttl);
      expect(deserialized.hopCount, header.hopCount);
      expect(deserialized.messageId, header.messageId);
      expect(deserialized.senderId, header.senderId);
      expect(deserialized.payloadLength, header.payloadLength);
    });

    test('round-trip serialization preserves all fields', () {
      final testCases = [
        (MessageHeader.typePublic, 'AA:BB:CC:DD:EE:FF', 7),
        (MessageHeader.typePrivate, '11:22:33:44:55:66', 5),
        (MessageHeader.typeChannel, 'FF:EE:DD:CC:BB:AA', 3),
        (MessageHeader.typePeerAnnouncement, '00:11:22:33:44:55', 1),
      ];

      for (var i = 0; i < testCases.length; i++) {
        final (type, senderId, ttl) = testCases[i];
        final header = MessageHeader(
          type: type,
          ttl: ttl,
          hopCount: 0,
          messageId: MessageHeader.generateMessageId(),
          senderId: senderId,
          payloadLength: i * 10,
        );

        final bytes = header.toBytes();
        final deserialized = MessageHeader.fromBytes(bytes);

        expect(deserialized.type, header.type, reason: 'Test case $i: Type should match');
        expect(deserialized.ttl, header.ttl, reason: 'Test case $i: TTL should match');
        expect(deserialized.senderId, header.senderId, reason: 'Test case $i: Sender ID should match');
        expect(deserialized.payloadLength, header.payloadLength, reason: 'Test case $i: Payload length should match');
      }
    });

    test('prepareForForward decrements TTL and increments hop count', () {
      final header = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 7,
        hopCount: 0,
        messageId: 12345,
        senderId: 'AA:BB:CC:DD:EE:FF',
        payloadLength: 10,
      );

      expect(header.ttl, 7);
      expect(header.hopCount, 0);
      expect(header.canForward(), true);

      header.prepareForForward();
      expect(header.ttl, 6);
      expect(header.hopCount, 1);
      expect(header.canForward(), true);

      // Forward multiple times
      for (var i = 0; i < 5; i++) {
        header.prepareForForward();
      }
      expect(header.ttl, 1);
      expect(header.hopCount, 6);
      expect(header.canForward(), false);
    });

    test('canForward returns correct values', () {
      final header1 = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 2,
        hopCount: 0,
        messageId: 1,
        senderId: 'AA:BB:CC:DD:EE:FF',
        payloadLength: 10,
      );
      expect(header1.canForward(), true);

      final header2 = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 1,
        hopCount: 0,
        messageId: 2,
        senderId: 'AA:BB:CC:DD:EE:FF',
        payloadLength: 10,
      );
      expect(header2.canForward(), false);

      final header3 = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 0,
        hopCount: 5,
        messageId: 3,
        senderId: 'AA:BB:CC:DD:EE:FF',
        payloadLength: 10,
      );
      expect(header3.canForward(), false);
    });

    test('generateMessageId creates unique IDs', () {
      final ids = <int>{};
      for (var i = 0; i < 1000; i++) {
        final id = MessageHeader.generateMessageId();
        expect(ids.contains(id), false, reason: 'Message ID should be unique');
        ids.add(id);
      }
      expect(ids.length, 1000);
    });

    test('getTypeString returns correct strings', () {
      final types = {
        MessageHeader.typePublic: 'PUBLIC',
        MessageHeader.typePrivate: 'PRIVATE',
        MessageHeader.typeChannel: 'CHANNEL',
        MessageHeader.typePeerAnnouncement: 'PEER_ANNOUNCEMENT',
        MessageHeader.typeAcknowledgment: 'ACKNOWLEDGMENT',
        MessageHeader.typeKeyExchange: 'KEY_EXCHANGE',
        MessageHeader.typeStoreForward: 'STORE_FORWARD',
        MessageHeader.typeRoutingUpdate: 'ROUTING_UPDATE',
      };

      types.forEach((type, expectedString) {
        final header = MessageHeader(
          type: type,
          ttl: 7,
          hopCount: 0,
          messageId: 1,
          senderId: 'AA:BB:CC:DD:EE:FF',
          payloadLength: 10,
        );
        expect(header.getTypeString(), expectedString);
      });
    });

    test('fromBytes throws on too small data', () {
      final smallData = Uint8List(10);
      expect(
        () => MessageHeader.fromBytes(smallData),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fromBytes throws on invalid protocol version', () {
      final header = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 7,
        hopCount: 0,
        messageId: 1,
        senderId: 'AA:BB:CC:DD:EE:FF',
        payloadLength: 10,
      );
      final bytes = header.toBytes();

      // Modify version byte to be invalid
      bytes[0] = 0x99;

      expect(
        () => MessageHeader.fromBytes(bytes),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('compact device ID formats are handled correctly', () {
      final deviceIds = [
        'AA:BB:CC:DD:EE:FF',
        '00:11:22:33:44:55',
        'FF:FF:FF:FF:FF:FF',
        '00:00:00:00:00:00',
        '55:0E:84:00:E2:9B',
        'A1:B2:C3:D4:E5:F6',
      ];

      for (final deviceId in deviceIds) {
        final header = MessageHeader(
          type: MessageHeader.typePublic,
          ttl: 7,
          hopCount: 0,
          messageId: 1,
          senderId: deviceId,
          payloadLength: 10,
        );

        final bytes = header.toBytes();
        final deserialized = MessageHeader.fromBytes(bytes);

        expect(deserialized.senderId, deviceId, reason: 'Device ID should match: $deviceId');
      }
    });

    test('toMap returns correct dictionary', () {
      final header = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 7,
        hopCount: 2,
        messageId: 123456789,
        senderId: 'AA:BB:CC:DD:EE:FF',
        payloadLength: 100,
      );

      final map = header.toMap();

      expect(map['version'], 1);
      expect(map['type'], 1);
      expect(map['ttl'], 7);
      expect(map['hopCount'], 2);
      expect(map['messageId'], '123456789');
      expect(map['senderId'], 'AA:BB:CC:DD:EE:FF');
      expect(map['payloadLength'], 100);
    });

    test('fromMap creates header correctly', () {
      final map = {
        'version': 1,
        'type': MessageHeader.typePublic,
        'ttl': 7,
        'hopCount': 2,
        'messageId': '123456789',
        'senderId': 'AA:BB:CC:DD:EE:FF',
        'payloadLength': 100,
      };

      final header = MessageHeader.fromMap(map);

      expect(header.version, 1);
      expect(header.type, MessageHeader.typePublic);
      expect(header.ttl, 7);
      expect(header.hopCount, 2);
      expect(header.messageId, 123456789);
      expect(header.senderId, 'AA:BB:CC:DD:EE:FF');
      expect(header.payloadLength, 100);
    });

    test('equality operator works correctly', () {
      final header1 = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 7,
        hopCount: 0,
        messageId: 123,
        senderId: 'AA:BB:CC:DD:EE:FF',
        payloadLength: 10,
      );

      final header2 = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 7,
        hopCount: 0,
        messageId: 123,
        senderId: 'AA:BB:CC:DD:EE:FF',
        payloadLength: 10,
      );

      final header3 = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 5,
        hopCount: 0,
        messageId: 123,
        senderId: 'AA:BB:CC:DD:EE:FF',
        payloadLength: 10,
      );

      expect(header1, header2);
      expect(header1, isNot(header3));
    });

    test('hashCode is consistent', () {
      final header = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 7,
        hopCount: 0,
        messageId: 123,
        senderId: 'AA:BB:CC:DD:EE:FF',
        payloadLength: 10,
      );

      final hash1 = header.hashCode;
      final hash2 = header.hashCode;

      expect(hash1, hash2);
    });

    test('toString returns formatted string', () {
      final header = MessageHeader(
        type: MessageHeader.typePublic,
        ttl: 7,
        hopCount: 2,
        messageId: 123456789,
        senderId: 'AA:BB:CC:DD:EE:FF',
        payloadLength: 100,
      );

      final str = header.toString();

      expect(str.contains('MessageHeader'), true);
      expect(str.contains('PUBLIC'), true);
      expect(str.contains('ttl=7'), true);
      expect(str.contains('hopCount=2'), true);
    });
  });
}

