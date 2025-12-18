package com.ble_mesh

import android.bluetooth.BluetoothGatt
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.ble_mesh.models.MeshEvent
import com.ble_mesh.models.MeshEventType
import com.ble_mesh.models.MessageHeader
import com.ble_mesh.models.Peer
import com.ble_mesh.models.PowerMode
import java.util.UUID

/**
 * Main coordinator for Bluetooth mesh networking
 * Manages scanning, advertising, and peer connections
 */
class BluetoothMeshService(private val context: Context) {
    private val tag = "BluetoothMeshService"

    // Bluetooth adapter
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager
    private val bluetoothAdapter = bluetoothManager.adapter

    // Components
    private val bleScanner = BleScanner(context)
    private val bleAdvertiser = BleAdvertiser(context)
    private val bleGattServer = BleGattServer(context)
    private val peerManager = PeerManager()
    private val connectionManager = BleConnectionManager(context)
    private val gattServiceManager = GattServiceManager()

    // Phase 2: Message deduplication cache
    private val messageCache = MessageCache(maxSize = 1000, expirationTimeMs = 5 * 60 * 1000) // 5 minutes

    // State
    private var isRunning = false
    private var deviceNickname: String = "BleMesh_${System.currentTimeMillis() % 10000}"
    private var powerMode: PowerMode = PowerMode.BALANCED
    private var enableEncryption: Boolean = true

    // Handler for periodic tasks
    private val handler = Handler(Looper.getMainLooper())

    // Callbacks
    var onPeerDiscovered: ((Peer) -> Unit)? = null
    var onPeerConnected: ((Peer) -> Unit)? = null
    var onPeerDisconnected: ((Peer) -> Unit)? = null
    var onMeshEvent: ((MeshEvent) -> Unit)? = null
    var onMessageReceived: ((com.ble_mesh.models.Message) -> Unit)? = null

    init {
        setupCallbacks()
    }

    /**
     * Initialize the mesh service
     */
    fun initialize(nickname: String?, encryption: Boolean, mode: PowerMode) {
        deviceNickname = nickname ?: deviceNickname
        enableEncryption = encryption
        powerMode = mode

        Log.d(tag, "Initialized with nickname: $deviceNickname, encryption: $enableEncryption, mode: $powerMode")
    }

    /**
     * Start the mesh network (scanning and advertising)
     */
    fun start() {
        if (isRunning) {
            Log.d(tag, "Mesh service already running")
            return
        }

        Log.d(tag, "Starting mesh service")

        // Start GATT server
        val gattStarted = bleGattServer.start()
        if (!gattStarted) {
            Log.e(tag, "Failed to start GATT server")
            onMeshEvent?.invoke(
                MeshEvent(
                    type = MeshEventType.ERROR,
                    message = "Failed to start GATT server",
                    data = mapOf("error" to "gatt_server_failed")
                )
            )
            return
        }

        // Start advertising
        bleAdvertiser.startAdvertising(deviceNickname)

        // Start scanning
        bleScanner.startScanning()

        isRunning = true

        // Schedule periodic tasks
        schedulePeriodicTasks()

        // Notify mesh started
        onMeshEvent?.invoke(
            MeshEvent(
                type = MeshEventType.MESH_STARTED,
                message = "Mesh network started"
            )
        )
    }

    /**
     * Stop the mesh network
     */
    fun stop() {
        if (!isRunning) {
            Log.d(tag, "Mesh service not running")
            return
        }

        Log.d(tag, "Stopping mesh service")

        // Stop scanning and advertising
        bleScanner.stopScanning()
        bleAdvertiser.stopAdvertising()

        // Stop GATT server
        bleGattServer.stop()

        // Cancel periodic tasks
        handler.removeCallbacksAndMessages(null)

        isRunning = false

        // Notify mesh stopped
        onMeshEvent?.invoke(
            MeshEvent(
                type = MeshEventType.MESH_STOPPED,
                message = "Mesh network stopped"
            )
        )
    }

    /**
     * Get list of connected peers
     */
    fun getConnectedPeers(): List<Peer> {
        return peerManager.getConnectedPeers()
    }

    /**
     * Get list of discovered peers
     */
    fun getDiscoveredPeers(): List<Peer> {
        return peerManager.getDiscoveredPeers()
    }

    /**
     * Check if mesh is running
     */
    fun isRunning(): Boolean = isRunning

