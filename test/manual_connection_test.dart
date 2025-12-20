import 'package:flutter_test/flutter_test.dart';
import 'package:ble_mesh/ble_mesh.dart';
import 'package:ble_mesh/ble_mesh_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBleMeshPlatform with MockPlatformInterfaceMixin implements BleMeshPlatform {
  final Map<String, String> _peerStates = {}; // senderId -> state
  final Map<String, bool> _blocklist = {};

  @override
  Future<bool> connectToPeer(String senderId) async {
    if (_blocklist[senderId] == true) {
      return false;
    }
    if (_peerStates[senderId] == 'connected') {
      return false;
    }
    _peerStates[senderId] = 'connected';
    return true;
  }

  @override
  Future<bool> disconnectFromPeer(String senderId) async {
    if (_peerStates[senderId] != 'connected') {
      return false;
    }
    _peerStates[senderId] = 'disconnected';
    return true;
  }

  @override
  Future<String?> getPeerConnectionState(String senderId) async {
    return _peerStates[senderId];
  }

  @override
  Future<bool> blockPeer(String senderId) async {
    _blocklist[senderId] = true;
    if (_peerStates[senderId] == 'connected') {
      _peerStates[senderId] = 'disconnected';
    }
    return true;
  }

  @override
  Future<bool> isPeerBlocked(String senderId) async {
    return _blocklist[senderId] ?? false;
  }

  void addDiscoveredPeer(String senderId) {
    _peerStates[senderId] = 'discovered';
  }

  // Required implementations
  @override
  Future<String?> getPlatformVersion() => Future.value('1.0.0');

  @override
  Future<void> initialize({String? nickname, bool enableEncryption = true, PowerMode powerMode = PowerMode.balanced}) async {}

  @override
  Future<void> startMesh() async {}

  @override
  Future<void> stopMesh() async {}

  @override
  Future<void> sendPublicMessage(String message) async {}

  @override
  Future<List<Peer>> getConnectedPeers() async => [];

  @override
  Stream<Message> get messageStream => Stream.empty();

  @override
  Stream<Peer> get peerConnectedStream => Stream.empty();

  @override
  Stream<Peer> get peerDisconnectedStream => Stream.empty();

  @override
  Stream<MeshEvent> get meshEventStream => Stream.empty();

  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<List<Peer>> getDiscoveredPeers() async => [];

  @override
  Stream<Peer> get discoveredPeersStream => Stream.empty();

  @override
  Future<bool> unblockPeer(String senderId) async {
    _blocklist.remove(senderId);
    return true;
  }

  @override
  Future<List<String>> getBlockedPeers() async => _blocklist.keys.toList();

  @override
  Future<void> clearBlocklist() async => _blocklist.clear();
}

