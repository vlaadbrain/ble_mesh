import Foundation
import CoreBluetooth

/// Manages discovered and connected peers
class PeerManager {
    private let tag = "PeerManager"

    // Thread-safe dictionaries for peers
    private let queue = DispatchQueue(label: "com.ble_mesh.peermanager")
    private var discoveredPeers: [String: Peer] = [:]
    private var connectedPeers: [String: Peer] = [:]

    // Callbacks
    var onPeerDiscovered: ((Peer) -> Void)?
    var onPeerConnected: ((Peer) -> Void)?
    var onPeerDisconnected: ((Peer) -> Void)?

    /// Add a discovered peer
    func addDiscoveredPeer(_ peer: Peer) {
        queue.async { [weak self] in
            guard let self = self else { return }

            if let existingPeer = self.discoveredPeers[peer.id] {
                // Update existing peer (RSSI, lastSeen, etc.)
                let updatedPeer = Peer(
                    senderId: existingPeer.senderId,
                    connectionId: peer.id,
                    nickname: peer.nickname,
                    rssi: peer.rssi,
                    lastSeen: Date(),
                    connectionState: existingPeer.connectionState,
                    hopCount: existingPeer.hopCount,
                    lastForwardTime: existingPeer.lastForwardTime,
                    isBlocked: existingPeer.isBlocked,
                    peripheral: peer.peripheral
                )
                self.discoveredPeers[peer.id] = updatedPeer
                print("[\(self.tag)] Updated peer: \(peer.id) (\(peer.nickname)), RSSI: \(peer.rssi)")
            } else {
                // New peer discovered
                self.discoveredPeers[peer.id] = peer
                print("[\(self.tag)] New peer discovered: \(peer.id) (\(peer.nickname))")

                DispatchQueue.main.async {
                    self.onPeerDiscovered?(peer)
                }
            }
        }
    }

