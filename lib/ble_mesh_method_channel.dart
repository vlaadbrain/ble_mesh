import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ble_mesh_platform_interface.dart';
import 'models/peer.dart';
import 'models/message.dart';
import 'models/mesh_event.dart';
import 'models/power_mode.dart';

/// An implementation of [BleMeshPlatform] that uses method channels.
class MethodChannelBleMesh extends BleMeshPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ble_mesh');

  /// Event channel for receiving messages
  @visibleForTesting
  final messageEventChannel = const EventChannel('ble_mesh/messages');

  /// Event channel for peer connected events
  @visibleForTesting
  final peerConnectedEventChannel = const EventChannel('ble_mesh/peer_connected');

  /// Event channel for peer disconnected events
  @visibleForTesting
  final peerDisconnectedEventChannel = const EventChannel('ble_mesh/peer_disconnected');

  /// Event channel for mesh events
  @visibleForTesting
  final meshEventChannel = const EventChannel('ble_mesh/mesh_events');

  /// Event channel for discovered peers
  @visibleForTesting
  final discoveredPeersEventChannel = const EventChannel('ble_mesh/discovered_peers');

  Stream<Message>? _messageStream;
  Stream<Peer>? _peerConnectedStream;
  Stream<Peer>? _peerDisconnectedStream;
  Stream<MeshEvent>? _meshEventStream;
  Stream<Peer>? _discoveredPeersStream;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> initialize({
    String? nickname,
    bool enableEncryption = true,
    PowerMode powerMode = PowerMode.balanced,
  }) async {
    await methodChannel.invokeMethod('initialize', {
      'nickname': nickname,
      'enableEncryption': enableEncryption,
      'powerMode': powerMode.index,
    });
  }

  @override
  Future<void> startMesh() async {
    await methodChannel.invokeMethod('startMesh');
  }

  @override
  Future<void> stopMesh() async {
    await methodChannel.invokeMethod('stopMesh');
  }

  @override
  Future<void> sendPublicMessage(String message) async {
    await methodChannel.invokeMethod('sendPublicMessage', {
      'message': message,
    });
  }

  @override
  Future<List<Peer>> getConnectedPeers() async {
    final result = await methodChannel.invokeMethod<List>('getConnectedPeers');
    if (result == null) return [];
    return result
        .map((e) => Peer.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Stream<Message> get messageStream {
    _messageStream ??= messageEventChannel.receiveBroadcastStream().map((event) {
      return Message.fromMap(Map<String, dynamic>.from(event as Map));
    });
    return _messageStream!;
  }

  @override
  Stream<Peer> get peerConnectedStream {
    _peerConnectedStream ??= peerConnectedEventChannel.receiveBroadcastStream().map((event) {
      return Peer.fromMap(Map<String, dynamic>.from(event as Map));
    });
    return _peerConnectedStream!;
  }

  @override
  Stream<Peer> get peerDisconnectedStream {
    _peerDisconnectedStream ??= peerDisconnectedEventChannel.receiveBroadcastStream().map((event) {
      return Peer.fromMap(Map<String, dynamic>.from(event as Map));
    });
    return _peerDisconnectedStream!;
  }

  @override
  Stream<MeshEvent> get meshEventStream {
    _meshEventStream ??= meshEventChannel.receiveBroadcastStream().map((event) {
      return MeshEvent.fromMap(Map<String, dynamic>.from(event as Map));
    });
    return _meshEventStream!;
  }

  @override
  Future<void> startDiscovery() async {
    await methodChannel.invokeMethod('startDiscovery');
  }

  @override
  Future<void> stopDiscovery() async {
    await methodChannel.invokeMethod('stopDiscovery');
  }

  @override
  Future<List<Peer>> getDiscoveredPeers() async {
    final result = await methodChannel.invokeMethod<List>('getDiscoveredPeers');
    if (result == null) return [];
    return result
        .map((e) => Peer.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Stream<Peer> get discoveredPeersStream {
    _discoveredPeersStream ??= discoveredPeersEventChannel.receiveBroadcastStream().map((event) {
      return Peer.fromMap(Map<String, dynamic>.from(event as Map));
    });
    return _discoveredPeersStream!;
  }

  @override
  Future<bool> connectToPeer(String senderId) async {
    final result = await methodChannel.invokeMethod<bool>('connectToPeer', {
      'senderId': senderId,
    });
    return result ?? false;
  }

  @override
  Future<bool> disconnectFromPeer(String senderId) async {
    final result = await methodChannel.invokeMethod<bool>('disconnectFromPeer', {
      'senderId': senderId,
    });
    return result ?? false;
  }

  @override
  Future<String?> getPeerConnectionState(String senderId) async {
    final result = await methodChannel.invokeMethod<String>('getPeerConnectionState', {
      'senderId': senderId,
    });
    return result;
  }

  @override
  Future<bool> blockPeer(String senderId) async {
    final result = await methodChannel.invokeMethod<bool>('blockPeer', {
      'senderId': senderId,
    });
    return result ?? false;
  }

  @override
  Future<bool> unblockPeer(String senderId) async {
    final result = await methodChannel.invokeMethod<bool>('unblockPeer', {
      'senderId': senderId,
    });
    return result ?? false;
  }

  @override
  Future<bool> isPeerBlocked(String senderId) async {
    final result = await methodChannel.invokeMethod<bool>('isPeerBlocked', {
      'senderId': senderId,
    });
    return result ?? false;
  }

  @override
  Future<List<String>> getBlockedPeers() async {
    final result = await methodChannel.invokeMethod<List>('getBlockedPeers');
    return result?.cast<String>() ?? [];
  }

  @override
  Future<void> clearBlocklist() async {
    await methodChannel.invokeMethod<void>('clearBlocklist');
  }
}
