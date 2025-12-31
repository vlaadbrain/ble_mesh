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
  Future<void> sendPrivateMessage({
    required String peerId,
    required List<int> encryptedData,
    required List<int> senderPublicKey,
  }) async {
    // Mock implementation
  }

  @override
  Future<void> sharePublicKey({
    required String peerId,
    required List<int> publicKey,
  }) async {
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
}
