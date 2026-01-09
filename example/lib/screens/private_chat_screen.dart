import 'package:flutter/material.dart';
import 'package:ble_mesh/ble_mesh.dart';
import 'dart:async';

/// Screen for encrypted private messaging with a specific peer
class PrivateChatScreen extends StatefulWidget {
  final BleMesh bleMesh;
  final Peer peer;
  final String nickname;

  const PrivateChatScreen({
    super.key,
    required this.bleMesh,
    required this.peer,
    required this.nickname,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Message>? _messageSubscription;
  bool _isSending = false;

  // Track peer state locally so we can update when key exchange completes
  late Peer _peer;
  // Store original callback to restore on dispose
  void Function(String peerId, List<int> publicKey)? _originalKeyCallback;

  @override
  void initState() {
    super.initState();
    _peer = widget.peer;
    _setupKeyExchangeListener();
    _listenToMessages();
  }

  void _setupKeyExchangeListener() {
    // Store original callback to restore later
    _originalKeyCallback = widget.bleMesh.onPeerPublicKeyReceived;

    // Set up our listener that chains to the original
    widget.bleMesh.onPeerPublicKeyReceived = (peerId, publicKey) {
      // Call original callback first (for home screen updates)
      _originalKeyCallback?.call(peerId, publicKey);

      // Update our local peer if it's the one we're chatting with
      if (peerId == _peer.id && mounted) {
        setState(() {
          _peer = Peer(
            id: _peer.id,
            nickname: _peer.nickname,
            rssi: _peer.rssi,
            lastSeen: _peer.lastSeen,
            isConnected: _peer.isConnected,
            hopCount: _peer.hopCount,
            lastForwardTime: _peer.lastForwardTime,
            publicKey: publicKey,
          );
        });
        _showSnackBar('Encryption key received! You can now send private messages.');
      }
    };
  }

  void _listenToMessages() {
    _messageSubscription = widget.bleMesh.messageStream.listen((message) {
      // Only show messages from this peer or sent to this peer
      if (message.type == MessageType.private &&
          (message.senderId == _peer.id ||
              message.senderId == 'self')) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Check if peer has public key
    if (_peer.publicKey == null || _peer.publicKey!.isEmpty) {
      _showKeyExchangeDialog();
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await widget.bleMesh.sendPrivateMessage(_peer.id, text);

      // Add own message to the list
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final ownMessage = Message(
        id: messageId,
        senderId: 'self',
        senderNickname: widget.nickname,
        content: text,
        type: MessageType.private,
        timestamp: DateTime.now(),
        isEncrypted: true,
        status: DeliveryStatus.sent,
        messageId: messageId,
        ttl: 7,
        hopCount: 0,
        isForwarded: false,
      );

      setState(() {
        _messages.add(ownMessage);
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (e is UnimplementedError) {
        _showSnackBar(
          'Private messaging requires platform implementation. '
          'The encryption layer is ready but native code needs updating.',
          duration: const Duration(seconds: 4),
        );
      } else {
        _showSnackBar('Failed to send message: $e');
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _showSnackBar(String message, {Duration? duration}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration ?? const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Show dialog explaining we're waiting for peer's key
  void _showKeyExchangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange),
            SizedBox(width: 8),
            Text('Waiting for Key'),
          ],
        ),
        content: Text(
          'You haven\'t received ${_peer.nickname}\'s encryption key yet.\n\n'
          'Ask them to share their public key with you, or share yours first to prompt them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _sharePublicKey();
            },
            icon: const Icon(Icons.vpn_key),
            label: const Text('Share My Key'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Share public key with the peer
  Future<void> _sharePublicKey() async {
    try {
      _showSnackBar('Sharing encryption key with ${_peer.nickname}...');

      final publicKey = await widget.bleMesh.getPublicKey();
      await widget.bleMesh.sharePublicKey(peerId: _peer.id, publicKey: publicKey);

      _showSnackBar('Encryption key shared! Ask ${_peer.nickname} to share their key too.');
    } catch (e) {
      _showSnackBar('Failed to share key: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.lock, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_peer.nickname),
                  Text(
                    'End-to-end encrypted',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade300,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showEncryptionInfo();
            },
            tooltip: 'Encryption info',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                _messages.clear();
              });
            },
            tooltip: 'Clear messages',
          ),
        ],
      ),
      body: Column(
        children: [
          // Encryption indicator banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(
                bottom: BorderSide(
                  color: Colors.green.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user,
                  color: Colors.green.shade700,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Messages are end-to-end encrypted with ${_peer.nickname}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Secure private chat',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Messages in this chat are encrypted with X25519 + Chacha20-Poly1305',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Send a message to start',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isOwnMessage = message.senderId == 'self';

                      return _MessageBubble(
                        message: message,
                        isOwnMessage: isOwnMessage,
                      );
                    },
                  ),
          ),

          // Message Input
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8.0),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type encrypted message...',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isSending,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          _isSending ? Colors.grey : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEncryptionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.green),
            SizedBox(width: 8),
            Text('Encryption Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This chat is protected with:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Key Exchange', 'X25519 ECDH'),
              _buildInfoRow('Encryption', 'Chacha20-Poly1305 AEAD'),
              _buildInfoRow('Signatures', 'Ed25519'),
              _buildInfoRow('Key Derivation', 'HKDF-SHA256'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Security Features',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildFeature('End-to-end encryption'),
                    _buildFeature('Forward secrecy'),
                    _buildFeature('Message authentication'),
                    _buildFeature('Replay protection'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Note: Platform implementation is still in progress. '
                'The encryption layer is ready but requires native code updates.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.check, color: Colors.green.shade700, size: 14),
          const SizedBox(width: 6),
          Text(
            feature,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Restore original callback
    widget.bleMesh.onPeerPublicKeyReceived = _originalKeyCallback;
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwnMessage;

  const _MessageBubble({
    required this.message,
    required this.isOwnMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwnMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green.shade200,
              child: Text(
                message.senderNickname.isNotEmpty
                    ? message.senderNickname[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isOwnMessage
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isOwnMessage)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                    child: Text(
                      message.senderNickname,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isOwnMessage
                        ? Colors.green.shade600
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isOwnMessage ? 16 : 4),
                      bottomRight: Radius.circular(isOwnMessage ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 16,
                      color: isOwnMessage ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 8.0, right: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock,
                        size: 12,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (isOwnMessage) ...[
                        const SizedBox(width: 4),
                        Icon(
                          _getStatusIcon(message.status),
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isOwnMessage) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green.shade200,
              child: Text(
                message.senderNickname.isNotEmpty
                    ? message.senderNickname[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  IconData _getStatusIcon(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return Icons.access_time;
      case DeliveryStatus.sent:
        return Icons.check;
      case DeliveryStatus.delivered:
        return Icons.done_all;
      case DeliveryStatus.failed:
        return Icons.error_outline;
    }
  }
}

