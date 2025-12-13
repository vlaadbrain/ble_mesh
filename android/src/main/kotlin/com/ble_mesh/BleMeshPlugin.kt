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

    // Event stream handlers
    private var messageStreamHandler: EventStreamHandler? = null
    private var peerConnectedStreamHandler: EventStreamHandler? = null
    private var peerDisconnectedStreamHandler: EventStreamHandler? = null
    private var meshEventStreamHandler: EventStreamHandler? = null

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

    private fun setupMeshServiceCallbacks() {
        meshService?.onPeerDiscovered = { peer ->
            // Peer discovered events are sent through mesh events
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
