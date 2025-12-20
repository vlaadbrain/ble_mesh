import Foundation
import CoreBluetooth

/// Main coordinator for Bluetooth mesh networking
/// Manages scanning, advertising, and peer connections
class BluetoothMeshService {
    private let tag = "BluetoothMeshService"

    // Device identity manager
    private let deviceIdManager = DeviceIdManager()

    // Components
    private let bleScanner = BleScanner()
    private lazy var bleAdvertiser = BleAdvertiser(deviceIdManager: deviceIdManager)
    private let blePeripheralServer = BlePeripheralServer()
    private let peerManager = PeerManager()
    private let connectionManager = BleConnectionManager()
    private let serviceManager = ServiceManager()
    private let blocklistManager = BlocklistManager()

    // Phase 2: Message deduplication cache
    private let messageCache = MessageCache(maxSize: 1000, expirationTimeInterval: 5 * 60) // 5 minutes

    // State
    private var isRunning = false
    private var deviceNickname: String = "BleMesh_\(Int(Date().timeIntervalSince1970) % 10000)"
    private var powerMode: PowerMode = .balanced
    private var enableEncryption: Bool = true

    // Timers for periodic tasks
    private var scanTimer: Timer?
    private var cleanupTimer: Timer?

    // Callbacks
    var onPeerDiscovered: ((Peer) -> Void)?
    var onPeerConnected: ((Peer) -> Void)?
    var onPeerDisconnected: ((Peer) -> Void)?
    var onMeshEvent: ((MeshEvent) -> Void)?
    var onMessageReceived: ((Message) -> Void)?

    init() {
        setupCallbacks()
    }

    /// Initialize the mesh service
    func initialize(nickname: String?, encryption: Bool, mode: PowerMode) {
        deviceNickname = nickname ?? deviceNickname
        enableEncryption = encryption
        powerMode = mode

        // Initialize scanner and advertiser
        bleScanner.initialize()
        bleAdvertiser.initialize()

        // Initialize connection manager with central manager
        if let centralManager = bleScanner.getCentralManager() {
            connectionManager.initialize(centralManager: centralManager)
        }

        print("[\(tag)] Initialized with nickname: \(deviceNickname), encryption: \(enableEncryption), mode: \(powerMode)")
    }

    /// Start the mesh network (scanning and advertising)
    func start() {
        if isRunning {
            print("[\(tag)] Mesh service already running")
            return
        }

        print("[\(tag)] Starting mesh service")

        // Start peripheral server
        let serverStarted = blePeripheralServer.start()
        if !serverStarted {
            print("[\(tag)] Failed to start peripheral server")
        }

        // Start advertising
        bleAdvertiser.startAdvertising(deviceName: deviceNickname)

        // Start scanning
        bleScanner.startScanning()

        isRunning = true

        // Schedule periodic tasks
        schedulePeriodicTasks()

        // Notify mesh started
        onMeshEvent?(MeshEvent(
            type: .meshStarted,
            message: "Mesh network started"
        ))
    }

    /// Stop the mesh network
    func stop() {
        if !isRunning {
            print("[\(tag)] Mesh service not running")
            return
        }

        print("[\(tag)] Stopping mesh service")

        // Stop scanning and advertising
        bleScanner.stopScanning()
        bleAdvertiser.stopAdvertising()

        // Cancel periodic tasks
        scanTimer?.invalidate()
        scanTimer = nil
        cleanupTimer?.invalidate()
        cleanupTimer = nil

        isRunning = false

        // Notify mesh stopped
        onMeshEvent?(MeshEvent(
            type: .meshStopped,
            message: "Mesh network stopped"
        ))
    }

    /// Get list of connected peers
    func getConnectedPeers() -> [Peer] {
        return peerManager.getConnectedPeers()
    }

    /// Get list of discovered peers
    func getDiscoveredPeers() -> [Peer] {
        return peerManager.getDiscoveredPeers()
    }

    /// Start discovery mode (scanning without auto-connect)
    /// Discovered peers will NOT be automatically connected.
    /// Use connectToPeer(senderId:) to manually connect to a discovered peer.
    func startDiscovery() {
        print("[\(tag)] Starting discovery mode")

        // Start scanning - peers will only be added to discovered list
        // Manual connection control via connectToPeer() is required
        bleScanner.startScanning()
    }

    /// Stop discovery mode
    func stopDiscovery() {
        print("[\(tag)] Stopping discovery mode")
        bleScanner.stopScanning()
    }

    // MARK: - Manual Connection Control

