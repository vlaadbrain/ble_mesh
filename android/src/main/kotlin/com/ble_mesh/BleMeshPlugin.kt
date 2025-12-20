package com.ble_mesh

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.ble_mesh.models.PowerMode
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** BleMeshPlugin */
class BleMeshPlugin : FlutterPlugin, MethodCallHandler {
    private val tag = "BleMeshPlugin"

    // Method channel for communication between Flutter and native Android
    private lateinit var methodChannel: MethodChannel

    // Event channels for streaming data to Flutter
    private lateinit var messageEventChannel: EventChannel
    private lateinit var peerConnectedEventChannel: EventChannel
    private lateinit var peerDisconnectedEventChannel: EventChannel
    private lateinit var meshEventChannel: EventChannel
    private lateinit var discoveredPeersEventChannel: EventChannel

    // Event stream handlers
    private var messageStreamHandler: EventStreamHandler? = null
    private var peerConnectedStreamHandler: EventStreamHandler? = null
    private var peerDisconnectedStreamHandler: EventStreamHandler? = null
    private var meshEventStreamHandler: EventStreamHandler? = null
    private var discoveredPeersStreamHandler: EventStreamHandler? = null

    // Bluetooth mesh service
    private var meshService: BluetoothMeshService? = null
    private var context: Context? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        // Setup method channel
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "ble_mesh")
        methodChannel.setMethodCallHandler(this)

        // Setup event channels
        messageEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "ble_mesh/messages")
        messageStreamHandler = EventStreamHandler()
        messageEventChannel.setStreamHandler(messageStreamHandler)

        peerConnectedEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "ble_mesh/peer_connected")
        peerConnectedStreamHandler = EventStreamHandler()
        peerConnectedEventChannel.setStreamHandler(peerConnectedStreamHandler)

        peerDisconnectedEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "ble_mesh/peer_disconnected")
        peerDisconnectedStreamHandler = EventStreamHandler()
        peerDisconnectedEventChannel.setStreamHandler(peerDisconnectedStreamHandler)

        meshEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "ble_mesh/mesh_events")
        meshEventStreamHandler = EventStreamHandler()
        meshEventChannel.setStreamHandler(meshEventStreamHandler)

        discoveredPeersEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "ble_mesh/discovered_peers")
        discoveredPeersStreamHandler = EventStreamHandler()
        discoveredPeersEventChannel.setStreamHandler(discoveredPeersStreamHandler)

        Log.d(tag, "BleMeshPlugin attached to engine")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "initialize" -> {
                handleInitialize(call, result)
            }
            "startMesh" -> {
                handleStartMesh(result)
            }
            "stopMesh" -> {
                handleStopMesh(result)
            }
            "sendPublicMessage" -> {
                handleSendPublicMessage(call, result)
            }
            "getConnectedPeers" -> {
                handleGetConnectedPeers(result)
            }
            "startDiscovery" -> {
                handleStartDiscovery(result)
            }
            "stopDiscovery" -> {
                handleStopDiscovery(result)
            }
            "getDiscoveredPeers" -> {
                handleGetDiscoveredPeers(result)
            }
            "connectToPeer" -> {
                handleConnectToPeer(call, result)
            }
            "disconnectFromPeer" -> {
                handleDisconnectFromPeer(call, result)
            }
            "getPeerConnectionState" -> {
                handleGetPeerConnectionState(call, result)
            }
            "blockPeer" -> {
                handleBlockPeer(call, result)
            }
            "unblockPeer" -> {
                handleUnblockPeer(call, result)
            }
            "isPeerBlocked" -> {
                handleIsPeerBlocked(call, result)
            }
            "getBlockedPeers" -> {
                handleGetBlockedPeers(result)
            }
            "clearBlocklist" -> {
                handleClearBlocklist(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleInitialize(call: MethodCall, result: Result) {
        try {
            val nickname = call.argument<String?>("nickname")
            val enableEncryption = call.argument<Boolean>("enableEncryption") ?: true
            val powerModeValue = call.argument<Int>("powerMode") ?: PowerMode.BALANCED.value
            val powerMode = PowerMode.fromInt(powerModeValue)

            // Create mesh service if not exists
            if (meshService == null && context != null) {
                meshService = BluetoothMeshService(context!!)
                setupMeshServiceCallbacks()
            }

            // Initialize mesh service
            meshService?.initialize(nickname, enableEncryption, powerMode)

            Log.d(tag, "Initialized mesh service")
            result.success(null)
        } catch (e: Exception) {
            Log.e(tag, "Error initializing mesh service", e)
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun handleStartMesh(result: Result) {
        try {
            if (meshService == null && context != null) {
                meshService = BluetoothMeshService(context!!)
                setupMeshServiceCallbacks()
            }

            meshService?.start()
            Log.d(tag, "Started mesh service")
            result.success(null)
        } catch (e: Exception) {
            Log.e(tag, "Error starting mesh service", e)
            result.error("START_ERROR", e.message, null)
        }
    }

    private fun handleStopMesh(result: Result) {
        try {
            meshService?.stop()
            Log.d(tag, "Stopped mesh service")
            result.success(null)
        } catch (e: Exception) {
            Log.e(tag, "Error stopping mesh service", e)
            result.error("STOP_ERROR", e.message, null)
        }
    }

    private fun handleSendPublicMessage(call: MethodCall, result: Result) {
        try {
            val message = call.argument<String>("message")
            if (message == null) {
                result.error("INVALID_ARGUMENT", "Message is required", null)
                return
            }

            meshService?.sendPublicMessage(message)
            Log.d(tag, "Sent public message: $message")
            result.success(null)
        } catch (e: Exception) {
            Log.e(tag, "Error sending message", e)
            result.error("SEND_ERROR", e.message, null)
        }
    }

    private fun handleGetConnectedPeers(result: Result) {
        try {
            val peers = meshService?.getConnectedPeers() ?: emptyList()
            val peerMaps = peers.map { it.toMap() }
            result.success(peerMaps)
        } catch (e: Exception) {
            Log.e(tag, "Error getting connected peers", e)
            result.error("GET_PEERS_ERROR", e.message, null)
        }
    }

    private fun handleStartDiscovery(result: Result) {
        try {
            if (meshService == null && context != null) {
                meshService = BluetoothMeshService(context!!)
                setupMeshServiceCallbacks()
            }

            meshService?.startDiscovery()
            Log.d(tag, "Started discovery")
            result.success(null)
        } catch (e: Exception) {
            Log.e(tag, "Error starting discovery", e)
            result.error("START_DISCOVERY_ERROR", e.message, null)
        }
    }

    private fun handleStopDiscovery(result: Result) {
        try {
            meshService?.stopDiscovery()
            Log.d(tag, "Stopped discovery")
            result.success(null)
        } catch (e: Exception) {
            Log.e(tag, "Error stopping discovery", e)
            result.error("STOP_DISCOVERY_ERROR", e.message, null)
        }
    }

    private fun handleGetDiscoveredPeers(result: Result) {
        try {
            val peers = meshService?.getDiscoveredPeers() ?: emptyList()
            val peerMaps = peers.map { it.toMap() }
            result.success(peerMaps)
        } catch (e: Exception) {
            Log.e(tag, "Error getting discovered peers", e)
            result.error("GET_DISCOVERED_PEERS_ERROR", e.message, null)
        }
    }

    private fun handleConnectToPeer(call: MethodCall, result: Result) {
        try {
            val senderId = call.argument<String>("senderId")
            if (senderId == null) {
                result.error("INVALID_ARGUMENT", "senderId is required", null)
                return
            }

            val success = meshService?.connectToPeer(senderId) ?: false
            result.success(success)
        } catch (e: Exception) {
            Log.e(tag, "Error connecting to peer", e)
            result.error("CONNECT_PEER_ERROR", e.message, null)
        }
    }

    private fun handleDisconnectFromPeer(call: MethodCall, result: Result) {
        try {
            val senderId = call.argument<String>("senderId")
            if (senderId == null) {
                result.error("INVALID_ARGUMENT", "senderId is required", null)
                return
            }

            val success = meshService?.disconnectFromPeer(senderId) ?: false
            result.success(success)
        } catch (e: Exception) {
            Log.e(tag, "Error disconnecting from peer", e)
            result.error("DISCONNECT_PEER_ERROR", e.message, null)
        }
    }

    private fun handleGetPeerConnectionState(call: MethodCall, result: Result) {
        try {
            val senderId = call.argument<String>("senderId")
            if (senderId == null) {
                result.error("INVALID_ARGUMENT", "senderId is required", null)
                return
            }

            val state = meshService?.getPeerConnectionState(senderId)
            result.success(state)
        } catch (e: Exception) {
            Log.e(tag, "Error getting peer connection state", e)
            result.error("GET_PEER_STATE_ERROR", e.message, null)
        }
    }

    private fun handleBlockPeer(call: MethodCall, result: Result) {
        try {
            val senderId = call.argument<String>("senderId")
            if (senderId == null) {
                result.error("INVALID_ARGUMENT", "senderId is required", null)
                return
            }

            val success = meshService?.blockPeer(senderId) ?: false
            result.success(success)
        } catch (e: Exception) {
            Log.e(tag, "Error blocking peer", e)
            result.error("BLOCK_PEER_ERROR", e.message, null)
        }
    }

    private fun handleUnblockPeer(call: MethodCall, result: Result) {
        try {
            val senderId = call.argument<String>("senderId")
            if (senderId == null) {
                result.error("INVALID_ARGUMENT", "senderId is required", null)
                return
            }

            val success = meshService?.unblockPeer(senderId) ?: false
            result.success(success)
        } catch (e: Exception) {
            Log.e(tag, "Error unblocking peer", e)
            result.error("UNBLOCK_PEER_ERROR", e.message, null)
        }
    }

    private fun handleIsPeerBlocked(call: MethodCall, result: Result) {
        try {
            val senderId = call.argument<String>("senderId")
            if (senderId == null) {
                result.error("INVALID_ARGUMENT", "senderId is required", null)
                return
            }

            val isBlocked = meshService?.isPeerBlocked(senderId) ?: false
            result.success(isBlocked)
        } catch (e: Exception) {
            Log.e(tag, "Error checking if peer is blocked", e)
            result.error("IS_PEER_BLOCKED_ERROR", e.message, null)
        }
    }

    private fun handleGetBlockedPeers(result: Result) {
        try {
            val blockedPeers = meshService?.getBlockedPeers() ?: emptyList()
            result.success(blockedPeers)
        } catch (e: Exception) {
            Log.e(tag, "Error getting blocked peers", e)
            result.error("GET_BLOCKED_PEERS_ERROR", e.message, null)
        }
    }

    private fun handleClearBlocklist(result: Result) {
        try {
            meshService?.clearBlocklist()
            result.success(null)
        } catch (e: Exception) {
            Log.e(tag, "Error clearing blocklist", e)
            result.error("CLEAR_BLOCKLIST_ERROR", e.message, null)
        }
    }

    private fun setupMeshServiceCallbacks() {
        meshService?.onPeerDiscovered = { peer ->
            // Send discovered peer to stream
            discoveredPeersStreamHandler?.sendEvent(peer.toMap())
        }

        meshService?.onPeerConnected = { peer ->
            peerConnectedStreamHandler?.sendEvent(peer.toMap())
        }

        meshService?.onPeerDisconnected = { peer ->
            peerDisconnectedStreamHandler?.sendEvent(peer.toMap())
        }

        meshService?.onMeshEvent = { event ->
            meshEventStreamHandler?.sendEvent(event.toMap())
        }

        meshService?.onMessageReceived = { message ->
            messageStreamHandler?.sendEvent(message.toMap())
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)

        messageEventChannel.setStreamHandler(null)
        peerConnectedEventChannel.setStreamHandler(null)
        peerDisconnectedEventChannel.setStreamHandler(null)
        meshEventChannel.setStreamHandler(null)

        meshService?.cleanup()
        meshService = null
        context = null

        Log.d(tag, "BleMeshPlugin detached from engine")
    }

    /**
     * Event stream handler for sending events to Flutter
     * Ensures all events are sent on the UI thread
     */
    private class EventStreamHandler : EventChannel.StreamHandler {
        private var eventSink: EventChannel.EventSink? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
        }

        fun sendEvent(event: Any) {
            mainHandler.post {
                eventSink?.success(event)
            }
        }

        fun sendError(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            mainHandler.post {
                eventSink?.error(errorCode, errorMessage, errorDetails)
            }
        }
    }
}
