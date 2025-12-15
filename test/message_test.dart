import 'package:flutter_test/flutter_test.dart';
import 'package:ble_mesh/models/message.dart';

void main() {
  group('Message', () {
    // Helper function to create a test message with default values
    Message createTestMessage({
      String id = 'test-id-123',
      String senderId = 'AA:BB:CC:DD:EE:FF',
      String senderNickname = 'TestUser',
      String content = 'Test message',
      MessageType type = MessageType.public,
      DateTime? timestamp,
      String? channel,
      bool isEncrypted = false,
      DeliveryStatus status = DeliveryStatus.sent,
      int ttl = 7,
      int hopCount = 0,
      String? messageId,
      bool isForwarded = false,
    }) {
      return Message(
        id: id,
        senderId: senderId,
        senderNickname: senderNickname,
        content: content,
        type: type,
        timestamp: timestamp ?? DateTime.now(),
        channel: channel,
        isEncrypted: isEncrypted,
        status: status,
        ttl: ttl,
        hopCount: hopCount,
        messageId: messageId ?? id,
        isForwarded: isForwarded,
      );
    }

    group('Constructor and Basic Creation', () {
      test('creates message with all required fields', () {
        final timestamp = DateTime.now();
        final message = Message(
          id: 'msg-1',
          senderId: 'AA:BB:CC:DD:EE:FF',
          senderNickname: 'Alice',
          content: 'Hello, World!',
          type: MessageType.public,
          timestamp: timestamp,
          messageId: 'msg-1',
        );

        expect(message.id, 'msg-1');
        expect(message.senderId, 'AA:BB:CC:DD:EE:FF');
        expect(message.senderNickname, 'Alice');
        expect(message.content, 'Hello, World!');
        expect(message.type, MessageType.public);
        expect(message.timestamp, timestamp);
        expect(message.messageId, 'msg-1');
      });

      test('creates message with default values for optional fields', () {
        final message = createTestMessage();

        expect(message.isEncrypted, false);
        expect(message.status, DeliveryStatus.sent);
        expect(message.ttl, 7);
        expect(message.hopCount, 0);
        expect(message.isForwarded, false);
        expect(message.channel, null);
      });

      test('creates message with custom routing fields', () {
        final message = createTestMessage(
          ttl: 5,
          hopCount: 2,
          isForwarded: true,
        );

        expect(message.ttl, 5);
        expect(message.hopCount, 2);
        expect(message.isForwarded, true);
      });
    });

    group('fromMap Factory Constructor', () {
      test('creates message from map with all fields', () {
        final timestamp = DateTime.now();
        final map = {
          'id': 'msg-1',
          'senderId': 'AA:BB:CC:DD:EE:FF',
          'senderNickname': 'Alice',
          'content': 'Hello',
          'type': MessageType.public.index,
          'timestamp': timestamp.millisecondsSinceEpoch,
          'channel': null,
          'isEncrypted': false,
          'status': DeliveryStatus.sent.index,
          'ttl': 7,
          'hopCount': 0,
          'messageId': 'msg-1',
          'isForwarded': false,
        };

        final message = Message.fromMap(map);

        expect(message.id, 'msg-1');
        expect(message.senderId, 'AA:BB:CC:DD:EE:FF');
        expect(message.senderNickname, 'Alice');
        expect(message.content, 'Hello');
        expect(message.type, MessageType.public);
        expect(message.timestamp.millisecondsSinceEpoch, timestamp.millisecondsSinceEpoch);
        expect(message.channel, null);
        expect(message.isEncrypted, false);
        expect(message.status, DeliveryStatus.sent);
        expect(message.ttl, 7);
        expect(message.hopCount, 0);
        expect(message.messageId, 'msg-1');
        expect(message.isForwarded, false);
      });

      test('creates message with optional fields', () {
        final map = {
          'id': 'msg-1',
          'senderId': 'AA:BB:CC:DD:EE:FF',
          'senderNickname': 'Alice',
          'content': 'Hello',
          'type': MessageType.channel.index,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'channel': 'general',
          'isEncrypted': true,
          'status': DeliveryStatus.delivered.index,
          'ttl': 5,
          'hopCount': 2,
          'messageId': 'msg-1',
          'isForwarded': true,
        };

        final message = Message.fromMap(map);

        expect(message.channel, 'general');
        expect(message.isEncrypted, true);
        expect(message.status, DeliveryStatus.delivered);
        expect(message.hopCount, 2);
        expect(message.isForwarded, true);
      });

      test('creates message with default values when routing fields are missing', () {
        final map = {
          'id': 'msg-1',
          'senderId': 'AA:BB:CC:DD:EE:FF',
          'senderNickname': 'Alice',
          'content': 'Hello',
          'type': MessageType.public.index,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        final message = Message.fromMap(map);

        expect(message.ttl, 7);
        expect(message.hopCount, 0);
        expect(message.messageId, 'msg-1'); // Falls back to id
        expect(message.isForwarded, false);
        expect(message.isEncrypted, false);
        expect(message.status, DeliveryStatus.pending);
      });

      test('creates messages with all MessageType values', () {
        for (final type in MessageType.values) {
          final map = {
            'id': 'msg-1',
            'senderId': 'AA:BB:CC:DD:EE:FF',
            'senderNickname': 'Alice',
            'content': 'Test',
            'type': type.index,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'messageId': 'msg-1',
          };

          final message = Message.fromMap(map);
          expect(message.type, type);
        }
      });
    });

    group('toMap Serialization', () {
      test('converts message to map with all fields', () {
        final timestamp = DateTime.now();
        final message = Message(
          id: 'msg-1',
          senderId: 'AA:BB:CC:DD:EE:FF',
          senderNickname: 'Alice',
          content: 'Hello',
          type: MessageType.public,
          timestamp: timestamp,
          channel: 'general',
          isEncrypted: true,
          status: DeliveryStatus.sent,
          ttl: 5,
          hopCount: 2,
          messageId: 'msg-1',
          isForwarded: true,
        );

        final map = message.toMap();

        expect(map['id'], 'msg-1');
        expect(map['senderId'], 'AA:BB:CC:DD:EE:FF');
        expect(map['senderNickname'], 'Alice');
        expect(map['content'], 'Hello');
        expect(map['type'], MessageType.public.index);
        expect(map['timestamp'], timestamp.millisecondsSinceEpoch);
        expect(map['channel'], 'general');
        expect(map['isEncrypted'], true);
        expect(map['status'], DeliveryStatus.sent.index);
        expect(map['ttl'], 5);
        expect(map['hopCount'], 2);
        expect(map['messageId'], 'msg-1');
        expect(map['isForwarded'], true);
      });

      test('includes routing fields in map', () {
        final message = createTestMessage(
          ttl: 3,
          hopCount: 4,
          messageId: 'routing-123',
          isForwarded: true,
        );

        final map = message.toMap();

        expect(map['ttl'], 3);
        expect(map['hopCount'], 4);
        expect(map['messageId'], 'routing-123');
        expect(map['isForwarded'], true);
      });

      test('serializes all message types correctly', () {
        final types = [
          MessageType.public,
          MessageType.private,
          MessageType.channel,
          MessageType.system,
        ];

        for (final type in types) {
          final message = createTestMessage(type: type);
          final map = message.toMap();
          expect(map['type'], type.index);
        }
      });

      test('serializes all delivery statuses correctly', () {
        final statuses = [
          DeliveryStatus.pending,
          DeliveryStatus.sent,
          DeliveryStatus.delivered,
          DeliveryStatus.failed,
        ];

        for (final status in statuses) {
          final message = createTestMessage(status: status);
          final map = message.toMap();
          expect(map['status'], status.index);
        }
      });
    });

    group('Round-trip Serialization', () {
      test('toMap -> fromMap preserves all fields', () {
        final timestamp = DateTime.now();
        final original = Message(
          id: 'msg-1',
          senderId: 'AA:BB:CC:DD:EE:FF',
          senderNickname: 'Alice',
          content: 'Test message',
          type: MessageType.private,
          timestamp: timestamp,
          channel: 'general',
          isEncrypted: true,
          status: DeliveryStatus.delivered,
          ttl: 5,
          hopCount: 2,
          messageId: 'routing-123',
          isForwarded: true,
        );

        final map = original.toMap();
        final deserialized = Message.fromMap(map);

        expect(deserialized.id, original.id);
        expect(deserialized.senderId, original.senderId);
        expect(deserialized.senderNickname, original.senderNickname);
        expect(deserialized.content, original.content);
        expect(deserialized.type, original.type);
        expect(deserialized.timestamp.millisecondsSinceEpoch, original.timestamp.millisecondsSinceEpoch);
        expect(deserialized.channel, original.channel);
        expect(deserialized.isEncrypted, original.isEncrypted);
        expect(deserialized.status, original.status);
        expect(deserialized.ttl, original.ttl);
        expect(deserialized.hopCount, original.hopCount);
        expect(deserialized.messageId, original.messageId);
        expect(deserialized.isForwarded, original.isForwarded);
      });

      test('round-trip works for all message types', () {
        for (final type in MessageType.values) {
          final original = createTestMessage(type: type);
          final map = original.toMap();
          final deserialized = Message.fromMap(map);
          expect(deserialized.type, type);
        }
      });

      test('round-trip preserves routing fields', () {
        final testCases = [
          (7, 0, false), // Original message
          (5, 2, true),  // Forwarded twice
          (1, 6, true),  // Nearly expired
          (10, 0, false), // High TTL
        ];

        for (final (ttl, hopCount, isForwarded) in testCases) {
          final original = createTestMessage(
            ttl: ttl,
            hopCount: hopCount,
            isForwarded: isForwarded,
          );

          final map = original.toMap();
          final deserialized = Message.fromMap(map);

          expect(deserialized.ttl, ttl, reason: 'TTL should match');
          expect(deserialized.hopCount, hopCount, reason: 'Hop count should match');
          expect(deserialized.isForwarded, isForwarded, reason: 'isForwarded should match');
        }
      });
    });

    group('copyWith Method', () {
      test('copyWith with no parameters returns identical message', () {
        final original = createTestMessage();
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.senderId, original.senderId);
        expect(copy.content, original.content);
        expect(copy.type, original.type);
        expect(copy.ttl, original.ttl);
        expect(copy.hopCount, original.hopCount);
      });

      test('copyWith updates single field', () {
        final original = createTestMessage(content: 'Original');
        final copy = original.copyWith(content: 'Updated');

        expect(copy.content, 'Updated');
        expect(copy.id, original.id);
        expect(copy.senderId, original.senderId);
      });

      test('copyWith updates multiple fields', () {
        final original = createTestMessage(
          content: 'Original',
          status: DeliveryStatus.pending,
        );
        final copy = original.copyWith(
          content: 'Updated',
          status: DeliveryStatus.sent,
        );

        expect(copy.content, 'Updated');
        expect(copy.status, DeliveryStatus.sent);
        expect(copy.id, original.id);
      });

      test('copyWith updates routing fields', () {
        final original = createTestMessage(
          ttl: 7,
          hopCount: 0,
          isForwarded: false,
        );
        final copy = original.copyWith(
          ttl: 6,
          hopCount: 1,
          isForwarded: true,
        );

        expect(copy.ttl, 6);
        expect(copy.hopCount, 1);
        expect(copy.isForwarded, true);
      });

      test('copyWith can update delivery status', () {
        final original = createTestMessage(status: DeliveryStatus.pending);

        final sent = original.copyWith(status: DeliveryStatus.sent);
        expect(sent.status, DeliveryStatus.sent);

        final delivered = sent.copyWith(status: DeliveryStatus.delivered);
        expect(delivered.status, DeliveryStatus.delivered);

        final failed = original.copyWith(status: DeliveryStatus.failed);
        expect(failed.status, DeliveryStatus.failed);
      });
    });

    group('Routing Fields', () {
      test('default routing fields are correct', () {
        final message = Message(
          id: 'msg-1',
          senderId: 'AA:BB:CC:DD:EE:FF',
          senderNickname: 'Alice',
          content: 'Test',
          type: MessageType.public,
          timestamp: DateTime.now(),
          messageId: 'msg-1',
        );

        expect(message.ttl, 7);
        expect(message.hopCount, 0);
        expect(message.isForwarded, false);
      });

      test('custom routing fields are preserved', () {
        final message = Message(
          id: 'msg-1',
          senderId: 'AA:BB:CC:DD:EE:FF',
          senderNickname: 'Alice',
          content: 'Test',
          type: MessageType.public,
          timestamp: DateTime.now(),
          ttl: 3,
          hopCount: 4,
          messageId: 'routing-123',
          isForwarded: true,
        );

        expect(message.ttl, 3);
        expect(message.hopCount, 4);
        expect(message.messageId, 'routing-123');
        expect(message.isForwarded, true);
      });

      test('forwarded message has correct properties', () {
        final message = createTestMessage(
          ttl: 5,
          hopCount: 2,
          isForwarded: true,
        );

        expect(message.isForwarded, true);
        expect(message.hopCount, greaterThan(0));
        expect(message.ttl, lessThan(7));
      });
    });

    group('Equality and HashCode', () {
      test('messages with same ID are equal', () {
        final message1 = createTestMessage(id: 'same-id');
        final message2 = createTestMessage(id: 'same-id');

        expect(message1, equals(message2));
      });

      test('messages with different IDs are not equal', () {
        final message1 = createTestMessage(id: 'id-1');
        final message2 = createTestMessage(id: 'id-2');

        expect(message1, isNot(equals(message2)));
      });

      test('messages with same ID but different content are equal', () {
        final message1 = createTestMessage(id: 'same-id', content: 'Content 1');
        final message2 = createTestMessage(id: 'same-id', content: 'Content 2');

        expect(message1, equals(message2));
      });

      test('hashCode is consistent for same message', () {
        final message = createTestMessage();
        final hash1 = message.hashCode;
        final hash2 = message.hashCode;

        expect(hash1, equals(hash2));
      });

      test('hashCode is based on ID only', () {
        final message1 = createTestMessage(id: 'same-id', content: 'Content 1');
        final message2 = createTestMessage(id: 'same-id', content: 'Content 2');

        expect(message1.hashCode, equals(message2.hashCode));
      });

      test('messages with different IDs have different hashCodes', () {
        final message1 = createTestMessage(id: 'id-1');
        final message2 = createTestMessage(id: 'id-2');

        expect(message1.hashCode, isNot(equals(message2.hashCode)));
      });
    });

    group('toString Method', () {
      test('toString returns formatted string', () {
        final message = createTestMessage(
          id: 'msg-1',
          senderNickname: 'Alice',
          content: 'Hello',
          type: MessageType.public,
        );

        final str = message.toString();

        expect(str.contains('Message'), true);
        expect(str.contains('msg-1'), true);
        expect(str.contains('Alice'), true);
        expect(str.contains('Hello'), true);
      });
    });

    group('Edge Cases', () {
      test('message with empty content', () {
        final message = createTestMessage(content: '');

        expect(message.content, '');

        final map = message.toMap();
        final deserialized = Message.fromMap(map);
        expect(deserialized.content, '');
      });

      test('message with long content', () {
        final longContent = 'A' * 200;
        final message = createTestMessage(content: longContent);

        expect(message.content.length, 200);

        final map = message.toMap();
        final deserialized = Message.fromMap(map);
        expect(deserialized.content, longContent);
      });

      test('message with Unicode characters', () {
        final unicodeContent = 'Hello 世界 🌍 Привет مرحبا';
        final message = createTestMessage(content: unicodeContent);

        expect(message.content, unicodeContent);

        final map = message.toMap();
        final deserialized = Message.fromMap(map);
        expect(deserialized.content, unicodeContent);
      });

      test('message with special characters', () {
        final specialContent = 'Line1\nLine2\tTabbed\r\nWindows"Quotes"\'Single\'';
        final message = createTestMessage(content: specialContent);

        expect(message.content, specialContent);

        final map = message.toMap();
        final deserialized = Message.fromMap(map);
        expect(deserialized.content, specialContent);
      });

      test('message with null channel', () {
        final message = createTestMessage(channel: null);

        expect(message.channel, null);

        final map = message.toMap();
        expect(map['channel'], null);

        final deserialized = Message.fromMap(map);
        expect(deserialized.channel, null);
      });
    });

    group('Message Types', () {
      test('creates public message', () {
        final message = createTestMessage(type: MessageType.public);

        expect(message.type, MessageType.public);
        expect(message.channel, null);
      });

      test('creates private message', () {
        final message = createTestMessage(
          type: MessageType.private,
          isEncrypted: true,
        );

        expect(message.type, MessageType.private);
        expect(message.isEncrypted, true);
      });

      test('creates channel message with channel name', () {
        final message = createTestMessage(
          type: MessageType.channel,
          channel: 'general',
        );

        expect(message.type, MessageType.channel);
        expect(message.channel, 'general');
      });

      test('creates system message', () {
        final message = createTestMessage(type: MessageType.system);

        expect(message.type, MessageType.system);
      });
    });

    group('Delivery Status', () {
      test('message with pending status', () {
        final message = createTestMessage(status: DeliveryStatus.pending);
        expect(message.status, DeliveryStatus.pending);
      });

      test('message with sent status', () {
        final message = createTestMessage(status: DeliveryStatus.sent);
        expect(message.status, DeliveryStatus.sent);
      });

      test('message with delivered status', () {
        final message = createTestMessage(status: DeliveryStatus.delivered);
        expect(message.status, DeliveryStatus.delivered);
      });

      test('message with failed status', () {
        final message = createTestMessage(status: DeliveryStatus.failed);
        expect(message.status, DeliveryStatus.failed);
      });
    });

    group('Timestamp Handling', () {
      test('timestamp is preserved in round-trip', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 45);
        final message = createTestMessage(timestamp: timestamp);

        final map = message.toMap();
        final deserialized = Message.fromMap(map);

        expect(
          deserialized.timestamp.millisecondsSinceEpoch,
          timestamp.millisecondsSinceEpoch,
        );
      });

      test('timestamp converts correctly to/from milliseconds', () {
        final now = DateTime.now();
        final message = createTestMessage(timestamp: now);

        final map = message.toMap();
        expect(map['timestamp'], now.millisecondsSinceEpoch);

        final deserialized = Message.fromMap(map);
        expect(
          deserialized.timestamp.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch,
        );
      });
    });
  });
}

