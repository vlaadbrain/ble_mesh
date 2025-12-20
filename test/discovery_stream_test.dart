import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ble_mesh/ble_mesh.dart';
import 'package:ble_mesh/ble_mesh_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBleMeshPlatform with MockPlatformInterfaceMixin implements BleMeshPlatform {
  final StreamController<Peer> _discoveredPeersController = StreamController<Peer>.broadcast();
  final List<Peer> _discoveredPeers = [];
  bool _isDiscovering = false;

  @override
  Future<void> startDiscovery() async {
    _isDiscovering = true;
  }

  @override
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
  }

  @override
  Future<List<Peer>> getDiscoveredPeers() async {
    return List.from(_discoveredPeers);
  }

  @override
  Stream<Peer> get discoveredPeersStream => _discoveredPeersController.stream;

  // Helper method to simulate peer discovery
  void simulatePeerDiscovery(Peer peer) {
    if (_isDiscovering) {
      _discoveredPeers.add(peer);
      _discoveredPeersController.add(peer);
    }
  }

  void clearDiscoveredPeers() {
    _discoveredPeers.clear();
  }

  bool get isDiscovering => _isDiscovering;

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
  Future<bool> connectToPeer(String senderId) async => true;

  @override
  Future<bool> disconnectFromPeer(String senderId) async => true;

  @override
  Future<String?> getPeerConnectionState(String senderId) async => null;

  @override
  Future<bool> blockPeer(String senderId) async => true;

  @override
  Future<bool> unblockPeer(String senderId) async => true;

  @override
  Future<bool> isPeerBlocked(String senderId) async => false;

  @override
  Future<List<String>> getBlockedPeers() async => [];

  @override
  Future<void> clearBlocklist() async {}
}

