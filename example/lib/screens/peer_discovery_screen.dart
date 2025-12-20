import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ble_mesh/ble_mesh.dart';
import '../services/peer_discovery_service.dart';

class PeerDiscoveryScreen extends StatefulWidget {
  const PeerDiscoveryScreen({super.key});

  @override
  State<PeerDiscoveryScreen> createState() => _PeerDiscoveryScreenState();
}

class _PeerDiscoveryScreenState extends State<PeerDiscoveryScreen> {
  late final BleMesh _bleMesh;
  bool _isDiscovering = false;
  StreamSubscription<Peer>? _connectionSubscription;
  StreamSubscription<Peer>? _disconnectionSubscription;
  String _filterState = 'all'; // all, discovered, connected

  @override
  void initState() {
    super.initState();
    _bleMesh = context.read<BleMesh>();
    _setupListeners();
    _startDiscovery();
  }

  void _setupListeners() {
    // Listen for connection events for notifications
    _connectionSubscription = _bleMesh.peerConnectedStream.listen((peer) {
      _showSnackBar('Connected to ${peer.nickname}');
    });

    // Listen for disconnection events for notifications
    _disconnectionSubscription = _bleMesh.peerDisconnectedStream.listen((peer) {
      _showSnackBar('Disconnected from ${peer.nickname}');
    });
  }

  Future<void> _startDiscovery() async {
    try {
      await _bleMesh.startDiscovery();
      setState(() {
        _isDiscovering = true;
      });
    } catch (e) {
      _showSnackBar('Failed to start discovery: $e');
    }
  }

  Future<void> _stopDiscovery() async {
    try {
      await _bleMesh.stopDiscovery();
      setState(() {
        _isDiscovering = false;
      });
    } catch (e) {
      _showSnackBar('Failed to stop discovery: $e');
    }
  }

  Future<void> _connectToPeer(Peer peer) async {
    if (peer.senderId == null) {
      _showSnackBar('Cannot connect: Peer has no sender ID');
      return;
    }

    try {
      final success = await _bleMesh.connectToPeer(peer.senderId!);
      if (success) {
        _showSnackBar('Connecting to ${peer.nickname}...');
      } else {
        _showSnackBar('Failed to initiate connection');
      }
    } catch (e) {
      _showSnackBar('Error connecting: $e');
    }
  }

  Future<void> _disconnectFromPeer(Peer peer) async {
    if (peer.senderId == null) {
      _showSnackBar('Cannot disconnect: Peer has no sender ID');
      return;
    }

    try {
      final success = await _bleMesh.disconnectFromPeer(peer.senderId!);
      if (success) {
        _showSnackBar('Disconnecting from ${peer.nickname}...');
      } else {
        _showSnackBar('Failed to initiate disconnection');
      }
    } catch (e) {
      _showSnackBar('Error disconnecting: $e');
    }
  }

  Future<void> _blockPeer(Peer peer) async {
    if (peer.senderId == null) {
      _showSnackBar('Cannot block: Peer has no sender ID');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Peer'),
        content: Text('Block ${peer.nickname}? They will be disconnected and filtered from discovery.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _bleMesh.blockPeer(peer.senderId!);
        if (success) {
          // Service will handle peer removal via stream updates
          _showSnackBar('Blocked ${peer.nickname}');
        } else {
          _showSnackBar('Failed to block peer');
        }
      } catch (e) {
        _showSnackBar('Error blocking peer: $e');
      }
    }
  }

