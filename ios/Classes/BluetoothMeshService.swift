import Foundation
import CoreBluetooth

/// Main coordinator for Bluetooth mesh networking
/// Manages scanning, advertising, and peer connections
class BluetoothMeshService {
    private let tag = "BluetoothMeshService"

    // Components
    private let bleScanner = BleScanner()
    private let bleAdvertiser = BleAdvertiser()
    private let blePeripheralServer = BlePeripheralServer()
    private let peerManager = PeerManager()
    private let connectionManager = BleConnectionManager()
    private let serviceManager = ServiceManager()

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

        print("[\(tag)] Created message: id=\(message.messageId), ttl=\(message.ttl), size=\(messageData.count) bytes")

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
            self.peerManager.addDiscoveredPeer(peer)

            // Auto-connect to discovered peers if not at max connections
            if self.connectionManager.getConnectedPeripherals().count < BleConstants.maxConnections &&
               !self.connectionManager.isConnected(peer.id),
               let peripheral = peer.peripheral {
                print("[\(self.tag)] Auto-connecting to discovered peer: \(peer.id)")
                self.connectionManager.connectToPeripheral(peripheral)
            }
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
                if let content = String(data: data, encoding: .utf8) {
                    print("[\(self.tag)] Received message from \(identifier): \(content)")

                    // Create message object
                    let peer = self.peerManager.getPeer(identifier)
                    let message = Message(
                        senderId: identifier,
                        senderNickname: peer?.nickname ?? "Unknown",
                        content: content,
                        type: .publicMessage,
                        status: .delivered
                    )

                    // Send message to Flutter via callback
                    print("[\(self.tag)] Message received: \(message.content)")
                    self.onMessageReceived?(message)
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

    /// Clean up resources
    func cleanup() {
        stop()
        bleScanner.cleanup()
        bleAdvertiser.cleanup()
        connectionManager.cleanup()
        peerManager.cleanup()

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