    /// Manually connect to a peer by senderId
    func connectToPeer(senderId: String) -> Bool {
        print("[\(tag)] Manual connect requested for senderId: \(senderId)")

        // Find peer by senderId
        guard let peer = peerManager.getPeerBySenderId(senderId) else {
            print("[\(tag)] Error: Peer with senderId \(senderId) not found")
            return false
        }

        // Check if peer has peripheral reference
        guard let peripheral = peer.peripheral else {
            print("[\(tag)] Error: Peer \(senderId) has no peripheral reference")
            return false
        }

        // Check if already connected
        if peer.connectionState == .connected {
            print("[\(tag)] Peer \(senderId) is already connected")
            return true
        }

        // Check max connections
        let connectedCount = peerManager.getConnectedPeerCount()
        if connectedCount >= BleConstants.maxConnections {
            print("[\(tag)] Cannot connect: maximum connections (\(BleConstants.maxConnections)) reached")
            return false
        }

        // Update state to connecting
        peerManager.updatePeerConnectionState(senderId, state: .connecting)
        print("[\(tag)] Connecting to peer \(senderId) (\(peer.nickname))...")

        // Initiate connection
        connectionManager.connectToPeripheral(peripheral)

        return true
    }

    /// Manually disconnect from a peer by senderId
    func disconnectFromPeer(senderId: String) -> Bool {
        print("[\(tag)] Manual disconnect requested for senderId: \(senderId)")

        // Find peer by senderId
        guard let peer = peerManager.getPeerBySenderId(senderId) else {
            print("[\(tag)] Error: Peer with senderId \(senderId) not found")
            return false
        }

        // Check if peer is connected
        guard peer.connectionState == .connected else {
            print("[\(tag)] Peer \(senderId) is not connected (state: \(peer.connectionState.rawValue))")
            return false
        }

        // Check if peer has peripheral reference
        guard let peripheral = peer.peripheral else {
            print("[\(tag)] Error: Peer \(senderId) has no peripheral reference")
            return false
        }

        // Update state to disconnecting
        peerManager.updatePeerConnectionState(senderId, state: .disconnecting)
        print("[\(tag)] Disconnecting from peer \(senderId) (\(peer.nickname))...")

        // Initiate disconnection
        connectionManager.disconnectPeripheral(peripheral.identifier.uuidString)

        return true
    }

    /// Get connection state of a peer by senderId
    func getPeerConnectionState(senderId: String) -> String? {
        guard let peer = peerManager.getPeerBySenderId(senderId) else {
            print("[\(tag)] Peer with senderId \(senderId) not found")
            return nil
        }

        return peer.connectionState.rawValue
    }

    /// Check if mesh is running
    func isRunningStatus() -> Bool {
        return isRunning
    }

    /// Send a public message to all connected peers
    func sendPublicMessage(content: String) {
        guard isRunning else {
            print("[\(tag)] Cannot send message: mesh service not running")
            return
        }

        let connectedPeripherals = connectionManager.getConnectedPeripherals()
        guard !connectedPeripherals.isEmpty() else {
            print("[\(tag)] No connected peers to send message to")
            return
        }

        print("[\(tag)] Sending public message to \(connectedPeripherals.count) peers: \(content)")

        // Phase 2: Create message object
        let senderId = UIDevice.current.identifierForVendor?.uuidString ?? "00:00:00:00:00:00"
        // Convert UUID to MAC address format (use first 6 bytes)
        let senderIdFormatted = String(senderId.prefix(17).replacingOccurrences(of: "-", with: ":"))

        let message = Message(
            senderId: senderIdFormatted,
            senderNickname: deviceNickname,
            content: content,
            type: .publicMessage,
            status: .sent,
            ttl: 7,  // Default TTL
            hopCount: 0,
            messageId: MessageHeader.generateMessageId(),
            isForwarded: false
        )

        // Serialize message (header + payload)
        let messageData = message.toData()

        print("[\(tag)] Created message: senderId=\(message.senderId), messageId=\(message.messageId), ttl=\(message.ttl), size=\(messageData.count) bytes")

        // Add to cache to prevent processing if we receive it back (loop prevention)
        _ = messageCache.addMessage(senderId: message.senderId, messageId: message.messageId)
        print("[\(tag)] Added own message to cache for loop prevention")

        // Send to all connected peers
        connectedPeripherals.forEach { identifier in
            if let peripheral = connectionManager.getConnectedPeripheral(identifier),
               let msgCharacteristic = serviceManager.findMsgCharacteristic(peripheral) {
                _ = serviceManager.writeCharacteristic(peripheral, characteristic: msgCharacteristic, data: messageData)
                print("[\(tag)] Sent message to peer: \(identifier)")
            } else {
                print("[\(tag)] MSG characteristic not found for peer: \(identifier)")
            }
        }
    }

