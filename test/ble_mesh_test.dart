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