    /**
     * Send a public message to all connected peers
     */
    fun sendPublicMessage(content: String) {
        if (!isRunning) {
            Log.w(tag, "Cannot send message: mesh service not running")
            return
        }

        val connectedDevices = connectionManager.getConnectedDevices()
        if (connectedDevices.isEmpty()) {
            Log.w(tag, "No connected peers to send message to")
            return
        }

        Log.d(tag, "Sending public message to ${connectedDevices.size} peers: $content")

        // Phase 2: Create message object
        val senderId = bluetoothAdapter.address ?: "00:00:00:00:00:00"
        val message = com.ble_mesh.models.Message(
            senderId = senderId,
            senderNickname = deviceNickname,
            content = content,
            type = com.ble_mesh.models.MessageType.PUBLIC,
            status = com.ble_mesh.models.DeliveryStatus.SENT,
            ttl = 7,  // Default TTL
            hopCount = 0,
            messageId = MessageHeader.generateMessageId(),
            isForwarded = false
        )

        // Serialize message (header + payload)
        val messageData = message.toByteArray()

        Log.d(tag, "Created message: senderId=${message.senderId}, messageId=${message.messageId}, ttl=${message.ttl}, size=${messageData.size} bytes")

        // Add to cache to prevent processing if we receive it back (loop prevention)
        messageCache.addMessage(message.senderId, message.messageId)
        Log.d(tag, "Added own message to cache for loop prevention")

        // Send to all connected peers
        connectedDevices.forEach { address ->
            val gatt = connectionManager.getGatt(address)
            if (gatt != null) {
                val msgCharacteristic = gattServiceManager.findMsgCharacteristic(gatt)
                if (msgCharacteristic != null) {
                    gattServiceManager.writeCharacteristic(gatt, msgCharacteristic, messageData)
                    Log.d(tag, "Sent message to peer: $address")
                } else {
                    Log.w(tag, "MSG characteristic not found for peer: $address")
                }
            }
        }
    }