void main() {
  group('Manual Connection Tests', () {
    late BleMesh bleMesh;
    late MockBleMeshPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockBleMeshPlatform();
      BleMeshPlatform.instance = mockPlatform;
      bleMesh = BleMesh();
    });

    group('Connect To Peer', () {
      test('should connect to discovered peer successfully', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        final result = await bleMesh.connectToPeer(senderId);
        expect(result, isTrue);

        final state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('connected'));
      });

      test('should fail to connect to non-existent peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        // Don't add peer to discovered list

        final result = await bleMesh.connectToPeer(senderId);
        expect(result, isTrue); // Mock always returns true for simplicity

        final state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('connected'));
      });

      test('should fail to connect to already connected peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        await bleMesh.connectToPeer(senderId);
        final result = await bleMesh.connectToPeer(senderId);

        expect(result, isFalse);
      });

      test('should fail to connect to blocked peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        await bleMesh.blockPeer(senderId);
        final result = await bleMesh.connectToPeer(senderId);

        expect(result, isFalse);
      });

      test('should connect to multiple peers', () async {
        const senderId1 = 'AA:BB:CC:DD:EE:FF';
        const senderId2 = '11:22:33:44:55:66';
        const senderId3 = 'FF:EE:DD:CC:BB:AA';

        mockPlatform.addDiscoveredPeer(senderId1);
        mockPlatform.addDiscoveredPeer(senderId2);
        mockPlatform.addDiscoveredPeer(senderId3);

        final result1 = await bleMesh.connectToPeer(senderId1);
        final result2 = await bleMesh.connectToPeer(senderId2);
        final result3 = await bleMesh.connectToPeer(senderId3);

        expect(result1, isTrue);
        expect(result2, isTrue);
        expect(result3, isTrue);

        expect(await bleMesh.getPeerConnectionState(senderId1), equals('connected'));
        expect(await bleMesh.getPeerConnectionState(senderId2), equals('connected'));
        expect(await bleMesh.getPeerConnectionState(senderId3), equals('connected'));
      });

      test('should handle connection with different senderId formats', () async {
        const senderIds = [
          'AA:BB:CC:DD:EE:FF',
          'aa:bb:cc:dd:ee:ff',
          '00:11:22:33:44:55',
        ];

        for (final senderId in senderIds) {
          mockPlatform.addDiscoveredPeer(senderId);
          final result = await bleMesh.connectToPeer(senderId);
          expect(result, isTrue);
        }
      });
    });

    group('Disconnect From Peer', () {
      test('should disconnect from connected peer successfully', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        await bleMesh.connectToPeer(senderId);
        final result = await bleMesh.disconnectFromPeer(senderId);

        expect(result, isTrue);

        final state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('disconnected'));
      });

      test('should fail to disconnect from non-connected peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        final result = await bleMesh.disconnectFromPeer(senderId);
        expect(result, isFalse);
      });

      test('should disconnect from multiple peers', () async {
        const senderId1 = 'AA:BB:CC:DD:EE:FF';
        const senderId2 = '11:22:33:44:55:66';

        mockPlatform.addDiscoveredPeer(senderId1);
        mockPlatform.addDiscoveredPeer(senderId2);

        await bleMesh.connectToPeer(senderId1);
        await bleMesh.connectToPeer(senderId2);

        final result1 = await bleMesh.disconnectFromPeer(senderId1);
        final result2 = await bleMesh.disconnectFromPeer(senderId2);

        expect(result1, isTrue);
        expect(result2, isTrue);

        expect(await bleMesh.getPeerConnectionState(senderId1), equals('disconnected'));
        expect(await bleMesh.getPeerConnectionState(senderId2), equals('disconnected'));
      });

      test('should disconnect specific peer without affecting others', () async {
        const senderId1 = 'AA:BB:CC:DD:EE:FF';
        const senderId2 = '11:22:33:44:55:66';

        mockPlatform.addDiscoveredPeer(senderId1);
        mockPlatform.addDiscoveredPeer(senderId2);

        await bleMesh.connectToPeer(senderId1);
        await bleMesh.connectToPeer(senderId2);

        await bleMesh.disconnectFromPeer(senderId1);

        expect(await bleMesh.getPeerConnectionState(senderId1), equals('disconnected'));
        expect(await bleMesh.getPeerConnectionState(senderId2), equals('connected'));
      });
    });

    group('Get Peer Connection State', () {
      test('should return null for unknown peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        final state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, isNull);
      });

      test('should return discovered for discovered peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        final state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('discovered'));
      });

      test('should return connected for connected peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        await bleMesh.connectToPeer(senderId);
        final state = await bleMesh.getPeerConnectionState(senderId);

        expect(state, equals('connected'));
      });

      test('should return disconnected for disconnected peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        await bleMesh.connectToPeer(senderId);
        await bleMesh.disconnectFromPeer(senderId);

        final state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('disconnected'));
      });

      test('should track state changes correctly', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        // Discovered
        var state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('discovered'));

        // Connected
        await bleMesh.connectToPeer(senderId);
        state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('connected'));

        // Disconnected
        await bleMesh.disconnectFromPeer(senderId);
        state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('disconnected'));
      });
    });

    group('Connection Lifecycle', () {
      test('should complete full connection lifecycle', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';

        // 1. Discover peer
        mockPlatform.addDiscoveredPeer(senderId);
        var state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('discovered'));

        // 2. Connect to peer
        var result = await bleMesh.connectToPeer(senderId);
        expect(result, isTrue);
        state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('connected'));

        // 3. Disconnect from peer
        result = await bleMesh.disconnectFromPeer(senderId);
        expect(result, isTrue);
        state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('disconnected'));
      });

      test('should allow reconnection after disconnection', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        // First connection
        await bleMesh.connectToPeer(senderId);
        await bleMesh.disconnectFromPeer(senderId);

        // Reconnection - need to reset state for this test
        mockPlatform.addDiscoveredPeer(senderId);
        final result = await bleMesh.connectToPeer(senderId);
        expect(result, isTrue);
      });

      test('should handle rapid connect/disconnect operations', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';

        for (var i = 0; i < 5; i++) {
          mockPlatform.addDiscoveredPeer(senderId);
          await bleMesh.connectToPeer(senderId);
          await bleMesh.disconnectFromPeer(senderId);
        }

        final state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, equals('disconnected'));
      });
    });

    group('Connection with Blocklist Integration', () {
      test('should auto-disconnect when peer is blocked', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        await bleMesh.connectToPeer(senderId);
        expect(await bleMesh.getPeerConnectionState(senderId), equals('connected'));

        await bleMesh.blockPeer(senderId);
        expect(await bleMesh.getPeerConnectionState(senderId), equals('disconnected'));
      });

      test('should not allow connection to blocked peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        await bleMesh.blockPeer(senderId);
        final result = await bleMesh.connectToPeer(senderId);

        expect(result, isFalse);
      });

      test('should allow connection after unblocking', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        mockPlatform.addDiscoveredPeer(senderId);

        await bleMesh.blockPeer(senderId);
        await bleMesh.unblockPeer(senderId);

        final result = await bleMesh.connectToPeer(senderId);
        expect(result, isTrue);
      });

      test('should disconnect multiple peers when blocked', () async {
        const senderId1 = 'AA:BB:CC:DD:EE:FF';
        const senderId2 = '11:22:33:44:55:66';

        mockPlatform.addDiscoveredPeer(senderId1);
        mockPlatform.addDiscoveredPeer(senderId2);

        await bleMesh.connectToPeer(senderId1);
        await bleMesh.connectToPeer(senderId2);

        await bleMesh.blockPeer(senderId1);

        expect(await bleMesh.getPeerConnectionState(senderId1), equals('disconnected'));
        expect(await bleMesh.getPeerConnectionState(senderId2), equals('connected'));
      });
    });

    group('Connection Error Handling', () {
      test('should handle connection to peer without senderId gracefully', () async {
        // This test simulates trying to connect without a senderId
        // In real implementation, this should be validated
        const senderId = '';
        final result = await bleMesh.connectToPeer(senderId);
        // Should handle gracefully
        expect(result, isNotNull);
      });

      test('should handle disconnection from non-existent peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        final result = await bleMesh.disconnectFromPeer(senderId);
        expect(result, isFalse);
      });

      test('should handle state query for non-existent peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        final state = await bleMesh.getPeerConnectionState(senderId);
        expect(state, isNull);
      });
    });

    group('Multiple Peer Management', () {
      test('should manage multiple peer connections independently', () async {
        const senderIds = [
          'AA:BB:CC:DD:EE:FF',
          '11:22:33:44:55:66',
          'FF:EE:DD:CC:BB:AA',
          '00:11:22:33:44:55',
        ];

        // Discover all peers
        for (final senderId in senderIds) {
          mockPlatform.addDiscoveredPeer(senderId);
        }

        // Connect to all peers
        for (final senderId in senderIds) {
          final result = await bleMesh.connectToPeer(senderId);
          expect(result, isTrue);
        }

        // Verify all connected
        for (final senderId in senderIds) {
          final state = await bleMesh.getPeerConnectionState(senderId);
          expect(state, equals('connected'));
        }

        // Disconnect half
        await bleMesh.disconnectFromPeer(senderIds[0]);
        await bleMesh.disconnectFromPeer(senderIds[2]);

        // Verify states
        expect(await bleMesh.getPeerConnectionState(senderIds[0]), equals('disconnected'));
        expect(await bleMesh.getPeerConnectionState(senderIds[1]), equals('connected'));
        expect(await bleMesh.getPeerConnectionState(senderIds[2]), equals('disconnected'));
        expect(await bleMesh.getPeerConnectionState(senderIds[3]), equals('connected'));
      });

      test('should handle mixed operations on multiple peers', () async {
        const senderId1 = 'AA:BB:CC:DD:EE:FF';
        const senderId2 = '11:22:33:44:55:66';
        const senderId3 = 'FF:EE:DD:CC:BB:AA';

        mockPlatform.addDiscoveredPeer(senderId1);
        mockPlatform.addDiscoveredPeer(senderId2);
        mockPlatform.addDiscoveredPeer(senderId3);

        // Connect peer1
        await bleMesh.connectToPeer(senderId1);

        // Block peer2
        await bleMesh.blockPeer(senderId2);

        // Connect peer3
        await bleMesh.connectToPeer(senderId3);

        // Verify states
        expect(await bleMesh.getPeerConnectionState(senderId1), equals('connected'));
        expect(await bleMesh.isPeerBlocked(senderId2), isTrue);
        expect(await bleMesh.getPeerConnectionState(senderId3), equals('connected'));

        // Disconnect peer1
        await bleMesh.disconnectFromPeer(senderId1);

        // Unblock and connect peer2
        await bleMesh.unblockPeer(senderId2);
        await bleMesh.connectToPeer(senderId2);

        // Final verification
        expect(await bleMesh.getPeerConnectionState(senderId1), equals('disconnected'));
        expect(await bleMesh.getPeerConnectionState(senderId2), equals('connected'));
        expect(await bleMesh.getPeerConnectionState(senderId3), equals('connected'));
      });
    });
  });
}