    /// Mark a peer as connected
    func markPeerConnected(_ peerId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let peer = self.discoveredPeers[peerId] else { return }

            let connectedPeer = Peer(
                senderId: peer.senderId,
                connectionId: peer.id,
                nickname: peer.nickname,
                rssi: peer.rssi,
                lastSeen: Date(),
                connectionState: .connected,
                hopCount: peer.hopCount,
                lastForwardTime: peer.lastForwardTime,
                isBlocked: peer.isBlocked,
                peripheral: peer.peripheral
            )

            self.connectedPeers[peerId] = connectedPeer
            self.discoveredPeers[peerId] = connectedPeer

            print("[\(self.tag)] Peer connected: \(peerId) (\(peer.nickname))")

            DispatchQueue.main.async {
                self.onPeerConnected?(connectedPeer)
            }
        }
    }

    /// Mark a peer as disconnected
    func markPeerDisconnected(_ peerId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let peer = self.connectedPeers.removeValue(forKey: peerId) else { return }

            let disconnectedPeer = Peer(
                senderId: peer.senderId,
                connectionId: peer.id,
                nickname: peer.nickname,
                rssi: peer.rssi,
                lastSeen: Date(),
                connectionState: .disconnected,
                hopCount: peer.hopCount,
                lastForwardTime: peer.lastForwardTime,
                isBlocked: peer.isBlocked,
                peripheral: peer.peripheral
            )

            self.discoveredPeers[peerId] = disconnectedPeer

            print("[\(self.tag)] Peer disconnected: \(peerId) (\(peer.nickname))")

            DispatchQueue.main.async {
                self.onPeerDisconnected?(disconnectedPeer)
            }
        }
    }

    /// Remove a peer completely
    func removePeer(_ peerId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.discoveredPeers.removeValue(forKey: peerId)
            self.connectedPeers.removeValue(forKey: peerId)
            print("[\(self.tag)] Peer removed: \(peerId)")
        }
    }

    /// Get a peer by ID (connectionId)
    func getPeer(_ peerId: String) -> Peer? {
        return queue.sync {
            return discoveredPeers[peerId]
        }
    }

    /// Get a peer by senderId (stable identifier)
    func getPeerBySenderId(_ senderId: String) -> Peer? {
        return queue.sync {
            return discoveredPeers.values.first { $0.senderId == senderId }
        }
    }

    /// Get connectionId by senderId
    func getConnectionIdBySenderId(_ senderId: String) -> String? {
        return queue.sync {
            return discoveredPeers.values.first { $0.senderId == senderId }?.connectionId
        }
    }

    /// Update peer's senderId
    func updatePeerSenderId(_ connectionId: String, senderId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard var peer = self.discoveredPeers[connectionId] else { return }

            // Create updated peer with new senderId
            let updatedPeer = Peer(
                senderId: senderId,
                connectionId: peer.connectionId,
                nickname: peer.nickname,
                rssi: peer.rssi,
                lastSeen: peer.lastSeen,
                connectionState: peer.connectionState,
                hopCount: peer.hopCount,
                lastForwardTime: peer.lastForwardTime,
                isBlocked: peer.isBlocked,
                peripheral: peer.peripheral
            )

            self.discoveredPeers[connectionId] = updatedPeer

            // Also update in connectedPeers if present
            if self.connectedPeers[connectionId] != nil {
                self.connectedPeers[connectionId] = updatedPeer
            }

            print("[\\(self.tag)] Updated senderId for peer \\(connectionId): \\(senderId)")
        }
    }

    /// Update peer's connection state
    func updatePeerConnectionState(_ senderId: String, state: PeerConnectionState) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let peer = self.getPeerBySenderId(senderId) else { return }

            let updatedPeer = Peer(
                senderId: peer.senderId,
                connectionId: peer.connectionId,
                nickname: peer.nickname,
                rssi: peer.rssi,
                lastSeen: Date(),
                connectionState: state,
                hopCount: peer.hopCount,
                lastForwardTime: peer.lastForwardTime,
                isBlocked: peer.isBlocked,
                peripheral: peer.peripheral
            )

            self.discoveredPeers[peer.connectionId] = updatedPeer

            // Manage connectedPeers based on state
            if state == .connected {
                self.connectedPeers[peer.connectionId] = updatedPeer
            } else if state == .disconnected {
                self.connectedPeers.removeValue(forKey: peer.connectionId)
            }

            print("[\\(self.tag)] Updated connection state for senderId \\(senderId): \\(state.rawValue)")
        }
    }

    /// Get all discovered peers
    func getDiscoveredPeers() -> [Peer] {
        return queue.sync {
            return Array(discoveredPeers.values)
        }
    }

    /// Get all connected peers
    func getConnectedPeers() -> [Peer] {
        return queue.sync {
            return Array(connectedPeers.values)
        }
    }

    /// Get count of connected peers
    func getConnectedPeerCount() -> Int {
        return queue.sync {
            return connectedPeers.count
        }
    }

    /// Check if a peer is connected
    func isPeerConnected(_ peerId: String) -> Bool {
        return queue.sync {
            return connectedPeers[peerId] != nil
        }
    }

    /// Clear all peers
    func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.discoveredPeers.removeAll()
            self.connectedPeers.removeAll()
            print("[\(self.tag)] All peers cleared")
        }
    }

    /// Remove stale peers (not seen for a while)
    func removeStalePeers(timeoutMs: TimeInterval = 60.0) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let currentTime = Date()
            var staleCount = 0

            let stalePeers = self.discoveredPeers.filter { (_, peer) in
                return peer.connectionState != .connected && currentTime.timeIntervalSince(peer.lastSeen) > timeoutMs
            }

            for (peerId, _) in stalePeers {
                self.discoveredPeers.removeValue(forKey: peerId)
                staleCount += 1
            }

            if staleCount > 0 {
                print("[\(self.tag)] Removed \(staleCount) stale peers")
            }
        }
    }

    /// Clean up resources
    func cleanup() {
        clearAll()
        onPeerDiscovered = nil
        onPeerConnected = nil
        onPeerDisconnected = nil
    }
}

