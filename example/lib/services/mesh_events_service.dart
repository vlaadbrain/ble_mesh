import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ble_mesh/ble_mesh.dart';

/// Wrapper class for MeshEvent with timestamp
class MeshEventEntry {
  final MeshEvent event;
  final DateTime timestamp;
  final int id;

  MeshEventEntry({
    required this.event,
    required this.timestamp,
    required this.id,
  });
}

/// Service that manages mesh event queue and notifies listeners of changes
class MeshEventsService extends ChangeNotifier {
  final BleMesh _bleMesh;

  // Queue of events (in chronological order)
  final List<MeshEventEntry> _events = [];

  // Stream subscription
  StreamSubscription<MeshEvent>? _eventSubscription;

  // Event counter for IDs
  int _eventCounter = 0;

  /// Current list of events
  List<MeshEventEntry> get events => List.unmodifiable(_events);

  /// Count of events
  int get eventCount => _events.length;

  /// Maximum number of events to keep in queue (to prevent memory issues)
  final int maxEvents;

  MeshEventsService(this._bleMesh, {this.maxEvents = 500}) {
    _setupListener();
  }

  /// Setup stream listener for mesh events
  void _setupListener() {
    _eventSubscription = _bleMesh.meshEventStream.listen((event) {
      _addEvent(event);
    });
  }

  /// Add an event to the queue
  void _addEvent(MeshEvent event) {
    _eventCounter++;
    _events.insert(
      0,
      MeshEventEntry(
        event: event,
        timestamp: DateTime.now(),
        id: _eventCounter,
      ),
    );

    // Trim old events if exceeding max
    if (_events.length > maxEvents) {
      _events.removeLast();
    }

    _notifyListeners();
  }

  /// Clear all events
  void clearAll() {
    _events.clear();
    _eventCounter = 0;
    _notifyListeners();
  }

  /// Get events by type
  List<MeshEventEntry> getEventsByType(MeshEventType type) {
    return _events
        .where((entry) => entry.event.type == type)
        .toList();
  }

  /// Get recent events (last N events)
  List<MeshEventEntry> getRecentEvents(int count) {
    if (_events.length <= count) {
      return events;
    }
    return _events.sublist(0, count);
  }

  /// Get events since a specific time
  List<MeshEventEntry> getEventsSince(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _events
        .where((entry) => entry.timestamp.isAfter(cutoff))
        .toList();
  }

  /// Get error events only
  List<MeshEventEntry> getErrorEvents() {
    return getEventsByType(MeshEventType.error);
  }

  /// Get peer-related events
  List<MeshEventEntry> getPeerEvents() {
    return _events.where((entry) {
      return entry.event.type == MeshEventType.peerDiscovered ||
             entry.event.type == MeshEventType.peerConnected ||
             entry.event.type == MeshEventType.peerDisconnected;
    }).toList();
  }

  /// Get mesh lifecycle events
  List<MeshEventEntry> getMeshLifecycleEvents() {
    return _events.where((entry) {
      return entry.event.type == MeshEventType.meshStarted ||
             entry.event.type == MeshEventType.meshStopped;
    }).toList();
  }

  /// Get event statistics
  Map<String, dynamic> getStatistics() {
    final totalEvents = _events.length;

    // Count events by type
    final typeCounts = <MeshEventType, int>{};
    for (final entry in _events) {
      typeCounts[entry.event.type] = (typeCounts[entry.event.type] ?? 0) + 1;
    }

    // Count errors
    final errorCount = typeCounts[MeshEventType.error] ?? 0;

    // Count peer events
    final peerDiscoveredCount = typeCounts[MeshEventType.peerDiscovered] ?? 0;
    final peerConnectedCount = typeCounts[MeshEventType.peerConnected] ?? 0;
    final peerDisconnectedCount = typeCounts[MeshEventType.peerDisconnected] ?? 0;

    return {
      'totalEvents': totalEvents,
      'errorCount': errorCount,
      'peerDiscoveredCount': peerDiscoveredCount,
      'peerConnectedCount': peerConnectedCount,
      'peerDisconnectedCount': peerDisconnectedCount,
      'typeCounts': typeCounts.map((key, value) => MapEntry(key.toString(), value)),
    };
  }

  /// Get events grouped by type
  Map<MeshEventType, List<MeshEventEntry>> getEventsByTypeGrouped() {
    final grouped = <MeshEventType, List<MeshEventEntry>>{};
    for (final entry in _events) {
      grouped.putIfAbsent(entry.event.type, () => []).add(entry);
    }
    return grouped;
  }

  /// Search events by message content
  List<MeshEventEntry> searchEvents(String query) {
    final lowerQuery = query.toLowerCase();
    return _events.where((entry) {
      final message = entry.event.message ?? '';
      return message.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Notify all listeners of event list changes
  void _notifyListeners() {
    notifyListeners();
  }

  /// Dispose of resources
  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

