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
                    id: peer.id,
                    nickname: peer.nickname,
                    rssi: peer.rssi,
                    lastSeen: Date(),
                    isConnected: existingPeer.isConnected,
                    hopCount: existingPeer.hopCount,
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
                id: peer.id,
                nickname: peer.nickname,
                rssi: peer.rssi,
                lastSeen: Date(),
                isConnected: true,
                hopCount: peer.hopCount,
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
                id: peer.id,
                nickname: peer.nickname,
                rssi: peer.rssi,
                lastSeen: Date(),
                isConnected: false,
                hopCount: peer.hopCount,
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

    /// Get a peer by ID
    func getPeer(_ peerId: String) -> Peer? {
        return queue.sync {
            return discoveredPeers[peerId]
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
                return !peer.isConnected && currentTime.timeIntervalSince(peer.lastSeen) > timeoutMs
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