    /// Setup callbacks for scanner, advertiser, peer manager, and connection manager
    private func setupCallbacks() {
        // Scanner callbacks
        bleScanner.onDeviceDiscovered = { [weak self] peer in
            guard let self = self else { return }

            // Check if peer is blocked
            if let senderId = peer.senderId, self.blocklistManager.isBlocked(senderId) {
                print("[\(self.tag)] Ignoring blocked peer: \(senderId) (\(peer.nickname))")
                return
            }

            self.peerManager.addDiscoveredPeer(peer)

            // Manual connection control: peers are only connected when explicitly requested
            // via connectToPeer(senderId). Auto-connection has been removed to give
            // applications full control over connection decisions.
            print("[\(self.tag)] Peer discovered: \(peer.id) (\(peer.nickname)), state: \(peer.connectionState.rawValue)")
        }

        bleScanner.onScanError = { [weak self] errorCode, message in
            guard let self = self else { return }
            print("[\(self.tag)] Scan error: \(message) (code: \(errorCode))")
            self.onMeshEvent?(MeshEvent(
                type: .error,
                message: "Scan error: \(message)",
                data: ["errorCode": errorCode]
            ))
        }

        // Advertiser callbacks
        bleAdvertiser.onAdvertisingStarted = { [weak self] in
            guard let self = self else { return }
            print("[\(self.tag)] Advertising started successfully")
        }

        bleAdvertiser.onAdvertisingFailed = { [weak self] errorCode, message in
            guard let self = self else { return }
            print("[\(self.tag)] Advertising error: \(message) (code: \(errorCode))")
            self.onMeshEvent?(MeshEvent(
                type: .error,
                message: "Advertising error: \(message)",
                data: ["errorCode": errorCode]
            ))
        }

        // Peer manager callbacks
        peerManager.onPeerDiscovered = { [weak self] peer in
            guard let self = self else { return }
            print("[\(self.tag)] Peer discovered: \(peer.nickname) (\(peer.id))")
            self.onPeerDiscovered?(peer)
            self.onMeshEvent?(MeshEvent(
                type: .peerDiscovered,
                message: "Peer discovered: \(peer.nickname)",
                data: ["peerId": peer.id]
            ))
        }

        peerManager.onPeerConnected = { [weak self] peer in
            guard let self = self else { return }
            print("[\(self.tag)] Peer connected: \(peer.nickname) (\(peer.id))")
            self.onPeerConnected?(peer)
        }

        peerManager.onPeerDisconnected = { [weak self] peer in
            guard let self = self else { return }
            print("[\(self.tag)] Peer disconnected: \(peer.nickname) (\(peer.id))")
            self.onPeerDisconnected?(peer)
        }

        // Connection manager callbacks
        connectionManager.onPeripheralConnected = { [weak self] identifier, peripheral in
            guard let self = self else { return }
            print("[\(self.tag)] Peripheral connected: \(identifier)")
            self.peerManager.markPeerConnected(identifier)
        }

        connectionManager.onPeripheralDisconnected = { [weak self] identifier in
            guard let self = self else { return }
            print("[\(self.tag)] Peripheral disconnected: \(identifier)")
            self.peerManager.markPeerDisconnected(identifier)
        }

        connectionManager.onServicesDiscovered = { [weak self] identifier, peripheral in
            guard let self = self else { return }
            print("[\(self.tag)] Services discovered for peripheral: \(identifier)")

            // Setup notifications for MSG characteristic
            if let msgCharacteristic = self.serviceManager.findMsgCharacteristic(peripheral) {
                if self.serviceManager.supportsNotifications(msgCharacteristic) {
                    _ = self.serviceManager.setupNotifications(peripheral, characteristic: msgCharacteristic)
                    print("[\(self.tag)] Setup notifications for MSG characteristic")
                }
            } else {
                print("[\(self.tag)] MSG characteristic not found for peripheral: \(identifier)")
            }
        }

        connectionManager.onCharacteristicValueUpdated = { [weak self] identifier, uuid, data in
            guard let self = self else { return }
            print("[\(self.tag)] Characteristic value updated: \(uuid), size: \(data.count)")

            // Handle received message
            if uuid == BleConstants.msgCharacteristicUUID {
                // Phase 2: Deserialize message with header
                let peer = self.peerManager.getPeer(identifier)
                if let message = Message.fromData(data, senderNickname: peer?.nickname ?? "Unknown") {
                    print("[\(self.tag)] Received message: senderId=\(message.senderId), messageId=\(message.messageId), ttl=\(message.ttl), hopCount=\(message.hopCount), content=\(message.content)")

                    // Check if message is from blocked peer
                    if self.blocklistManager.isBlocked(message.senderId) {
                        print("[\(self.tag)] Ignoring message from blocked peer: \(message.senderId)")
                        return
                    }

                    // Phase 2: Check for duplicate (deduplication) using composite key
                    if self.messageCache.hasMessage(senderId: message.senderId, messageId: message.messageId) {
                        print("[\(self.tag)] Duplicate message detected, dropping: id=\(message.messageId)")
                        return
                    }

                    // Add to cache
                    _ = self.messageCache.addMessage(senderId: message.senderId, messageId: message.messageId)

                    // Send message to Flutter via callback
                    print("[\(self.tag)] Forwarding message to Flutter: \(message.content)")
                    self.onMessageReceived?(message)

                    // Phase 2: Forward message if TTL > 1
                    if message.ttl > 1 {
                        print("[\(self.tag)] Message can be forwarded (TTL=\(message.ttl)), forwarding to other peers")
                        self.forwardMessage(message, senderIdentifier: identifier)
                    } else {
                        print("[\(self.tag)] Message TTL exhausted (TTL=\(message.ttl)), not forwarding")
                    }
                } else {
                    print("[\(self.tag)] Failed to parse message from \(identifier)")
                }
            }
        }

        connectionManager.onConnectionError = { [weak self] identifier, error in
            guard let self = self else { return }
            print("[\(self.tag)] Connection error for peripheral \(identifier): \(error)")
            self.onMeshEvent?(MeshEvent(
                type: .error,
                message: "Connection error: \(error)",
                data: ["peerId": identifier]
            ))
        }

        // Peripheral server callbacks - handle incoming messages when acting as peripheral
        blePeripheralServer.onCharacteristicWriteRequest = { [weak self] central, data in
            guard let self = self else { return }
            print("[\(self.tag)] Received data from central (as peripheral): \(central.identifier), size: \(data.count)")

            // Phase 2: Deserialize message with header
            if let message = Message.fromData(data, senderNickname: "Unknown") {
                print("[\(self.tag)] Received message from central: senderId=\(message.senderId), messageId=\(message.messageId), ttl=\(message.ttl), hopCount=\(message.hopCount), content=\(message.content)")

                // Phase 2: Check for duplicate (deduplication) using composite key
                if self.messageCache.hasMessage(senderId: message.senderId, messageId: message.messageId) {
                    print("[\(self.tag)] Duplicate message detected (from central), dropping: id=\(message.messageId)")
                    return
                }

                // Add to cache
                _ = self.messageCache.addMessage(senderId: message.senderId, messageId: message.messageId)

                // Send message to Flutter via callback
                print("[\(self.tag)] Forwarding message from central to Flutter: \(message.content)")
                self.onMessageReceived?(message)

                // Phase 2: Forward message if TTL > 1
                if message.ttl > 1 {
                    print("[\(self.tag)] Message can be forwarded (TTL=\(message.ttl)), forwarding to other peers")
                    self.forwardMessage(message, senderIdentifier: central.identifier.uuidString)
                } else {
                    print("[\(self.tag)] Message TTL exhausted (TTL=\(message.ttl)), not forwarding")
                }
            } else {
                print("[\(self.tag)] Failed to parse message from central \(central.identifier)")
            }
        }

        blePeripheralServer.onCentralConnected = { [weak self] central in
            guard let self = self else { return }
            print("[\(self.tag)] Central connected (to our peripheral): \(central.identifier)")
            // Note: We don't track centrals in peerManager as they're not persistent connections
        }

        blePeripheralServer.onCentralDisconnected = { [weak self] central in
            guard let self = self else { return }
            print("[\(self.tag)] Central disconnected (from our peripheral): \(central.identifier)")
        }
    }

