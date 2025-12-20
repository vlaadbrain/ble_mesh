import 'package:flutter/material.dart';
import 'package:ble_mesh/ble_mesh.dart';

class BlocklistScreen extends StatefulWidget {
  final BleMesh bleMesh;

  const BlocklistScreen({
    super.key,
    required this.bleMesh,
  });

  @override
  State<BlocklistScreen> createState() => _BlocklistScreenState();
}

class _BlocklistScreenState extends State<BlocklistScreen> {
  List<String> _blockedPeers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedPeers();
  }

  Future<void> _loadBlockedPeers() async {
    setState(() => _isLoading = true);
    try {
      final blocked = await widget.bleMesh.getBlockedPeers();
      setState(() {
        _blockedPeers = blocked;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load blocklist: $e');
    }
  }

  Future<void> _unblockPeer(String senderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock Peer'),
        content: Text('Unblock peer $senderId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await widget.bleMesh.unblockPeer(senderId);
        if (success) {
          setState(() {
            _blockedPeers.remove(senderId);
          });
          _showSnackBar('Unblocked peer');
        } else {
          _showSnackBar('Failed to unblock peer');
        }
      } catch (e) {
        _showSnackBar('Error unblocking peer: $e');
      }
    }
  }

  Future<void> _clearBlocklist() async {
    if (_blockedPeers.isEmpty) {
      _showSnackBar('Blocklist is already empty');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Blocklist'),
        content: Text('Unblock all ${_blockedPeers.length} peer(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.bleMesh.clearBlocklist();
        setState(() {
          _blockedPeers.clear();
        });
        _showSnackBar('Blocklist cleared');
      } catch (e) {
        _showSnackBar('Error clearing blocklist: $e');
      }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocklist'),
        actions: [
          if (_blockedPeers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear All',
              onPressed: _clearBlocklist,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedPeers.isEmpty
              ? _buildEmptyState()
              : _buildBlocklist(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Blocked Peers',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Blocked peers will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocklist() {
    return Column(
      children: [
        // Info Banner
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.red.shade50,
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Blocked peers cannot connect and will not appear in discovery',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Blocked Peers List
        Expanded(
          child: ListView.builder(
            itemCount: _blockedPeers.length,
            itemBuilder: (context, index) {
              final senderId = _blockedPeers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: Text(
                    senderId,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  subtitle: const Text('Blocked peer'),
                  trailing: IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    color: Colors.blue,
                    tooltip: 'Unblock',
                    onPressed: () => _unblockPeer(senderId),
                  ),
                ),
              );
            },
          ),
        ),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_blockedPeers.length} peer(s) blocked',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _clearBlocklist,
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('Clear All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

