import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ble_mesh/ble_mesh.dart';
import '../services/mesh_events_service.dart';

/// Screen that displays all MeshEvents in real-time
class MeshEventsScreen extends StatefulWidget {
  const MeshEventsScreen({super.key});

  @override
  State<MeshEventsScreen> createState() => _MeshEventsScreenState();
}

class _MeshEventsScreenState extends State<MeshEventsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  String _getEventTypeIcon(MeshEventType type) {
    switch (type) {
      case MeshEventType.meshStarted:
        return '🟢';
      case MeshEventType.meshStopped:
        return '🔴';
      case MeshEventType.peerDiscovered:
        return '🔍';
      case MeshEventType.peerConnected:
        return '🤝';
      case MeshEventType.peerDisconnected:
        return '👋';
      case MeshEventType.messageReceived:
        return '📨';
      case MeshEventType.forwardingMetrics:
        return '📊';
      case MeshEventType.error:
        return '⚠️';
    }
  }

  Color _getEventTypeColor(MeshEventType type) {
    switch (type) {
      case MeshEventType.meshStarted:
        return Colors.green;
      case MeshEventType.meshStopped:
        return Colors.red;
      case MeshEventType.peerDiscovered:
        return Colors.blue;
      case MeshEventType.peerConnected:
        return Colors.teal;
      case MeshEventType.peerDisconnected:
        return Colors.orange;
      case MeshEventType.messageReceived:
        return Colors.purple;
      case MeshEventType.forwardingMetrics:
        return Colors.indigo;
      case MeshEventType.error:
        return Colors.red.shade700;
    }
  }

  String _formatEventType(MeshEventType type) {
    switch (type) {
      case MeshEventType.meshStarted:
        return 'Mesh Started';
      case MeshEventType.meshStopped:
        return 'Mesh Stopped';
      case MeshEventType.peerDiscovered:
        return 'Peer Discovered';
      case MeshEventType.peerConnected:
        return 'Peer Connected';
      case MeshEventType.peerDisconnected:
        return 'Peer Disconnected';
      case MeshEventType.messageReceived:
        return 'Message Received';
      case MeshEventType.forwardingMetrics:
        return 'Forwarding Metrics';
      case MeshEventType.error:
        return 'Error';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${(timestamp.millisecond ~/ 100).toString()}';
  }

  Widget _buildEventData(MeshEvent event) {
    if (event.data == null || event.data!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Special handling for forwarding metrics
    if (event.type == MeshEventType.forwardingMetrics) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.messagesForwarded != null)
              _buildDataRow('Messages Forwarded', event.messagesForwarded!),
            if (event.messagesCached != null)
              _buildDataRow('Messages Cached', event.messagesCached!),
            if (event.cacheHits != null)
              _buildDataRow('Cache Hits', event.cacheHits!),
            if (event.cacheMisses != null)
              _buildDataRow('Cache Misses', event.cacheMisses!),
          ],
        ),
      );
    }

    // Generic data display
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: event.data!.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              '${entry.key}: ${entry.value}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontFamily: 'monospace',
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDataRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the MeshEventsService for updates
    final meshEventsService = context.watch<MeshEventsService>();
    final events = meshEventsService.events;

    // Auto-scroll to top if enabled
    if (_autoScroll && _scrollController.hasClients && events.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Events'),
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.arrow_downward : Icons.arrow_downward_outlined),
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear events',
            onPressed: events.isEmpty ? null : () => meshEventsService.clearAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Events', events.length.toString()),
                _buildStatItem('Auto-scroll', _autoScroll ? 'ON' : 'OFF'),
                _buildStatItem('Max', '500'),
              ],
            ),
          ),

          // Events list
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No events yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Events will appear here as they occur',
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
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final entry = events[index];
                      return _buildEventCard(entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(MeshEventEntry entry) {
    final event = entry.event;
    final color = _getEventTypeColor(event.type);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: InkWell(
        onTap: () {
          // Show detailed event info in a dialog
          _showEventDetails(entry);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Event icon
                  Text(
                    _getEventTypeIcon(event.type),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),

                  // Event type and timestamp
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatEventType(event.type),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTimestamp(entry.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Event ID badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '#${entry.id}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),

              // Message (if present)
              if (event.message != null && event.message!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  event.message!,
                  style: const TextStyle(fontSize: 14),
                ),
              ],

              // Event data (if present)
              _buildEventData(event),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetails(MeshEventEntry entry) {
    final event = entry.event;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(_getEventTypeIcon(event.type)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_formatEventType(event.type)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Event ID', '#${entry.id}'),
              _buildDetailRow('Timestamp', entry.timestamp.toString()),
              _buildDetailRow('Type', event.type.toString()),
              if (event.message != null)
                _buildDetailRow('Message', event.message!),
              if (event.data != null && event.data!.isNotEmpty) ...[
                const Divider(),
                const Text(
                  'Event Data:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...event.data!.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      '${e.key}: ${e.value}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  );
                }),
              ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