    /// Schedule periodic tasks (scanning, cleanup, etc.)
    private func schedulePeriodicTasks() {
        // Get scan interval based on power mode
        let scanInterval: TimeInterval
        switch powerMode {
        case .performance:
            scanInterval = BleConstants.scanIntervalBalancedMs
        case .balanced:
            scanInterval = BleConstants.scanIntervalBalancedMs
        case .powerSaver:
            scanInterval = BleConstants.scanIntervalPowerSaverMs
        case .ultraLowPower:
            scanInterval = BleConstants.scanIntervalPowerSaverMs * 2
        }

        // Schedule periodic scanning
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isRunning && !self.bleScanner.isScanningActive() {
                self.bleScanner.startScanning()
            }
        }

        // Schedule periodic cleanup of stale peers
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isRunning {
                self.peerManager.removeStalePeers()
            }
        }
    }

    /// Forward a message to all connected peers except the sender
    /// Phase 2: Multi-hop routing implementation
    ///
    /// - Parameters:
    ///   - message: Original message to forward
    ///   - senderIdentifier: Identifier of the peer who sent us this message (don't send back to them)
    private func forwardMessage(_ message: Message, senderIdentifier: String) {
        // Create a new message with decremented TTL and incremented hop count
        let forwardedMessage = Message(
            id: message.id,
            senderId: message.senderId,  // Keep original sender
            senderNickname: message.senderNickname,
            content: message.content,
            type: message.type,
            timestamp: message.timestamp,
            channel: message.channel,
            isEncrypted: message.isEncrypted,
            status: .sent,
            ttl: message.ttl - 1,  // Decrement TTL
            hopCount: message.hopCount + 1,  // Increment hop count
            messageId: message.messageId,  // Keep same message ID
            isForwarded: true
        )

        // Serialize message
        let messageData = forwardedMessage.toData()

        print("[\(tag)] Forwarding message id=\(forwardedMessage.messageId), ttl=\(forwardedMessage.ttl), hopCount=\(forwardedMessage.hopCount)")

        // Forward to all connected peers except the sender
        let connectedPeripherals = connectionManager.getConnectedPeripherals()
        var forwardCount = 0

        connectedPeripherals.forEach { identifier in
            // Skip the sender
            if identifier == senderIdentifier {
                print("[\(tag)] Skipping forward to sender: \(identifier)")
                return
            }

            if let peripheral = connectionManager.getConnectedPeripheral(identifier),
               let msgCharacteristic = serviceManager.findMsgCharacteristic(peripheral) {
                _ = serviceManager.writeCharacteristic(peripheral, characteristic: msgCharacteristic, data: messageData)
                forwardCount += 1
                print("[\(tag)] Forwarded message to peer: \(identifier)")
            } else {
                print("[\(tag)] MSG characteristic not found for peer: \(identifier)")
            }
        }

        print("[\(tag)] Message forwarded to \(forwardCount) peer(s)")
    }

    // MARK: - Blocklist Management

    /// Block a peer by sender UUID
    ///
    /// - Parameter senderId: The sender UUID to block
    /// - Returns: true if the peer was blocked successfully
    func blockPeer(_ senderId: String) -> Bool {
        let success = blocklistManager.blockPeer(senderId)

        if success {
            // Disconnect from peer if currently connected
            if let peer = peerManager.getPeerBySenderId(senderId),
               connectionManager.isConnected(peer.connectionId) {
                print("[\(tag)] Disconnecting from blocked peer: \(senderId)")
                _ = disconnectFromPeer(senderId)
            }

            // Remove from discovered peers
            if let peer = peerManager.getPeerBySenderId(senderId) {
                peerManager.removePeer(peer.connectionId)
            }
        }

        return success
    }

    /// Unblock a peer by sender UUID
    ///
    /// - Parameter senderId: The sender UUID to unblock
    /// - Returns: true if the peer was unblocked successfully
    func unblockPeer(_ senderId: String) -> Bool {
        return blocklistManager.unblockPeer(senderId)
    }

    /// Check if a peer is blocked
    ///
    /// - Parameter senderId: The sender UUID to check
    /// - Returns: true if the peer is blocked
    func isPeerBlocked(_ senderId: String) -> Bool {
        return blocklistManager.isBlocked(senderId)
    }

    /// Get list of all blocked peer sender UUIDs
    ///
    /// - Returns: Array of blocked sender UUIDs
    func getBlockedPeers() -> [String] {
        return blocklistManager.getBlockedPeers()
    }

    /// Clear the entire blocklist
    func clearBlocklist() {
        blocklistManager.clearBlocklist()
        print("[\(tag)] Blocklist cleared")
    }

    /// Clean up resources
    func cleanup() {
        stop()
        bleScanner.cleanup()
        bleAdvertiser.cleanup()
        connectionManager.cleanup()
        peerManager.cleanup()
        blocklistManager.cleanup()

        scanTimer?.invalidate()
        scanTimer = nil
        cleanupTimer?.invalidate()
        cleanupTimer = nil

        onPeerDiscovered = nil
        onPeerConnected = nil
        onPeerDisconnected = nil
        onMeshEvent = nil
    }
}

