import 'package:flutter_test/flutter_test.dart';
import 'package:ble_mesh/ble_mesh.dart';

void main() {
  group('Peer Model Tests', () {
    group('Constructor and Basic Properties', () {
      test('should create a Peer with all required fields', () {
        final now = DateTime.now();
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'connection-123',
          nickname: 'TestPeer',
          rssi: -65,
          lastSeen: now,
          connectionState: PeerConnectionState.connected,
        );

        expect(peer.senderId, equals('AA:BB:CC:DD:EE:FF'));
        expect(peer.connectionId, equals('connection-123'));
        expect(peer.nickname, equals('TestPeer'));
        expect(peer.rssi, equals(-65));
        expect(peer.lastSeen, equals(now));
        expect(peer.connectionState, equals(PeerConnectionState.connected));
        expect(peer.hopCount, equals(0));
        expect(peer.lastForwardTime, isNull);
        expect(peer.isBlocked, isFalse);
      });

      test('should create a Peer with optional fields', () {
        final now = DateTime.now();
        final forwardTime = now.subtract(const Duration(seconds: 10));
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'connection-123',
          nickname: 'TestPeer',
          rssi: -65,
          lastSeen: now,
          connectionState: PeerConnectionState.connected,
          hopCount: 2,
          lastForwardTime: forwardTime,
          isBlocked: true,
        );

        expect(peer.hopCount, equals(2));
        expect(peer.lastForwardTime, equals(forwardTime));
        expect(peer.isBlocked, isTrue);
      });

      test('should handle null senderId', () {
        final now = DateTime.now();
        final peer = Peer(
          senderId: null,
          connectionId: 'connection-123',
          nickname: 'TestPeer',
          rssi: -65,
          lastSeen: now,
          connectionState: PeerConnectionState.discovered,
        );

        expect(peer.senderId, isNull);
        expect(peer.connectionId, equals('connection-123'));
      });
    });

    group('Connection States', () {
      test('should correctly identify connected state', () {
        final peer = Peer(
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connected,
        );

        expect(peer.connectionState, equals(PeerConnectionState.connected));
      });

      test('should correctly identify discovered state', () {
        final peer = Peer(
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        expect(peer.connectionState, equals(PeerConnectionState.discovered));
      });

      test('should correctly identify connecting state', () {
        final peer = Peer(
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connecting,
        );

        expect(peer.connectionState, equals(PeerConnectionState.connecting));
      });

      test('should correctly identify disconnecting state', () {
        final peer = Peer(
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.disconnecting,
        );

        expect(peer.connectionState, equals(PeerConnectionState.disconnecting));
      });

      test('should correctly identify disconnected state', () {
        final peer = Peer(
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.disconnected,
        );

        expect(peer.connectionState, equals(PeerConnectionState.disconnected));
      });
    });

    group('Blocklist Integration', () {
      test('should create non-blocked peer by default', () {
        final peer = Peer(
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        expect(peer.isBlocked, isFalse);
      });

      test('should create blocked peer when specified', () {
        final peer = Peer(
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: true,
        );

        expect(peer.isBlocked, isTrue);
      });
    });

    group('canConnect Property', () {
      test('should be true for discovered peer with senderId and not blocked', () {
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: false,
        );

        expect(peer.canConnect, isTrue);
      });

      test('should be false for peer without senderId', () {
        final peer = Peer(
          senderId: null,
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: false,
        );

        expect(peer.canConnect, isFalse);
      });

      test('should be false for blocked peer', () {
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: true,
        );

        expect(peer.canConnect, isFalse);
      });

      test('should be false for connected peer', () {
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connected,
          isBlocked: false,
        );

        expect(peer.canConnect, isFalse);
      });

      test('should be false for connecting peer', () {
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connecting,
          isBlocked: false,
        );

        expect(peer.canConnect, isFalse);
      });
    });

    group('Serialization', () {
      test('should serialize to map correctly', () {
        final now = DateTime.now();
        final forwardTime = now.subtract(const Duration(seconds: 5));
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'connection-123',
          nickname: 'TestPeer',
          rssi: -65,
          lastSeen: now,
          connectionState: PeerConnectionState.connected,
          hopCount: 2,
          lastForwardTime: forwardTime,
          isBlocked: true,
        );

        final map = peer.toMap();

        expect(map['senderId'], equals('AA:BB:CC:DD:EE:FF'));
        expect(map['connectionId'], equals('connection-123'));
        expect(map['id'], equals('connection-123')); // Backward compatibility
        expect(map['nickname'], equals('TestPeer'));
        expect(map['rssi'], equals(-65));
        expect(map['lastSeen'], equals(now.millisecondsSinceEpoch));
        expect(map['connectionState'], equals('connected'));
        expect(map['hopCount'], equals(2));
        expect(map['lastForwardTime'], equals(forwardTime.millisecondsSinceEpoch));
        expect(map['isBlocked'], isTrue);
      });

      test('should deserialize from map correctly', () {
        final now = DateTime.now();
        final forwardTime = now.subtract(const Duration(seconds: 5));
        final map = {
          'senderId': 'AA:BB:CC:DD:EE:FF',
          'connectionId': 'connection-123',
          'nickname': 'TestPeer',
          'rssi': -65,
          'lastSeen': now.millisecondsSinceEpoch,
          'connectionState': 'connected',
          'hopCount': 2,
          'lastForwardTime': forwardTime.millisecondsSinceEpoch,
          'isBlocked': true,
        };

        final peer = Peer.fromMap(map);

        expect(peer.senderId, equals('AA:BB:CC:DD:EE:FF'));
        expect(peer.connectionId, equals('connection-123'));
        expect(peer.nickname, equals('TestPeer'));
        expect(peer.rssi, equals(-65));
        expect(peer.lastSeen.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
        expect(peer.connectionState, equals(PeerConnectionState.connected));
        expect(peer.hopCount, equals(2));
        expect(peer.lastForwardTime?.millisecondsSinceEpoch, equals(forwardTime.millisecondsSinceEpoch));
        expect(peer.isBlocked, isTrue);
      });

      test('should handle backward compatibility with id field', () {
        final now = DateTime.now();
        final map = {
          'id': 'connection-123', // Old field name
          'nickname': 'TestPeer',
          'rssi': -65,
          'lastSeen': now.millisecondsSinceEpoch,
        };

        final peer = Peer.fromMap(map);

        expect(peer.connectionId, equals('connection-123'));
        expect(peer.id, equals('connection-123')); // Backward compatibility getter
      });

      test('should handle missing optional fields in deserialization', () {
        final now = DateTime.now();
        final map = {
          'connectionId': 'connection-123',
          'nickname': 'TestPeer',
          'rssi': -65,
          'lastSeen': now.millisecondsSinceEpoch,
        };

        final peer = Peer.fromMap(map);

        expect(peer.senderId, isNull);
        expect(peer.connectionState, equals(PeerConnectionState.discovered)); // Default
        expect(peer.hopCount, equals(0)); // Default
        expect(peer.lastForwardTime, isNull);
        expect(peer.isBlocked, isFalse); // Default
      });

      test('should handle null senderId in serialization', () {
        final peer = Peer(
          senderId: null,
          connectionId: 'connection-123',
          nickname: 'TestPeer',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        final map = peer.toMap();

        expect(map['senderId'], isNull);
      });

      test('should roundtrip serialize and deserialize', () {
        final now = DateTime.now();
        final original = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'connection-123',
          nickname: 'TestPeer',
          rssi: -65,
          lastSeen: now,
          connectionState: PeerConnectionState.connected,
          hopCount: 2,
          isBlocked: true,
        );

        final map = original.toMap();
        final deserialized = Peer.fromMap(map);

        expect(deserialized.senderId, equals(original.senderId));
        expect(deserialized.connectionId, equals(original.connectionId));
        expect(deserialized.nickname, equals(original.nickname));
        expect(deserialized.rssi, equals(original.rssi));
        expect(deserialized.connectionState, equals(original.connectionState));
        expect(deserialized.hopCount, equals(original.hopCount));
        expect(deserialized.isBlocked, equals(original.isBlocked));
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when senderIds match', () {
        final peer1 = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'connection-1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connected,
        );

        final peer2 = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'connection-2', // Different connectionId
          nickname: 'Peer2', // Different nickname
          rssi: -70, // Different RSSI
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered, // Different state
        );

        expect(peer1, equals(peer2));
        expect(peer1.hashCode, equals(peer2.hashCode));
      });

      test('should not be equal when senderIds differ', () {
        final peer1 = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'connection-123',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connected,
        );

        final peer2 = Peer(
          senderId: 'AA:BB:CC:DD:EE:00',
          connectionId: 'connection-123', // Same connectionId
          nickname: 'Peer1', // Same nickname
          rssi: -65, // Same RSSI
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connected,
        );

        expect(peer1, isNot(equals(peer2)));
      });

      test('should fall back to connectionId when senderId is null', () {
        final peer1 = Peer(
          senderId: null,
          connectionId: 'connection-123',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        final peer2 = Peer(
          senderId: null,
          connectionId: 'connection-123',
          nickname: 'Peer2', // Different nickname
          rssi: -70, // Different RSSI
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        expect(peer1, equals(peer2));
        expect(peer1.hashCode, equals(peer2.hashCode));
      });

      test('should not be equal when connectionIds differ and senderId is null', () {
        final peer1 = Peer(
          senderId: null,
          connectionId: 'connection-123',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        final peer2 = Peer(
          senderId: null,
          connectionId: 'connection-456',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        expect(peer1, isNot(equals(peer2)));
      });

      test('should be equal to itself', () {
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'connection-123',
          nickname: 'TestPeer',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connected,
        );

        expect(peer, equals(peer));
        expect(identical(peer, peer), isTrue);
      });
    });

    group('toString', () {
      test('should provide readable string representation', () {
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'connection-123',
          nickname: 'TestPeer',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connected,
          hopCount: 2,
        );

        final str = peer.toString();

        expect(str, contains('AA:BB:CC:DD:EE:FF'));
        expect(str, contains('connection-123'));
        expect(str, contains('TestPeer'));
        expect(str, contains('-65'));
        expect(str, contains('connected'));
        expect(str, contains('2'));
      });
    });

    group('Backward Compatibility', () {
      test('should provide id getter for backward compatibility', () {
        final peer = Peer(
          connectionId: 'connection-123',
          nickname: 'TestPeer',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connected,
        );

        expect(peer.id, equals('connection-123'));
        expect(peer.id, equals(peer.connectionId));
      });
    });
  });
}