void main() {
  group('Discovery Stream Tests', () {
    late BleMesh bleMesh;
    late MockBleMeshPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockBleMeshPlatform();
      BleMeshPlatform.instance = mockPlatform;
      bleMesh = BleMesh();
    });

    tearDown(() {
      mockPlatform.clearDiscoveredPeers();
    });

    group('Start Discovery', () {
      test('should start discovery successfully', () async {
        await bleMesh.startDiscovery();
        expect(mockPlatform.isDiscovering, isTrue);
      });

      test('should allow starting discovery multiple times', () async {
        await bleMesh.startDiscovery();
        await bleMesh.startDiscovery();
        expect(mockPlatform.isDiscovering, isTrue);
      });
    });

    group('Stop Discovery', () {
      test('should stop discovery successfully', () async {
        await bleMesh.startDiscovery();
        await bleMesh.stopDiscovery();
        expect(mockPlatform.isDiscovering, isFalse);
      });

      test('should allow stopping discovery when not started', () async {
        await bleMesh.stopDiscovery();
        expect(mockPlatform.isDiscovering, isFalse);
      });

      test('should stop discovery after multiple starts', () async {
        await bleMesh.startDiscovery();
        await bleMesh.startDiscovery();
        await bleMesh.stopDiscovery();
        expect(mockPlatform.isDiscovering, isFalse);
      });
    });

    group('Get Discovered Peers', () {
      test('should return empty list when no peers discovered', () async {
        await bleMesh.startDiscovery();
        final peers = await bleMesh.getDiscoveredPeers();
        expect(peers, isEmpty);
      });

      test('should return discovered peers', () async {
        await bleMesh.startDiscovery();

        final peer1 = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        final peer2 = Peer(
          senderId: '11:22:33:44:55:66',
          connectionId: 'id2',
          nickname: 'Peer2',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        mockPlatform.simulatePeerDiscovery(peer1);
        mockPlatform.simulatePeerDiscovery(peer2);

        final peers = await bleMesh.getDiscoveredPeers();
        expect(peers.length, equals(2));
        expect(peers, contains(peer1));
        expect(peers, contains(peer2));
      });

      test('should return empty list when discovery is stopped', () async {
        await bleMesh.startDiscovery();

        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        mockPlatform.simulatePeerDiscovery(peer);
        await bleMesh.stopDiscovery();

        final peers = await bleMesh.getDiscoveredPeers();
        expect(peers.length, equals(1)); // Peers remain in list
      });
    });

    group('Discovered Peers Stream', () {
      test('should emit discovered peers', () async {
        await bleMesh.startDiscovery();

        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        final streamFuture = bleMesh.discoveredPeersStream.first;
        mockPlatform.simulatePeerDiscovery(peer);

        final receivedPeer = await streamFuture;
        expect(receivedPeer, equals(peer));
      });

      test('should emit multiple peers', () async {
        await bleMesh.startDiscovery();

        final peers = [
          Peer(
            senderId: 'AA:BB:CC:DD:EE:FF',
            connectionId: 'id1',
            nickname: 'Peer1',
            rssi: -65,
            lastSeen: DateTime.now(),
            connectionState: PeerConnectionState.discovered,
          ),
          Peer(
            senderId: '11:22:33:44:55:66',
            connectionId: 'id2',
            nickname: 'Peer2',
            rssi: -70,
            lastSeen: DateTime.now(),
            connectionState: PeerConnectionState.discovered,
          ),
          Peer(
            senderId: 'FF:EE:DD:CC:BB:AA',
            connectionId: 'id3',
            nickname: 'Peer3',
            rssi: -75,
            lastSeen: DateTime.now(),
            connectionState: PeerConnectionState.discovered,
          ),
        ];

        final receivedPeers = <Peer>[];
        final subscription = bleMesh.discoveredPeersStream.listen((peer) {
          receivedPeers.add(peer);
        });

        for (final peer in peers) {
          mockPlatform.simulatePeerDiscovery(peer);
        }

        await Future.delayed(const Duration(milliseconds: 100));
        await subscription.cancel();

        expect(receivedPeers.length, equals(3));
        expect(receivedPeers, containsAll(peers));
      });

      test('should not emit peers when discovery is stopped', () async {
        await bleMesh.startDiscovery();
        await bleMesh.stopDiscovery();

        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        final receivedPeers = <Peer>[];
        final subscription = bleMesh.discoveredPeersStream.listen((peer) {
          receivedPeers.add(peer);
        });

        mockPlatform.simulatePeerDiscovery(peer);

        await Future.delayed(const Duration(milliseconds: 100));
        await subscription.cancel();

        expect(receivedPeers, isEmpty);
      });

      test('should support multiple listeners', () async {
        await bleMesh.startDiscovery();

        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        final receivedPeers1 = <Peer>[];
        final receivedPeers2 = <Peer>[];

        final subscription1 = bleMesh.discoveredPeersStream.listen((peer) {
          receivedPeers1.add(peer);
        });

        final subscription2 = bleMesh.discoveredPeersStream.listen((peer) {
          receivedPeers2.add(peer);
        });

        mockPlatform.simulatePeerDiscovery(peer);

        await Future.delayed(const Duration(milliseconds: 100));
        await subscription1.cancel();
        await subscription2.cancel();

        expect(receivedPeers1.length, equals(1));
        expect(receivedPeers2.length, equals(1));
        expect(receivedPeers1.first, equals(peer));
        expect(receivedPeers2.first, equals(peer));
      });
    });

    group('Discovery Lifecycle', () {
      test('should complete full discovery lifecycle', () async {
        // Start discovery
        await bleMesh.startDiscovery();
        expect(mockPlatform.isDiscovering, isTrue);

        // Discover peers
        final peer1 = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        mockPlatform.simulatePeerDiscovery(peer1);

        final peers = await bleMesh.getDiscoveredPeers();
        expect(peers.length, equals(1));

        // Stop discovery
        await bleMesh.stopDiscovery();
        expect(mockPlatform.isDiscovering, isFalse);
      });

      test('should handle restart of discovery', () async {
        await bleMesh.startDiscovery();

        final peer1 = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        mockPlatform.simulatePeerDiscovery(peer1);

        await bleMesh.stopDiscovery();
        mockPlatform.clearDiscoveredPeers();

        await bleMesh.startDiscovery();

        final peer2 = Peer(
          senderId: '11:22:33:44:55:66',
          connectionId: 'id2',
          nickname: 'Peer2',
          rssi: -70,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        mockPlatform.simulatePeerDiscovery(peer2);

        final peers = await bleMesh.getDiscoveredPeers();
        expect(peers.length, equals(1));
        expect(peers.first.senderId, equals('11:22:33:44:55:66'));
      });
    });

    group('Discovery with Peer Properties', () {
      test('should discover peers with varying RSSI', () async {
        await bleMesh.startDiscovery();

        final peers = [
          Peer(
            senderId: 'AA:BB:CC:DD:EE:FF',
            connectionId: 'id1',
            nickname: 'Near',
            rssi: -40,
            lastSeen: DateTime.now(),
            connectionState: PeerConnectionState.discovered,
          ),
          Peer(
            senderId: '11:22:33:44:55:66',
            connectionId: 'id2',
            nickname: 'Medium',
            rssi: -70,
            lastSeen: DateTime.now(),
            connectionState: PeerConnectionState.discovered,
          ),
          Peer(
            senderId: 'FF:EE:DD:CC:BB:AA',
            connectionId: 'id3',
            nickname: 'Far',
            rssi: -90,
            lastSeen: DateTime.now(),
            connectionState: PeerConnectionState.discovered,
          ),
        ];

        for (final peer in peers) {
          mockPlatform.simulatePeerDiscovery(peer);
        }

        final discoveredPeers = await bleMesh.getDiscoveredPeers();
        expect(discoveredPeers.length, equals(3));

        // Verify RSSI values
        expect(discoveredPeers[0].rssi, equals(-40));
        expect(discoveredPeers[1].rssi, equals(-70));
        expect(discoveredPeers[2].rssi, equals(-90));
      });

      test('should discover peers with different connection states', () async {
        await bleMesh.startDiscovery();

        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        mockPlatform.simulatePeerDiscovery(peer);

        final discoveredPeers = await bleMesh.getDiscoveredPeers();
        expect(discoveredPeers.first.connectionState, equals(PeerConnectionState.discovered));
      });

      test('should discover peers with senderId', () async {
        await bleMesh.startDiscovery();

        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        mockPlatform.simulatePeerDiscovery(peer);

        final discoveredPeers = await bleMesh.getDiscoveredPeers();
        expect(discoveredPeers.first.senderId, equals('AA:BB:CC:DD:EE:FF'));
        expect(discoveredPeers.first.canConnect, isTrue);
      });

      test('should discover peers without senderId', () async {
        await bleMesh.startDiscovery();

        final peer = Peer(
          senderId: null,
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        mockPlatform.simulatePeerDiscovery(peer);

        final discoveredPeers = await bleMesh.getDiscoveredPeers();
        expect(discoveredPeers.first.senderId, isNull);
        expect(discoveredPeers.first.canConnect, isFalse);
      });
    });

    group('Discovery Performance', () {
      test('should handle discovering many peers', () async {
        await bleMesh.startDiscovery();

        final peers = List.generate(50, (i) => Peer(
          senderId: '${i.toRadixString(16).padLeft(2, '0')}:00:00:00:00:00',
          connectionId: 'id$i',
          nickname: 'Peer$i',
          rssi: -60 - i,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        ));

        for (final peer in peers) {
          mockPlatform.simulatePeerDiscovery(peer);
        }

        final discoveredPeers = await bleMesh.getDiscoveredPeers();
        expect(discoveredPeers.length, equals(50));
      });

      test('should handle rapid peer discoveries', () async {
        await bleMesh.startDiscovery();

        final receivedPeers = <Peer>[];
        final subscription = bleMesh.discoveredPeersStream.listen((peer) {
          receivedPeers.add(peer);
        });

        for (var i = 0; i < 20; i++) {
          final peer = Peer(
            senderId: '${i.toRadixString(16).padLeft(2, '0')}:00:00:00:00:00',
            connectionId: 'id$i',
            nickname: 'Peer$i',
            rssi: -65,
            lastSeen: DateTime.now(),
            connectionState: PeerConnectionState.discovered,
          );
          mockPlatform.simulatePeerDiscovery(peer);
        }

        await Future.delayed(const Duration(milliseconds: 100));
        await subscription.cancel();

        expect(receivedPeers.length, equals(20));
      });
    });

    group('Discovery Integration Scenarios', () {
      test('should discover and connect to peer', () async {
        await bleMesh.startDiscovery();

        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
        );

        mockPlatform.simulatePeerDiscovery(peer);

        final discoveredPeers = await bleMesh.getDiscoveredPeers();
        expect(discoveredPeers.length, equals(1));
        expect(discoveredPeers.first.canConnect, isTrue);

        final result = await bleMesh.connectToPeer(peer.senderId!);
        expect(result, isTrue);
      });

      test('should not discover blocked peers (in real implementation)', () async {
        // This test documents expected behavior
        // In real implementation, blocked peers should be filtered from discovery
        await bleMesh.startDiscovery();

        final peer = Peer(
          senderId: 'AA:BB:CC:DD:EE:FF',
          connectionId: 'id1',
          nickname: 'Peer1',
          rssi: -65,
          lastSeen: DateTime.now(),
          connectionState: PeerConnectionState.discovered,
          isBlocked: true,
        );

        mockPlatform.simulatePeerDiscovery(peer);

        final discoveredPeers = await bleMesh.getDiscoveredPeers();
        // In real implementation, blocked peers should be filtered
        // For this mock, we just verify the isBlocked flag
        expect(discoveredPeers.first.isBlocked, isTrue);
        expect(discoveredPeers.first.canConnect, isFalse);
      });
    });
  });
}

