import 'package:flutter_test/flutter_test.dart';
import 'package:ble_mesh/ble_mesh.dart';
import 'package:ble_mesh/ble_mesh_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBleMeshPlatform with MockPlatformInterfaceMixin implements BleMeshPlatform {
  final Map<String, bool> _blocklist = {};

  @override
  Future<bool> blockPeer(String senderId) async {
    _blocklist[senderId] = true;
    return true;
  }

  @override
  Future<bool> unblockPeer(String senderId) async {
    _blocklist.remove(senderId);
    return true;
  }

  @override
  Future<bool> isPeerBlocked(String senderId) async {
    return _blocklist[senderId] ?? false;
  }

  @override
  Future<List<String>> getBlockedPeers() async {
    return _blocklist.keys.toList();
  }

  @override
  Future<void> clearBlocklist() async {
    _blocklist.clear();
  }

  // Required implementations for other methods
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
  Future<bool> connectToPeer(String senderId) async => true;

  @override
  Future<bool> disconnectFromPeer(String senderId) async => true;

  @override
  Future<String?> getPeerConnectionState(String senderId) async => null;
}

void main() {
  group('Blocklist Functionality Tests', () {
    late BleMesh bleMesh;
    late MockBleMeshPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockBleMeshPlatform();
      BleMeshPlatform.instance = mockPlatform;
      bleMesh = BleMesh();
    });

    group('Block Peer', () {
      test('should block a peer successfully', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        final result = await bleMesh.blockPeer(senderId);

        expect(result, isTrue);
        expect(await bleMesh.isPeerBlocked(senderId), isTrue);
      });

      test('should block multiple peers', () async {
        const senderId1 = 'AA:BB:CC:DD:EE:FF';
        const senderId2 = '11:22:33:44:55:66';
        const senderId3 = 'FF:EE:DD:CC:BB:AA';

        await bleMesh.blockPeer(senderId1);
        await bleMesh.blockPeer(senderId2);
        await bleMesh.blockPeer(senderId3);

        expect(await bleMesh.isPeerBlocked(senderId1), isTrue);
        expect(await bleMesh.isPeerBlocked(senderId2), isTrue);
        expect(await bleMesh.isPeerBlocked(senderId3), isTrue);
      });

      test('should handle blocking already blocked peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';

        await bleMesh.blockPeer(senderId);
        final result = await bleMesh.blockPeer(senderId);

        expect(result, isTrue);
        expect(await bleMesh.isPeerBlocked(senderId), isTrue);
      });

      test('should block peer with different senderId formats', () async {
        const formats = [
          'AA:BB:CC:DD:EE:FF',
          'aa:bb:cc:dd:ee:ff',
          '00:11:22:33:44:55',
        ];

        for (final senderId in formats) {
          await bleMesh.blockPeer(senderId);
          expect(await bleMesh.isPeerBlocked(senderId), isTrue);
        }
      });
    });

    group('Unblock Peer', () {
      test('should unblock a blocked peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';

        await bleMesh.blockPeer(senderId);
        expect(await bleMesh.isPeerBlocked(senderId), isTrue);

        final result = await bleMesh.unblockPeer(senderId);
        expect(result, isTrue);
        expect(await bleMesh.isPeerBlocked(senderId), isFalse);
      });

      test('should handle unblocking non-blocked peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';

        final result = await bleMesh.unblockPeer(senderId);
        expect(result, isTrue);
        expect(await bleMesh.isPeerBlocked(senderId), isFalse);
      });

      test('should unblock specific peer without affecting others', () async {
        const senderId1 = 'AA:BB:CC:DD:EE:FF';
        const senderId2 = '11:22:33:44:55:66';
        const senderId3 = 'FF:EE:DD:CC:BB:AA';

        await bleMesh.blockPeer(senderId1);
        await bleMesh.blockPeer(senderId2);
        await bleMesh.blockPeer(senderId3);

        await bleMesh.unblockPeer(senderId2);

        expect(await bleMesh.isPeerBlocked(senderId1), isTrue);
        expect(await bleMesh.isPeerBlocked(senderId2), isFalse);
        expect(await bleMesh.isPeerBlocked(senderId3), isTrue);
      });
    });

    group('Is Peer Blocked', () {
      test('should return false for non-blocked peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        expect(await bleMesh.isPeerBlocked(senderId), isFalse);
      });

      test('should return true for blocked peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        await bleMesh.blockPeer(senderId);
        expect(await bleMesh.isPeerBlocked(senderId), isTrue);
      });

      test('should return false after unblocking', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        await bleMesh.blockPeer(senderId);
        await bleMesh.unblockPeer(senderId);
        expect(await bleMesh.isPeerBlocked(senderId), isFalse);
      });

      test('should check multiple peers independently', () async {
        const blockedId = 'AA:BB:CC:DD:EE:FF';
        const unblockedId = '11:22:33:44:55:66';

        await bleMesh.blockPeer(blockedId);

        expect(await bleMesh.isPeerBlocked(blockedId), isTrue);
        expect(await bleMesh.isPeerBlocked(unblockedId), isFalse);
      });
    });

    group('Get Blocked Peers', () {
      test('should return empty list when no peers are blocked', () async {
        final blockedPeers = await bleMesh.getBlockedPeers();
        expect(blockedPeers, isEmpty);
      });

      test('should return list of blocked peers', () async {
        const senderId1 = 'AA:BB:CC:DD:EE:FF';
        const senderId2 = '11:22:33:44:55:66';
        const senderId3 = 'FF:EE:DD:CC:BB:AA';

        await bleMesh.blockPeer(senderId1);
        await bleMesh.blockPeer(senderId2);
        await bleMesh.blockPeer(senderId3);

        final blockedPeers = await bleMesh.getBlockedPeers();
        expect(blockedPeers.length, equals(3));
        expect(blockedPeers, contains(senderId1));
        expect(blockedPeers, contains(senderId2));
        expect(blockedPeers, contains(senderId3));
      });

      test('should update list after unblocking', () async {
        const senderId1 = 'AA:BB:CC:DD:EE:FF';
        const senderId2 = '11:22:33:44:55:66';

        await bleMesh.blockPeer(senderId1);
        await bleMesh.blockPeer(senderId2);

        var blockedPeers = await bleMesh.getBlockedPeers();
        expect(blockedPeers.length, equals(2));

        await bleMesh.unblockPeer(senderId1);

        blockedPeers = await bleMesh.getBlockedPeers();
        expect(blockedPeers.length, equals(1));
        expect(blockedPeers, contains(senderId2));
        expect(blockedPeers, isNot(contains(senderId1)));
      });

      test('should return copy of blocked peers list', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        await bleMesh.blockPeer(senderId);

        final blockedPeers1 = await bleMesh.getBlockedPeers();
        final blockedPeers2 = await bleMesh.getBlockedPeers();

        expect(blockedPeers1, equals(blockedPeers2));
        expect(identical(blockedPeers1, blockedPeers2), isFalse);
      });
    });

    group('Clear Blocklist', () {
      test('should clear empty blocklist', () async {
        await bleMesh.clearBlocklist();
        final blockedPeers = await bleMesh.getBlockedPeers();
        expect(blockedPeers, isEmpty);
      });

      test('should clear blocklist with one peer', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        await bleMesh.blockPeer(senderId);

        await bleMesh.clearBlocklist();

        final blockedPeers = await bleMesh.getBlockedPeers();
        expect(blockedPeers, isEmpty);
        expect(await bleMesh.isPeerBlocked(senderId), isFalse);
      });

      test('should clear blocklist with multiple peers', () async {
        const senderIds = [
          'AA:BB:CC:DD:EE:FF',
          '11:22:33:44:55:66',
          'FF:EE:DD:CC:BB:AA',
          '00:11:22:33:44:55',
        ];

        for (final senderId in senderIds) {
          await bleMesh.blockPeer(senderId);
        }

        await bleMesh.clearBlocklist();

        final blockedPeers = await bleMesh.getBlockedPeers();
        expect(blockedPeers, isEmpty);

        for (final senderId in senderIds) {
          expect(await bleMesh.isPeerBlocked(senderId), isFalse);
        }
      });

      test('should allow blocking after clearing', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';

        await bleMesh.blockPeer(senderId);
        await bleMesh.clearBlocklist();
        await bleMesh.blockPeer(senderId);

        expect(await bleMesh.isPeerBlocked(senderId), isTrue);
        final blockedPeers = await bleMesh.getBlockedPeers();
        expect(blockedPeers.length, equals(1));
      });
    });

    group('Blocklist Persistence Scenarios', () {
      test('should maintain blocklist across multiple operations', () async {
        const senderId1 = 'AA:BB:CC:DD:EE:FF';
        const senderId2 = '11:22:33:44:55:66';
        const senderId3 = 'FF:EE:DD:CC:BB:AA';

        // Block peers
        await bleMesh.blockPeer(senderId1);
        await bleMesh.blockPeer(senderId2);
        await bleMesh.blockPeer(senderId3);

        // Unblock one
        await bleMesh.unblockPeer(senderId2);

        // Check state
        expect(await bleMesh.isPeerBlocked(senderId1), isTrue);
        expect(await bleMesh.isPeerBlocked(senderId2), isFalse);
        expect(await bleMesh.isPeerBlocked(senderId3), isTrue);

        // Block again
        await bleMesh.blockPeer(senderId2);

        // Verify all blocked
        expect(await bleMesh.isPeerBlocked(senderId1), isTrue);
        expect(await bleMesh.isPeerBlocked(senderId2), isTrue);
        expect(await bleMesh.isPeerBlocked(senderId3), isTrue);

        final blockedPeers = await bleMesh.getBlockedPeers();
        expect(blockedPeers.length, equals(3));
      });
    });

    group('Blocklist Edge Cases', () {
      test('should handle blocking with special characters in senderId', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';
        await bleMesh.blockPeer(senderId);
        expect(await bleMesh.isPeerBlocked(senderId), isTrue);
      });

      test('should handle rapid block/unblock operations', () async {
        const senderId = 'AA:BB:CC:DD:EE:FF';

        for (var i = 0; i < 10; i++) {
          await bleMesh.blockPeer(senderId);
          expect(await bleMesh.isPeerBlocked(senderId), isTrue);
          await bleMesh.unblockPeer(senderId);
          expect(await bleMesh.isPeerBlocked(senderId), isFalse);
        }
      });

      test('should handle blocking many peers', () async {
        final senderIds = List.generate(100, (i) =>
          '${i.toRadixString(16).padLeft(2, '0')}:00:00:00:00:00');

        for (final senderId in senderIds) {
          await bleMesh.blockPeer(senderId);
        }

        final blockedPeers = await bleMesh.getBlockedPeers();
        expect(blockedPeers.length, equals(100));

        for (final senderId in senderIds) {
          expect(await bleMesh.isPeerBlocked(senderId), isTrue);
        }
      });
    });

    group('Blocklist Integration with Connection State', () {
      test('blocked peer should have isBlocked flag in Peer model', () {
        final blockedPeer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Blocked',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: true,
        );

        expect(blockedPeer.isBlocked, isTrue);
        expect(blockedPeer.canConnect, isFalse);
      });

      test('blocked peer should not be connectable even with valid senderId', () {
        final blockedPeer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Blocked',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: true,
        );

        expect(blockedPeer.senderId, isNotNull);
        expect(blockedPeer.connectionState, equals(PeerConnectionState.discovered));
        expect(blockedPeer.canConnect, isFalse);
      });

      test('unblocked peer should be connectable with valid senderId', () {
        final unblockedPeer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Unblocked',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: false,
        );

        expect(unblockedPeer.senderId, isNotNull);
        expect(unblockedPeer.connectionState, equals(PeerConnectionState.discovered));
        expect(unblockedPeer.canConnect, isTrue);
      });
    });

    group('Blocklist Serialization in Peer Model', () {
      test('should serialize isBlocked flag correctly', () {
        final blockedPeer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'test-id',
          nickname: 'Test',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: true,
        );

        final map = blockedPeer.toMap();
        expect(map['isBlocked'], isTrue);
      });

      test('should deserialize isBlocked flag correctly', () {
        final map = {
          'senderId': 'AA:BB:CC:DD:EE:FF',
          'connectionId': 'test-id',
          'nickname': 'Test',
          'rssi': -70,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'connectionState': 'discovered',
          'isBlocked': true,
        };

        final peer = Peer.fromMap(map);
        expect(peer.isBlocked, isTrue);
      });

      test('should default isBlocked to false when missing', () {
        final map = {
          'senderId': 'AA:BB:CC:DD:EE:FF',
          'connectionId': 'test-id',
          'nickname': 'Test',
          'rssi': -70,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'connectionState': 'discovered',
        };

        final peer = Peer.fromMap(map);
        expect(peer.isBlocked, isFalse);
      });
    });
  });
}

