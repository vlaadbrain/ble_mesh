import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ble_mesh/ble_mesh.dart';

/// Service that manages discovered peers queue and notifies listeners of changes
class PeerDiscoveryService extends ChangeNotifier {
  final BleMesh _bleMesh;

  // Queue of discovered peers (keyed by senderId or connectionId)
  final Map<String, Peer> _discoveredPeers = {};

  // Stream subscriptions
  StreamSubscription<Peer>? _discoverySubscription;
  StreamSubscription<Peer>? _connectionSubscription;
  StreamSubscription<Peer>? _disconnectionSubscription;

  /// Current list of discovered peers
  List<Peer> get peers => _discoveredPeers.values.toList();
  
  /// Count of discovered peers
  int get peerCount => _discoveredPeers.length;
  
  PeerDiscoveryService(this._bleMesh) {
    _setupListeners();
  }
  
  /// Setup stream listeners for peer events
  void _setupListeners() {
    // Listen for discovered peers
    _discoverySubscription = _bleMesh.discoveredPeersStream.listen((peer) {
      _addOrUpdatePeer(peer);
    });
    
    // Listen for connection events (update peer state)
    _connectionSubscription = _bleMesh.peerConnectedStream.listen((peer) {
      _addOrUpdatePeer(peer);
    });
    
    // Listen for disconnection events (update peer state)
    _disconnectionSubscription = _bleMesh.peerDisconnectedStream.listen((peer) {
      _addOrUpdatePeer(peer);
    });
  }
  
  /// Add or update a peer in the queue
  void _addOrUpdatePeer(Peer peer) {
    final key = peer.senderId ?? peer.connectionId;
    _discoveredPeers[key] = peer;
    _notifyListeners();
  }
  
  /// Remove a peer from the queue
  void removePeer(String senderId) {
    _discoveredPeers.remove(senderId);
    _notifyListeners();
  }
  
  /// Clear all discovered peers
  void clearAll() {
    _discoveredPeers.clear();
    _notifyListeners();
  }
  
  /// Get a specific peer by senderId
  Peer? getPeer(String senderId) {
    return _discoveredPeers[senderId];
  }
  
  /// Get filtered peers by connection state
  List<Peer> getPeersByState(PeerConnectionState state) {
    return _discoveredPeers.values
        .where((peer) => peer.connectionState == state)
        .toList();
  }
  
  /// Get all discovered (not connected) peers
  List<Peer> getDiscoveredPeers() {
    return getPeersByState(PeerConnectionState.discovered);
  }
  
  /// Get all connected peers
  List<Peer> getConnectedPeers() {
    return getPeersByState(PeerConnectionState.connected);
  }
  
  /// Get peers sorted by RSSI (strongest first)
  List<Peer> getPeersSortedByRssi() {
    final peerList = peers;
    peerList.sort((a, b) => b.rssi.compareTo(a.rssi));
    return peerList;
  }
  
  /// Get peers sorted by connection state, then RSSI
  List<Peer> getPeersSortedByStateAndRssi() {
    final peerList = peers;
    peerList.sort((a, b) {
      // Sort by connection state first
      if (a.connectionState != b.connectionState) {
        return a.connectionState.index.compareTo(b.connectionState.index);
      }
      // Then by RSSI (stronger signal first)
      return b.rssi.compareTo(a.rssi);
    });
    return peerList;
  }

  /// Notify all listeners of peer list changes
  void _notifyListeners() {
    notifyListeners();
  }

  /// Dispose of resources
  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _connectionSubscription?.cancel();
    _disconnectionSubscription?.cancel();
    super.dispose();
  }
}