    /**
     * Setup callbacks for scanner, advertiser, peer manager, and connection manager
     */
    private fun setupCallbacks() {
        // Scanner callbacks
        bleScanner.onDeviceDiscovered = { peer ->
            peerManager.addDiscoveredPeer(peer)

            // Auto-connect to discovered peers if not at max connections
            if (connectionManager.getConnectedDevices().size < BleConstants.MAX_CONNECTIONS &&
                !connectionManager.isConnected(peer.id)) {
                peer.device?.let { device ->
                    Log.d(tag, "Auto-connecting to discovered peer: ${peer.id}")
                    connectionManager.connectToDevice(device)
                }
            }
        }

        bleScanner.onScanError = { errorCode, message ->
            Log.e(tag, "Scan error: $message (code: $errorCode)")
            onMeshEvent?.invoke(
                MeshEvent(
                    type = MeshEventType.ERROR,
                    message = "Scan error: $message",
                    data = mapOf("errorCode" to errorCode)
                )
            )
        }

        // Advertiser callbacks
        bleAdvertiser.onAdvertisingStarted = {
            Log.d(tag, "Advertising started successfully")
        }

        bleAdvertiser.onAdvertisingFailed = { errorCode, message ->
            Log.e(tag, "Advertising error: $message (code: $errorCode)")
            onMeshEvent?.invoke(
                MeshEvent(
                    type = MeshEventType.ERROR,
                    message = "Advertising error: $message",
                    data = mapOf("errorCode" to errorCode)
                )
            )
        }

        // GATT Server callbacks
        bleGattServer.onCharacteristicWriteRequest = { device, data ->
            Log.d(tag, "GATT server received write from ${device.address}, size: ${data.size} bytes")

            // Phase 2: Deserialize message with header
            val peer = peerManager.getPeer(device.address)
            val message = com.ble_mesh.models.Message.fromByteArray(data, peer?.nickname ?: "Unknown")

            if (message != null) {
                Log.d(tag, "Received message: senderId=${message.senderId}, messageId=${message.messageId}, ttl=${message.ttl}, hopCount=${message.hopCount}, content=${message.content}")

                // Phase 2: Check for duplicate (deduplication) using composite key
                if (!messageCache.hasMessage(message.senderId, message.messageId)) {
                    // Add to cache
                    messageCache.addMessage(message.senderId, message.messageId)

                    // Send message to Flutter via callback
                    Log.d(tag, "Forwarding message to Flutter: ${message.content}")
                    onMessageReceived?.invoke(message)

                    // Phase 2: Forward message if TTL > 1
                    if (message.ttl > 1) {
                        Log.d(tag, "Message can be forwarded (TTL=${message.ttl}), forwarding to other peers")
                        forwardMessage(message, device.address)
                    } else {
                        Log.d(tag, "Message TTL exhausted (TTL=${message.ttl}), not forwarding")
                    }
                } else {
                    Log.d(tag, "Duplicate message detected, dropping: id=${message.messageId}")
                }
            } else {
                Log.w(tag, "Failed to parse message from ${device.address}")
            }
        }

        bleGattServer.onDeviceConnected = { device ->
            Log.d(tag, "Device connected to GATT server: ${device.address}")
            peerManager.markPeerConnected(device.address)
        }

        bleGattServer.onDeviceDisconnected = { device ->
            Log.d(tag, "Device disconnected from GATT server: ${device.address}")
            peerManager.markPeerDisconnected(device.address)
        }

        // Peer manager callbacks
        peerManager.onPeerDiscovered = { peer ->
            Log.d(tag, "Peer discovered: ${peer.nickname} (${peer.id})")
            onPeerDiscovered?.invoke(peer)
            onMeshEvent?.invoke(
                MeshEvent(
                    type = MeshEventType.PEER_DISCOVERED,
                    message = "Peer discovered: ${peer.nickname}",
                    data = mapOf("peerId" to peer.id)
                )
            )
        }

        peerManager.onPeerConnected = { peer ->
            Log.d(tag, "Peer connected: ${peer.nickname} (${peer.id})")
            onPeerConnected?.invoke(peer)
        }

        peerManager.onPeerDisconnected = { peer ->
            Log.d(tag, "Peer disconnected: ${peer.nickname} (${peer.id})")
            onPeerDisconnected?.invoke(peer)
        }

        // Connection manager callbacks
        connectionManager.onDeviceConnected = { address, gatt ->
            Log.d(tag, "GATT connected to device: $address")
            peerManager.markPeerConnected(address)
        }

        connectionManager.onDeviceDisconnected = { address ->
            Log.d(tag, "GATT disconnected from device: $address")
            peerManager.markPeerDisconnected(address)
        }

        connectionManager.onServicesDiscovered = { address, gatt ->
            Log.d(tag, "Services discovered for device: $address")

            // Setup notifications for MSG characteristic
            val msgCharacteristic = gattServiceManager.findMsgCharacteristic(gatt)
            if (msgCharacteristic != null) {
                if (gattServiceManager.supportsNotifications(msgCharacteristic)) {
                    gattServiceManager.setupNotifications(gatt, msgCharacteristic)
                    Log.d(tag, "Setup notifications for MSG characteristic")
                }
            } else {
                Log.w(tag, "MSG characteristic not found for device: $address")
            }

            // Request larger MTU for better throughput
            gattServiceManager.requestMtu(gatt)
        }

        connectionManager.onCharacteristicChanged = { address, uuid, data ->
            Log.d(tag, "Characteristic changed: $uuid, size: ${data.size}")

            // Handle received message
            if (uuid == BleConstants.MSG_CHARACTERISTIC_UUID) {
                // Phase 2: Deserialize message with header
                val peer = peerManager.getPeer(address)
                val message = com.ble_mesh.models.Message.fromByteArray(data, peer?.nickname ?: "Unknown")

                if (message != null) {
                    Log.d(tag, "Received message: senderId=${message.senderId}, messageId=${message.messageId}, ttl=${message.ttl}, hopCount=${message.hopCount}, content=${message.content}")

                    // Phase 2: Check for duplicate (deduplication) using composite key
                    if (!messageCache.hasMessage(message.senderId, message.messageId)) {
                        // Add to cache
                        messageCache.addMessage(message.senderId, message.messageId)

                        // Send message to Flutter via callback
                        Log.d(tag, "Forwarding message to Flutter: ${message.content}")
                        onMessageReceived?.invoke(message)

                        // Phase 2: Forward message if TTL > 1
                        if (message.ttl > 1) {
                            Log.d(tag, "Message can be forwarded (TTL=${message.ttl}), forwarding to other peers")
                            forwardMessage(message, address)
                        } else {
                            Log.d(tag, "Message TTL exhausted (TTL=${message.ttl}), not forwarding")
                        }
                    } else {
                        Log.d(tag, "Duplicate message detected, dropping: id=${message.messageId}")
                    }
                } else {
                    Log.w(tag, "Failed to parse message from $address")
                }
            }
        }

        connectionManager.onConnectionError = { address, error ->
            Log.e(tag, "Connection error for device $address: $error")
            onMeshEvent?.invoke(
                MeshEvent(
                    type = MeshEventType.ERROR,
                    message = "Connection error: $error",
                    data = mapOf("peerId" to address)
                )
            )
        }
    }

