import 'package:flutter_test/flutter_test.dart';
import 'package:ble_mesh/ble_mesh.dart';

void main() {
  group('Connection State Tests', () {
    group('PeerConnectionState Enum', () {
      test('should have all expected states', () {
        expect(PeerConnectionState.values.length, equals(5));
        expect(PeerConnectionState.values, contains(PeerConnectionState.discovered));
        expect(PeerConnectionState.values, contains(PeerConnectionState.connecting));
        expect(PeerConnectionState.values, contains(PeerConnectionState.connected));
        expect(PeerConnectionState.values, contains(PeerConnectionState.disconnecting));
        expect(PeerConnectionState.values, contains(PeerConnectionState.disconnected));
      });

      test('should have correct string names', () {
        expect(PeerConnectionState.discovered.name, equals('discovered'));
        expect(PeerConnectionState.connecting.name, equals('connecting'));
        expect(PeerConnectionState.connected.name, equals('connected'));
        expect(PeerConnectionState.disconnecting.name, equals('disconnecting'));
        expect(PeerConnectionState.disconnected.name, equals('disconnected'));
      });
    });

    group('State Transitions', () {
      test('discovered -> connecting is valid transition', () {
        final discovered = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        final connecting = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connecting,
        );

        expect(discovered.connectionState, equals(PeerConnectionState.discovered));
        expect(connecting.connectionState, equals(PeerConnectionState.connecting));
        expect(discovered.canConnect, isTrue);
        expect(connecting.canConnect, isFalse);
      });

      test('connecting -> connected is valid transition', () {
        final connecting = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connecting,
        );

        final connected = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connected,
        );

        expect(connecting.connectionState, isNot(equals(PeerConnectionState.connected)));
        expect(connected.connectionState, equals(PeerConnectionState.connected));
      });

      test('connected -> disconnecting is valid transition', () {
        final connected = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connected,
        );

        final disconnecting = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.disconnecting,
        );

        expect(connected.connectionState, equals(PeerConnectionState.connected));
        expect(disconnecting.connectionState, isNot(equals(PeerConnectionState.connected)));
      });

      test('disconnecting -> disconnected is valid transition', () {
        final disconnecting = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.disconnecting,
        );

        final disconnected = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.disconnected,
        );

        expect(disconnecting.connectionState, equals(PeerConnectionState.disconnecting));
        expect(disconnected.connectionState, equals(PeerConnectionState.disconnected));
      });

      test('connecting -> disconnected on failure is valid', () {
        final connecting = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connecting,
        );

        final disconnected = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.disconnected,
        );

        expect(connecting.connectionState, isNot(equals(PeerConnectionState.connected)));
        expect(disconnected.connectionState, isNot(equals(PeerConnectionState.connected)));
      });
    });

    group('State-Based Behavior', () {
      test('only discovered peers can be connected', () {
        final states = [
          PeerConnectionState.discovered,
          PeerConnectionState.connecting,
          PeerConnectionState.connected,
          PeerConnectionState.disconnecting,
          PeerConnectionState.disconnected,
        ];

        for (final state in states) {
          final peer = Peer(
            senderId: 'AA:BB:CC:DD:EE:FF',
            connectionId: 'test-id',
            nickname: 'Test',
            rssi: -70,
            lastSeen: DateTime.now(),
            connectionState: state,
          );

          if (state == PeerConnectionState.discovered) {
            expect(peer.canConnect, isTrue, reason: 'Discovered peer should be connectable');
          } else {
            expect(peer.canConnect, isFalse, reason: '$state peer should not be connectable');
          }
        }
      });

      test('only connected state should have PeerConnectionState.connected', () {
        final states = [
          PeerConnectionState.discovered,
          PeerConnectionState.connecting,
          PeerConnectionState.connected,
          PeerConnectionState.disconnecting,
          PeerConnectionState.disconnected,
        ];

        for (final state in states) {
          final peer = Peer(
            connectionId: 'test-id',
            nickname: 'Test',
            rssi: -70,
            lastSeen: DateTime.now(),
            connectionState: state,
          );

          if (state == PeerConnectionState.connected) {
            expect(peer.connectionState, equals(PeerConnectionState.connected), reason: 'Connected peer should have connected state');
          } else {
            expect(peer.connectionState, isNot(equals(PeerConnectionState.connected)), reason: '$state peer should not have connected state');
          }
        }
      });
    });

    group('State Serialization', () {
      test('should serialize all connection states correctly', () {
        final states = [
          PeerConnectionState.discovered,
          PeerConnectionState.connecting,
          PeerConnectionState.connected,
          PeerConnectionState.disconnecting,
          PeerConnectionState.disconnected,
        ];

        for (final state in states) {
          final peer = Peer(
            connectionId: 'test-id',
            nickname: 'Test',
            rssi: -70,
            lastSeen: DateTime.now(),
            connectionState: state,
          );

          final map = peer.toMap();
          expect(map['connectionState'], equals(state.name));
        }
      });

      test('should deserialize all connection states correctly', () {
        final stateNames = ['discovered', 'connecting', 'connected', 'disconnecting', 'disconnected'];

        for (final stateName in stateNames) {
          final map = {
            'connectionId': 'test-id',
            'nickname': 'Test',
            'rssi': -70,
            'lastSeen': DateTime.now().millisecondsSinceEpoch,
            'connectionState': stateName,
          };

          final peer = Peer.fromMap(map);
          expect(peer.connectionState.name, equals(stateName));
        }
      });

      test('should default to discovered state when missing', () {
        final map = {
          'connectionId': 'test-id',
          'nickname': 'Test',
          'rssi': -70,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        };

        final peer = Peer.fromMap(map);
        expect(peer.connectionState, equals(PeerConnectionState.discovered));
      });

      test('should default to discovered state for invalid state string', () {
        final map = {
          'connectionId': 'test-id',
          'nickname': 'Test',
          'rssi': -70,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'connectionState': 'invalid_state',
        };

        final peer = Peer.fromMap(map);
        expect(peer.connectionState, equals(PeerConnectionState.discovered));
      });
    });

    group('State Interaction with Blocklist', () {
      test('blocked peer in discovered state cannot connect', () {
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: true,
        );

        expect(peer.isBlocked, isTrue);
        expect(peer.canConnect, isFalse);
      });

      test('blocked peer in connected state should not be connectable', () {
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.connected,
          isBlocked: true,
        );

        expect(peer.isBlocked, isTrue);
        expect(peer.connectionState, equals(PeerConnectionState.connected)); // Still connected
        expect(peer.canConnect, isFalse); // But not connectable
      });

      test('non-blocked peer in discovered state can connect', () {
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: false,
        );

        expect(peer.isBlocked, isFalse);
        expect(peer.canConnect, isTrue);
      });
    });

    group('State Interaction with SenderId', () {
      test('peer without senderId cannot connect regardless of state', () {
        final peer = Peer(
          senderId: null,
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: false,
        );

        expect(peer.senderId, isNull);
        expect(peer.canConnect, isFalse);
      });

      test('peer with senderId in discovered state can connect', () {
        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: false,
        );

        expect(peer.senderId, isNotNull);
        expect(peer.canConnect, isTrue);
      });
    });

    group('Complex State Scenarios', () {
      test('typical discovery and connection lifecycle', () {
        final now = DateTime.now();

        // 1. Peer is discovered
        final discovered = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: now,
          connectionState: PeerConnectionState.discovered,
        );
        expect(discovered.canConnect, isTrue);
        expect(discovered.connectionState, isNot(equals(PeerConnectionState.connected)));

        // 2. Connection initiated
        final connecting = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: now.add(const Duration(seconds: 1)),
          connectionState: PeerConnectionState.connecting,
        );
        expect(connecting.canConnect, isFalse);
        expect(connecting.connectionState, isNot(equals(PeerConnectionState.connected)));

        // 3. Connection established
        final connected = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: now.add(const Duration(seconds: 2)),
          connectionState: PeerConnectionState.connected,
        );
        expect(connected.canConnect, isFalse);
        expect(connected.connectionState, equals(PeerConnectionState.connected));

        // 4. Disconnection initiated
        final disconnecting = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: now.add(const Duration(seconds: 3)),
          connectionState: PeerConnectionState.disconnecting,
        );
        expect(disconnecting.canConnect, isFalse);
        expect(disconnecting.connectionState, isNot(equals(PeerConnectionState.connected)));

        // 5. Disconnected
        final disconnected = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: now.add(const Duration(seconds: 4)),
          connectionState: PeerConnectionState.disconnected,
        );
        expect(disconnected.canConnect, isFalse);
        expect(disconnected.connectionState, isNot(equals(PeerConnectionState.connected)));
      });

      test('connection failure scenario', () {
        final now = DateTime.now();

        // 1. Peer discovered
        final discovered = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: now,
          connectionState: PeerConnectionState.discovered,
        );
        expect(discovered.canConnect, isTrue);

        // 2. Connection attempt
        final connecting = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: now.add(const Duration(seconds: 1)),
          connectionState: PeerConnectionState.connecting,
        );
        expect(connecting.connectionState, isNot(equals(PeerConnectionState.connected)));

        // 3. Connection failed - goes directly to disconnected
        final disconnected = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: now.add(const Duration(seconds: 2)),
          connectionState: PeerConnectionState.disconnected,
        );
        expect(disconnected.connectionState, isNot(equals(PeerConnectionState.connected)));
        expect(disconnected.canConnect, isFalse);
      });

      test('peer blocking during connection lifecycle', () {
        final now = DateTime.now();

        // Connected peer gets blocked
        final connectedBlocked = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: now,
          connectionState: PeerConnectionState.connected,
          isBlocked: true,
        );
        expect(connectedBlocked.connectionState, equals(PeerConnectionState.connected));
        expect(connectedBlocked.isBlocked, isTrue);
        expect(connectedBlocked.canConnect, isFalse);

        // After blocking, peer should be disconnected
        final disconnectedBlocked = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: now.add(const Duration(seconds: 1)),
          connectionState: PeerConnectionState.disconnected,
          isBlocked: true,
        );
        expect(disconnectedBlocked.connectionState, isNot(equals(PeerConnectionState.connected)));
        expect(disconnectedBlocked.isBlocked, isTrue);
        expect(disconnectedBlocked.canConnect, isFalse);
      });
    });
  });
}

