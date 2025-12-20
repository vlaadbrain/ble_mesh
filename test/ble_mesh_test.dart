import 'package:flutter_test/flutter_test.dart';
import 'package:ble_mesh/ble_mesh.dart';
import 'package:ble_mesh/ble_mesh_platform_interface.dart';
import 'package:ble_mesh/ble_mesh_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBleMeshPlatform
    with MockPlatformInterfaceMixin
    implements BleMeshPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> initialize({
    String? nickname,
    bool enableEncryption = true,
    PowerMode powerMode = PowerMode.balanced,
  }) async {
    // Mock implementation
  }

  @override
  Future<void> startMesh() async {
    // Mock implementation
  }

  @override
  Future<void> stopMesh() async {
    // Mock implementation
  }

  @override
  Future<void> sendPublicMessage(String message) async {
    // Mock implementation
  }

  @override
  Future<List<Peer>> getConnectedPeers() async {
    return [];
  }

  @override
  Stream<Message> get messageStream => Stream.empty();

  @override
  Stream<Peer> get peerConnectedStream => Stream.empty();

  @override
  Stream<Peer> get peerDisconnectedStream => Stream.empty();

  @override
  Stream<MeshEvent> get meshEventStream => Stream.empty();

  // Discovery APIs
  @override
  Future<void> startDiscovery() async {
    // Mock implementation
  }

  @override
  Future<void> stopDiscovery() async {
    // Mock implementation
  }

  @override
  Future<List<Peer>> getDiscoveredPeers() async {
    return [];
  }

  @override
  Stream<Peer> get discoveredPeersStream => Stream.empty();

  // Manual Connection APIs
  @override
  Future<bool> connectToPeer(String senderId) async {
    return true;
  }

  @override
  Future<bool> disconnectFromPeer(String senderId) async {
    return true;
  }

  @override
  Future<String?> getPeerConnectionState(String senderId) async {
    return null;
  }

  // Blocklist APIs
  @override
  Future<bool> blockPeer(String senderId) async {
    return true;
  }

  @override
  Future<bool> unblockPeer(String senderId) async {
    return true;
  }

  @override
  Future<bool> isPeerBlocked(String senderId) async {
    return false;
  }

  @override
  Future<List<String>> getBlockedPeers() async {
    return [];
  }

  @override
  Future<void> clearBlocklist() async {
    // Mock implementation
  }
}

void main() {
  final BleMeshPlatform initialPlatform = BleMeshPlatform.instance;

  test('$MethodChannelBleMesh is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelBleMesh>());
  });

  test('getPlatformVersion', () async {
    BleMesh bleMeshPlugin = BleMesh();
    MockBleMeshPlatform fakePlatform = MockBleMeshPlatform();
    BleMeshPlatform.instance = fakePlatform;

    expect(await bleMeshPlugin.getPlatformVersion(), '42');
  });

  group('Discovery APIs', () {
    late BleMesh bleMesh;
    late MockBleMeshPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockBleMeshPlatform();
      BleMeshPlatform.instance = mockPlatform;
      bleMesh = BleMesh();
    });

    test('startDiscovery should complete successfully', () async {
      await expectLater(bleMesh.startDiscovery(), completes);
    });

    test('stopDiscovery should complete successfully', () async {
      await expectLater(bleMesh.stopDiscovery(), completes);
    });

    test('getDiscoveredPeers should return empty list', () async {
      final peers = await bleMesh.getDiscoveredPeers();
      expect(peers, isEmpty);
    });

    test('discoveredPeersStream should return empty stream', () {
      expect(bleMesh.discoveredPeersStream, isNotNull);
    });
  });

  group('Manual Connection APIs', () {
    late BleMesh bleMesh;
    late MockBleMeshPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockBleMeshPlatform();
      BleMeshPlatform.instance = mockPlatform;
      bleMesh = BleMesh();
    });

    test('connectToPeer should return true', () async {
      const senderId = 'AA:BB:CC:DD:EE:FF';
      final result = await bleMesh.connectToPeer(senderId);
      expect(result, isTrue);
    });

    test('disconnectFromPeer should return true', () async {
      const senderId = 'AA:BB:CC:DD:EE:FF';
      final result = await bleMesh.disconnectFromPeer(senderId);
      expect(result, isTrue);
    });

    test('getPeerConnectionState should return null for unknown peer', () async {
      const senderId = 'AA:BB:CC:DD:EE:FF';
      final state = await bleMesh.getPeerConnectionState(senderId);
      expect(state, isNull);
    });
  });

  group('Blocklist APIs', () {
    late BleMesh bleMesh;
    late MockBleMeshPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockBleMeshPlatform();
      BleMeshPlatform.instance = mockPlatform;
      bleMesh = BleMesh();
    });

    test('blockPeer should return true', () async {
      const senderId = 'AA:BB:CC:DD:EE:FF';
      final result = await bleMesh.blockPeer(senderId);
      expect(result, isTrue);
    });

    test('unblockPeer should return true', () async {
      const senderId = 'AA:BB:CC:DD:EE:FF';
      final result = await bleMesh.unblockPeer(senderId);
      expect(result, isTrue);
    });

    test('isPeerBlocked should return false for non-blocked peer', () async {
      const senderId = 'AA:BB:CC:DD:EE:FF';
      final result = await bleMesh.isPeerBlocked(senderId);
      expect(result, isFalse);
    });

    test('getBlockedPeers should return empty list', () async {
      final blockedPeers = await bleMesh.getBlockedPeers();
      expect(blockedPeers, isEmpty);
    });

    test('clearBlocklist should complete successfully', () async {
      await expectLater(bleMesh.clearBlocklist(), completes);
    });
  });
}