    /**
     * Schedule periodic tasks (scanning, cleanup, etc.)
     */
    private fun schedulePeriodicTasks() {
        // Get scan interval based on power mode
        val scanInterval = when (powerMode) {
            PowerMode.PERFORMANCE -> BleConstants.SCAN_INTERVAL_BALANCED_MS
            PowerMode.BALANCED -> BleConstants.SCAN_INTERVAL_BALANCED_MS
            PowerMode.POWER_SAVER -> BleConstants.SCAN_INTERVAL_POWER_SAVER_MS
            PowerMode.ULTRA_LOW_POWER -> BleConstants.SCAN_INTERVAL_POWER_SAVER_MS * 2
        }

        // Schedule periodic scanning
        handler.postDelayed(object : Runnable {
            override fun run() {
                if (isRunning && !bleScanner.isScanning()) {
                    bleScanner.startScanning()
                }
                handler.postDelayed(this, scanInterval)
            }
        }, scanInterval)

        // Schedule periodic cleanup of stale peers
        handler.postDelayed(object : Runnable {
            override fun run() {
                if (isRunning) {
                    peerManager.removeStalePeers()
                }
                handler.postDelayed(this, 30000L) // Every 30 seconds
            }
        }, 30000L)
    }

    /**
     * Forward a message to all connected peers except the sender
     * Phase 2: Multi-hop routing implementation
     *
     * @param message Original message to forward
     * @param senderAddress Address of the peer who sent us this message (don't send back to them)
     */
    private fun forwardMessage(message: com.ble_mesh.models.Message, senderAddress: String) {
        // Create a new message with decremented TTL and incremented hop count
        val forwardedMessage = com.ble_mesh.models.Message(
            id = message.id,
            senderId = message.senderId,  // Keep original sender
            senderNickname = message.senderNickname,
            content = message.content,
            type = message.type,
            timestamp = message.timestamp,
            channel = message.channel,
            isEncrypted = message.isEncrypted,
            status = com.ble_mesh.models.DeliveryStatus.SENT,
            ttl = message.ttl - 1,  // Decrement TTL
            hopCount = message.hopCount + 1,  // Increment hop count
            messageId = message.messageId,  // Keep same message ID
            isForwarded = true
        )

        // Serialize message
        val messageData = forwardedMessage.toByteArray()

        Log.d(tag, "Forwarding message id=${forwardedMessage.messageId}, ttl=${forwardedMessage.ttl}, hopCount=${forwardedMessage.hopCount}")

        // Forward to all connected peers except the sender
        val connectedDevices = connectionManager.getConnectedDevices()
        var forwardCount = 0

        connectedDevices.forEach { address ->
            // Skip the sender
            if (address == senderAddress) {
                Log.d(tag, "Skipping forward to sender: $address")
                return@forEach
            }

            val gatt = connectionManager.getGatt(address)
            if (gatt != null) {
                val msgCharacteristic = gattServiceManager.findMsgCharacteristic(gatt)
                if (msgCharacteristic != null) {
                    gattServiceManager.writeCharacteristic(gatt, msgCharacteristic, messageData)
                    forwardCount++
                    Log.d(tag, "Forwarded message to peer: $address")
                } else {
                    Log.w(tag, "MSG characteristic not found for peer: $address")
                }
            }
        }

        Log.d(tag, "Message forwarded to $forwardCount peer(s)")
    }

    /**
     * Clean up resources
     */
    fun cleanup() {
        stop()
        bleScanner.cleanup()
        bleAdvertiser.cleanup()
        bleGattServer.cleanup()
        connectionManager.cleanup()
        peerManager.cleanup()
        handler.removeCallbacksAndMessages(null)

        onPeerDiscovered = null
        onPeerConnected = null
        onPeerDisconnected = null
        onMeshEvent = null
    }
}

