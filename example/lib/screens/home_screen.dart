import 'package:flutter/material.dart';
import 'package:ble_mesh/ble_mesh.dart';
import 'chat_screen.dart';
import 'private_chat_screen.dart';
import 'settings_screen.dart';
import 'mesh_events_screen.dart';
import '../services/permission_service.dart';
import '../widgets/permission_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleMesh _bleMesh = BleMesh();
  String _nickname = 'Anonymous';
  bool _isMeshStarted = false;
  bool _isInitialized = false;
  bool _encryptionEnabled = true; // Phase 3: Track encryption status
  String _statusMessage = 'Not initialized';
  final List<Peer> _connectedPeers = [];

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  void _loadNickname() {
    // In a real app, you'd load this from SharedPreferences
    setState(() {
      _nickname = 'User${DateTime.now().millisecondsSinceEpoch % 10000}';
    });
  }

  Future<void> _initializeMesh() async {
    try {
      await _bleMesh.initialize(
        nickname: _nickname,
        enableEncryption: true, // Phase 3: Enable encryption
        powerMode: PowerMode.balanced,
      );
      setState(() {
        _isInitialized = true;
        _statusMessage = 'Initialized (Encryption enabled)';
      });
      _showSnackBar('Mesh initialized with encryption');
    } catch (e) {
      _showSnackBar('Failed to initialize: $e');
    }
  }

  Future<void> _startMesh() async {
    // Check and request permissions first
    final hasPermissions = await _checkAndRequestPermissions();
    if (!hasPermissions) {
      return;
    }

    if (!_isInitialized) {
      await _initializeMesh();
    }

    try {
      await _bleMesh.startMesh();
      setState(() {
        _isMeshStarted = true;
        _statusMessage = 'Mesh started - Scanning for peers';
      });
      _showSnackBar('Mesh network started');
      _startListeningToPeers();
    } catch (e) {
      _showSnackBar('Failed to start mesh: $e');
    }
  }

  /// Check and request all required permissions
  Future<bool> _checkAndRequestPermissions() async {
    // Check if permissions are already granted
    final hasPermissions = await PermissionService.hasAllPermissions();
    if (hasPermissions) {
      return true;
    }

    // Show permission explanation dialog
    if (!mounted) return false;
    final shouldRequest = await PermissionDialog.show(context);
    if (!shouldRequest) {
      _showSnackBar('Permissions are required to use BLE Mesh');
      return false;
    }

    // Request permissions
    final result = await PermissionService.requestAllPermissions();

    if (result.granted) {
      _showSnackBar('All permissions granted');
      return true;
    } else {
      // Show denial dialog
      if (!mounted) return false;
      final retry = await PermissionDeniedDialog.show(context, result);
      if (retry) {
        // User wants to try again
        return await _checkAndRequestPermissions();
      }
      return false;
    }
  }

  Future<void> _stopMesh() async {
    try {
      await _bleMesh.stopMesh();
      setState(() {
        _isMeshStarted = false;
        _statusMessage = 'Mesh stopped';
        _connectedPeers.clear();
      });
      _showSnackBar('Mesh network stopped');
    } catch (e) {
      _showSnackBar('Failed to stop mesh: $e');
    }
  }

  void _startListeningToPeers() {
    // Listen to peer connections
    _bleMesh.peerConnectedStream.listen((peer) async {
      setState(() {
        if (!_connectedPeers.any((p) => p.id == peer.id)) {
          _connectedPeers.add(peer);
        }
        _statusMessage = 'Connected to ${_connectedPeers.length} peer(s)';
      });
      _showSnackBar('Peer connected: ${peer.nickname}');

      // Phase 3: Automatically exchange public keys when a peer connects
      if (_encryptionEnabled) {
        try {
          final publicKey = await _bleMesh.getPublicKey();
          await _bleMesh.sharePublicKey(peerId: peer.id, publicKey: publicKey);
          print('Shared public key with ${peer.nickname}');
        } catch (e) {
          print('Error sharing public key: $e');
        }
      }
    });

    // Listen to peer disconnections
    _bleMesh.peerDisconnectedStream.listen((peer) {
      setState(() {
        _connectedPeers.removeWhere((p) => p.id == peer.id);
        _statusMessage = _connectedPeers.isEmpty
            ? 'No peers connected'
            : 'Connected to ${_connectedPeers.length} peer(s)';
      });
      _showSnackBar('Peer disconnected: ${peer.nickname}');
    });
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _navigateToChat() {
    if (!_isMeshStarted) {
      _showSnackBar('Please start the mesh network first');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          bleMesh: _bleMesh,
          nickname: _nickname,
        ),
      ),
    );
  }

  /// Phase 3: Navigate to private chat with a selected peer
  void _navigateToPrivateChat() {
    if (!_isMeshStarted) {
      _showSnackBar('Please start the mesh network first');
      return;
    }

    if (_connectedPeers.isEmpty) {
      _showSnackBar('No peers connected. Cannot start private chat.');
      return;
    }

    // Show peer selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.green),
            SizedBox(width: 8),
            Text('Select Peer for Private Chat'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _connectedPeers.length,
            itemBuilder: (context, index) {
              final peer = _connectedPeers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade200,
                  child: Text(
                    peer.nickname.isNotEmpty
                        ? peer.nickname[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(peer.nickname),
                subtitle: Text('RSSI: ${peer.rssi} dBm'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _openPrivateChat(peer);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _openPrivateChat(Peer peer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrivateChatScreen(
          bleMesh: _bleMesh,
          peer: peer,
          nickname: _nickname,
        ),
      ),
    );
  }

  void _navigateToMeshEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeshEventsScreen(
          bleMesh: _bleMesh,
        ),
      ),
    );
  }

  Future<void> _navigateToSettings() async {
    final newNickname = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(currentNickname: _nickname),
      ),
    );

    if (newNickname != null && newNickname.isNotEmpty) {
      setState(() {
        _nickname = newNickname;
      });

      // Reinitialize if already initialized
      if (_isInitialized) {
        if (_isMeshStarted) {
          await _stopMesh();
        }
        setState(() {
          _isInitialized = false;
        });
        _showSnackBar('Nickname updated to: $_nickname');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Mesh Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nickname Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Nickname',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _nickname,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _navigateToSettings,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status Card
            Card(
              color: _isMeshStarted
                  ? Colors.green.shade50
                  : Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isMeshStarted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _isMeshStarted ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Mesh Status',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Connected Peers Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people),
                        const SizedBox(width: 8),
                        Text(
                          'Connected Peers (${_connectedPeers.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_connectedPeers.isEmpty)
                      const Text('No peers connected')
                    else
                      ...(_connectedPeers.map((peer) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.person, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(peer.nickname)),
                                Text(
                                  'RSSI: ${peer.rssi}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Control Buttons
            if (!_isMeshStarted)
              ElevatedButton.icon(
                onPressed: _startMesh,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Mesh Network'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _stopMesh,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Mesh Network'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            const SizedBox(height: 16),

            // Chat Button
            ElevatedButton.icon(
              onPressed: _isMeshStarted ? _navigateToChat : null,
              icon: const Icon(Icons.chat),
              label: const Text('Open Public Chat'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),

            // Phase 3: Private Chat Button
            ElevatedButton.icon(
              onPressed: _isMeshStarted ? _navigateToPrivateChat : null,
              icon: const Icon(Icons.lock),
              label: const Text('Open Private Chat'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Mesh Events Button
            ElevatedButton.icon(
              onPressed: _navigateToMeshEvents,
              icon: const Icon(Icons.event_note),
              label: const Text('View Mesh Events'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const Spacer(),

            // Info Text
            Text(
              'Note: Bluetooth permissions are required. Make sure Bluetooth is enabled on your device.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_isMeshStarted) {
      _bleMesh.stopMesh();
    }
    super.dispose();
  }
}

