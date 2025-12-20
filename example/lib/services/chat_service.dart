import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ble_mesh/ble_mesh.dart';

/// Service that manages chat message queue and notifies listeners of changes
class ChatService extends ChangeNotifier {
  final BleMesh _bleMesh;

  // Queue of messages (in chronological order)
  final List<Message> _messages = [];

  // Stream subscription
  StreamSubscription<Message>? _messageSubscription;

  /// Current list of messages
  List<Message> get messages => List.unmodifiable(_messages);
  
  /// Count of messages
  int get messageCount => _messages.length;
  
  /// Maximum number of messages to keep in queue (to prevent memory issues)
  final int maxMessages;
  
  ChatService(this._bleMesh, {this.maxMessages = 1000}) {
    _setupListener();
  }
  
  /// Setup stream listener for messages
  void _setupListener() {
    _messageSubscription = _bleMesh.messageStream.listen((message) {
      _addMessage(message);
    });
  }
  
  /// Add a message to the queue
  void _addMessage(Message message) {
    _messages.add(message);
    
    // Trim old messages if exceeding max
    if (_messages.length > maxMessages) {
      _messages.removeRange(0, _messages.length - maxMessages);
    }
    
    _notifyListeners();
  }
  
  /// Send a message
  Future<void> sendMessage(String content, String nickname) async {
    await _bleMesh.sendPublicMessage(content);

    // Add own message to the list
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final ownMessage = Message(
      id: messageId,
      senderId: 'self',
      senderNickname: nickname,
      content: content,
      type: MessageType.public,
      timestamp: DateTime.now(),
      channel: null,
      isEncrypted: false,
      status: DeliveryStatus.sent,
      // Phase 2: Routing fields
      messageId: messageId,
      ttl: 7,
      hopCount: 0,
      isForwarded: false,
    );

    _addMessage(ownMessage);
  }
  
  /// Clear all messages
  void clearAll() {
    _messages.clear();
    _notifyListeners();
  }
  
  /// Get messages from a specific sender
  List<Message> getMessagesBySender(String senderId) {
    return _messages
        .where((msg) => msg.senderId == senderId)
        .toList();
  }
  
  /// Get messages from a specific sender nickname
  List<Message> getMessagesByNickname(String nickname) {
    return _messages
        .where((msg) => msg.senderNickname == nickname)
        .toList();
  }
  
  /// Get recent messages (last N messages)
  List<Message> getRecentMessages(int count) {
    if (_messages.length <= count) {
      return messages;
    }
    return _messages.sublist(_messages.length - count);
  }
  
  /// Get messages sent in the last duration
  List<Message> getMessagesSince(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _messages
        .where((msg) => msg.timestamp.isAfter(cutoff))
        .toList();
  }
  
  /// Get forwarded messages only
  List<Message> getForwardedMessages() {
    return _messages
        .where((msg) => msg.isForwarded)
        .toList();
  }
  
  /// Get direct (non-forwarded) messages only
  List<Message> getDirectMessages() {
    return _messages
        .where((msg) => !msg.isForwarded)
        .toList();
  }
  
  /// Get message statistics
  Map<String, dynamic> getStatistics() {
    final totalMessages = _messages.length;
    final forwardedCount = _messages.where((m) => m.isForwarded).length;
    final directCount = totalMessages - forwardedCount;
    
    // Count messages by sender
    final senderCounts = <String, int>{};
    for (final msg in _messages) {
      senderCounts[msg.senderNickname] = (senderCounts[msg.senderNickname] ?? 0) + 1;
    }
    
    // Calculate average hop count
    final totalHops = _messages.fold<int>(0, (sum, msg) => sum + msg.hopCount);
    final avgHopCount = totalMessages > 0 ? totalHops / totalMessages : 0.0;
    
    return {
      'totalMessages': totalMessages,
      'directMessages': directCount,
      'forwardedMessages': forwardedCount,
      'averageHopCount': avgHopCount,
      'uniqueSenders': senderCounts.length,
      'senderCounts': senderCounts,
    };
  }

  /// Notify all listeners of message list changes
  void _notifyListeners() {
    notifyListeners();
  }

  /// Dispose of resources
  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}