  Future<void> _refreshPeers() async {
    final discoveryService = context.read<PeerDiscoveryService>();
    discoveryService.clearAll();
    if (_isDiscovering) {
      await _stopDiscovery();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await _startDiscovery();
  }

  List<Peer> _getFilteredPeers(PeerDiscoveryService discoveryService) {
    switch (_filterState) {
      case 'discovered':
        return discoveryService.getDiscoveredPeers();
      case 'connected':
        return discoveryService.getConnectedPeers();
      default:
        return discoveryService.getPeersSortedByStateAndRssi();
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the PeerDiscoveryService for updates
    final discoveryService = context.watch<PeerDiscoveryService>();
    final filteredPeers = _getFilteredPeers(discoveryService);

    // Sort peers by connection state first, then by RSSI
    filteredPeers.sort((a, b) {
      if (a.connectionState != b.connectionState) {
        return a.connectionState.index.compareTo(b.connectionState.index);
      }
      return b.rssi.compareTo(a.rssi);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peer Discovery'),
        actions: [
          IconButton(
            icon: Icon(_isDiscovering ? Icons.pause : Icons.play_arrow),
            tooltip: _isDiscovering ? 'Stop Discovery' : 'Start Discovery',
            onPressed: _isDiscovering ? _stopDiscovery : _startDiscovery,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshPeers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: _isDiscovering ? Colors.blue.shade50 : Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  _isDiscovering ? Icons.radar : Icons.radar_outlined,
                  color: _isDiscovering ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isDiscovering
                        ? 'Discovering... (${filteredPeers.length} peers)'
                        : 'Discovery stopped (${filteredPeers.length} peers)',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _isDiscovering ? Colors.blue.shade900 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filterState == 'all',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterState = 'all');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Discovered'),
                  selected: _filterState == 'discovered',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterState = 'discovered');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Connected'),
                  selected: _filterState == 'connected',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterState = 'connected');
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Peer List
          Expanded(
            child: filteredPeers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _isDiscovering ? 'Searching for peers...' : 'No peers found',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        if (!_isDiscovering) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _startDiscovery,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Discovery'),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshPeers,
                    child: ListView.builder(
                      itemCount: filteredPeers.length,
                      itemBuilder: (context, index) {
                        final peer = filteredPeers[index];
                        return _buildPeerTile(peer);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeerTile(Peer peer) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: _buildConnectionStateIcon(peer.connectionState),
        title: Row(
          children: [
            Expanded(
              child: Text(
                peer.nickname,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (peer.isBlocked)
              const Icon(Icons.block, size: 16, color: Colors.red),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('ID: ${peer.senderId ?? 'Unknown'}'),
            Text('RSSI: ${peer.rssi} dBm'),
            Text('State: ${_getConnectionStateText(peer.connectionState)}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConnectionButton(peer),
            const SizedBox(width: 4),
            _buildBlockButton(peer),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildConnectionStateIcon(PeerConnectionState state) {
    switch (state) {
      case PeerConnectionState.discovered:
        return const Icon(Icons.visibility, color: Colors.grey);
      case PeerConnectionState.connecting:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case PeerConnectionState.connected:
        return const Icon(Icons.check_circle, color: Colors.green);
      case PeerConnectionState.disconnecting:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
        );
      case PeerConnectionState.disconnected:
        return const Icon(Icons.cancel, color: Colors.orange);
    }
  }

  Widget _buildConnectionButton(Peer peer) {
    if (peer.senderId == null) {
      return IconButton(
        icon: const Icon(Icons.help_outline),
        color: Colors.grey,
        tooltip: 'No sender ID available',
        onPressed: null,
      );
    }

    switch (peer.connectionState) {
      case PeerConnectionState.discovered:
      case PeerConnectionState.disconnected:
        return IconButton(
          icon: const Icon(Icons.link),
          color: Colors.blue,
          tooltip: 'Connect',
          onPressed: peer.canConnect ? () => _connectToPeer(peer) : null,
        );
      case PeerConnectionState.connecting:
        return IconButton(
          icon: const Icon(Icons.hourglass_empty),
          color: Colors.orange,
          tooltip: 'Connecting...',
          onPressed: null,
        );
      case PeerConnectionState.connected:
        return IconButton(
          icon: const Icon(Icons.link_off),
          color: Colors.red,
          tooltip: 'Disconnect',
          onPressed: () => _disconnectFromPeer(peer),
        );
      case PeerConnectionState.disconnecting:
        return IconButton(
          icon: const Icon(Icons.hourglass_empty),
          color: Colors.orange,
          tooltip: 'Disconnecting...',
          onPressed: null,
        );
    }
  }

  Widget _buildBlockButton(Peer peer) {
    if (peer.senderId == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.block),
      color: Colors.red,
      tooltip: 'Block Peer',
      onPressed: () => _blockPeer(peer),
    );
  }

  String _getConnectionStateText(PeerConnectionState state) {
    switch (state) {
      case PeerConnectionState.discovered:
        return 'Discovered';
      case PeerConnectionState.connecting:
        return 'Connecting...';
      case PeerConnectionState.connected:
        return 'Connected';
      case PeerConnectionState.disconnecting:
        return 'Disconnecting...';
      case PeerConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _disconnectionSubscription?.cancel();
    super.dispose();
  }
}

