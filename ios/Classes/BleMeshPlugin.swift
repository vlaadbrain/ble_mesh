import Flutter
import UIKit

public class BleMeshPlugin: NSObject, FlutterPlugin {
    private let tag = "BleMeshPlugin"

    // Method channel for communication between Flutter and native iOS
    private var methodChannel: FlutterMethodChannel?

    // Event channels for streaming data to Flutter
    private var messageEventChannel: FlutterEventChannel?
    private var peerConnectedEventChannel: FlutterEventChannel?
    private var peerDisconnectedEventChannel: FlutterEventChannel?
    private var meshEventChannel: FlutterEventChannel?
    private var discoveredPeersEventChannel: FlutterEventChannel?

    // Event stream handlers
    private var messageStreamHandler: EventStreamHandler?
    private var peerConnectedStreamHandler: EventStreamHandler?
    private var peerDisconnectedStreamHandler: EventStreamHandler?
    private var meshEventStreamHandler: EventStreamHandler?
    private var discoveredPeersStreamHandler: EventStreamHandler?

    // Bluetooth mesh service
    private var meshService: BluetoothMeshService?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BleMeshPlugin()

        // Setup method channel
        let methodChannel = FlutterMethodChannel(name: "ble_mesh", binaryMessenger: registrar.messenger())
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        // Setup event channels
        let messageEventChannel = FlutterEventChannel(name: "ble_mesh/messages", binaryMessenger: registrar.messenger())
        instance.messageStreamHandler = EventStreamHandler()
        messageEventChannel.setStreamHandler(instance.messageStreamHandler)
        instance.messageEventChannel = messageEventChannel

        let peerConnectedEventChannel = FlutterEventChannel(name: "ble_mesh/peer_connected", binaryMessenger: registrar.messenger())
        instance.peerConnectedStreamHandler = EventStreamHandler()
        peerConnectedEventChannel.setStreamHandler(instance.peerConnectedStreamHandler)
        instance.peerConnectedEventChannel = peerConnectedEventChannel

        let peerDisconnectedEventChannel = FlutterEventChannel(name: "ble_mesh/peer_disconnected", binaryMessenger: registrar.messenger())
        instance.peerDisconnectedStreamHandler = EventStreamHandler()
        peerDisconnectedEventChannel.setStreamHandler(instance.peerDisconnectedStreamHandler)
        instance.peerDisconnectedEventChannel = peerDisconnectedEventChannel

        let meshEventChannel = FlutterEventChannel(name: "ble_mesh/mesh_events", binaryMessenger: registrar.messenger())
        instance.meshEventStreamHandler = EventStreamHandler()
        meshEventChannel.setStreamHandler(instance.meshEventStreamHandler)
        instance.meshEventChannel = meshEventChannel

        let discoveredPeersEventChannel = FlutterEventChannel(name: "ble_mesh/discovered_peers", binaryMessenger: registrar.messenger())
        instance.discoveredPeersStreamHandler = EventStreamHandler()
        discoveredPeersEventChannel.setStreamHandler(instance.discoveredPeersStreamHandler)
        instance.discoveredPeersEventChannel = discoveredPeersEventChannel

        print("[BleMeshPlugin] Plugin registered")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "initialize":
            handleInitialize(call, result: result)

        case "startMesh":
            handleStartMesh(result: result)

        case "stopMesh":
            handleStopMesh(result: result)

        case "sendPublicMessage":
            handleSendPublicMessage(call, result: result)

        case "getConnectedPeers":
            handleGetConnectedPeers(result: result)

        case "startDiscovery":
            handleStartDiscovery(result: result)

        case "stopDiscovery":
            handleStopDiscovery(result: result)

        case "getDiscoveredPeers":
            handleGetDiscoveredPeers(result: result)

        case "connectToPeer":
            handleConnectToPeer(call, result: result)

        case "disconnectFromPeer":
            handleDisconnectFromPeer(call, result: result)

        case "getPeerConnectionState":
            handleGetPeerConnectionState(call, result: result)

        case "blockPeer":
            handleBlockPeer(call, result: result)

        case "unblockPeer":
            handleUnblockPeer(call, result: result)

        case "isPeerBlocked":
            handleIsPeerBlocked(call, result: result)

        case "getBlockedPeers":
            handleGetBlockedPeers(result: result)

        case "clearBlocklist":
            handleClearBlocklist(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInitialize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }

        let nickname = args["nickname"] as? String
        let enableEncryption = args["enableEncryption"] as? Bool ?? true
        let powerModeValue = args["powerMode"] as? Int ?? PowerMode.balanced.rawValue
        let powerMode = PowerMode.fromInt(powerModeValue)

        // Create mesh service if not exists
        if meshService == nil {
            meshService = BluetoothMeshService()
            setupMeshServiceCallbacks()
        }

        // Initialize mesh service
        meshService?.initialize(nickname: nickname, encryption: enableEncryption, mode: powerMode)

        print("[\(tag)] Initialized mesh service")
        result(nil)
    }

    private func handleStartMesh(result: @escaping FlutterResult) {
        if meshService == nil {
            meshService = BluetoothMeshService()
            setupMeshServiceCallbacks()
        }

        meshService?.start()
        print("[\(tag)] Started mesh service")
        result(nil)
    }

    private func handleStopMesh(result: @escaping FlutterResult) {
        meshService?.stop()
        print("[\(tag)] Stopped mesh service")
        result(nil)
    }

    private func handleSendPublicMessage(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let message = args["message"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Message is required", details: nil))
            return
        }

        meshService?.sendPublicMessage(content: message)
        print("[\(tag)] Sent public message: \(message)")
        result(nil)
    }

    private func handleGetConnectedPeers(result: @escaping FlutterResult) {
        let peers = meshService?.getConnectedPeers() ?? []
        let peerMaps = peers.map { $0.toMap() }
        result(peerMaps)
    }

    private func handleStartDiscovery(result: @escaping FlutterResult) {
        if meshService == nil {
            meshService = BluetoothMeshService()
            setupMeshServiceCallbacks()
        }

        meshService?.startDiscovery()
        print("[\(tag)] Started discovery")
        result(nil)
    }

    private func handleStopDiscovery(result: @escaping FlutterResult) {
        meshService?.stopDiscovery()
        print("[\(tag)] Stopped discovery")
        result(nil)
    }

    private func handleGetDiscoveredPeers(result: @escaping FlutterResult) {
        let peers = meshService?.getDiscoveredPeers() ?? []
        let peerMaps = peers.map { $0.toMap() }
        result(peerMaps)
    }

    private func handleConnectToPeer(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let senderId = args["senderId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "senderId is required", details: nil))
            return
        }

        guard let service = meshService else {
            result(FlutterError(code: "SERVICE_NOT_INITIALIZED", message: "Mesh service not initialized", details: nil))
            return
        }

        let success = service.connectToPeer(senderId: senderId)
        result(success)
    }

    private func handleDisconnectFromPeer(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let senderId = args["senderId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "senderId is required", details: nil))
            return
        }

        guard let service = meshService else {
            result(FlutterError(code: "SERVICE_NOT_INITIALIZED", message: "Mesh service not initialized", details: nil))
            return
        }

        let success = service.disconnectFromPeer(senderId: senderId)
        result(success)
    }

    private func handleGetPeerConnectionState(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let senderId = args["senderId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "senderId is required", details: nil))
            return
        }

        guard let service = meshService else {
            result(FlutterError(code: "SERVICE_NOT_INITIALIZED", message: "Mesh service not initialized", details: nil))
            return
        }

        let state = service.getPeerConnectionState(senderId: senderId)
        result(state)
    }

    private func handleBlockPeer(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let senderId = args["senderId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "senderId is required", details: nil))
            return
        }

        guard let service = meshService else {
            result(FlutterError(code: "SERVICE_NOT_INITIALIZED", message: "Mesh service not initialized", details: nil))
            return
        }

        let success = service.blockPeer(senderId)
        result(success)
    }

    private func handleUnblockPeer(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let senderId = args["senderId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "senderId is required", details: nil))
            return
        }

        guard let service = meshService else {
            result(FlutterError(code: "SERVICE_NOT_INITIALIZED", message: "Mesh service not initialized", details: nil))
            return
        }

        let success = service.unblockPeer(senderId)
        result(success)
    }

    private func handleIsPeerBlocked(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let senderId = args["senderId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "senderId is required", details: nil))
            return
        }

        guard let service = meshService else {
            result(FlutterError(code: "SERVICE_NOT_INITIALIZED", message: "Mesh service not initialized", details: nil))
            return
        }

        let isBlocked = service.isPeerBlocked(senderId)
        result(isBlocked)
    }

    private func handleGetBlockedPeers(result: @escaping FlutterResult) {
        guard let service = meshService else {
            result(FlutterError(code: "SERVICE_NOT_INITIALIZED", message: "Mesh service not initialized", details: nil))
            return
        }

        let blockedPeers = service.getBlockedPeers()
        result(blockedPeers)
    }

    private func handleClearBlocklist(result: @escaping FlutterResult) {
        guard let service = meshService else {
            result(FlutterError(code: "SERVICE_NOT_INITIALIZED", message: "Mesh service not initialized", details: nil))
            return
        }

        service.clearBlocklist()
        result(nil)
    }

    private func setupMeshServiceCallbacks() {
        meshService?.onPeerDiscovered = { [weak self] peer in
            // Send discovered peer to stream
            self?.discoveredPeersStreamHandler?.sendEvent(peer.toMap())
        }

        meshService?.onPeerConnected = { [weak self] peer in
            self?.peerConnectedStreamHandler?.sendEvent(peer.toMap())
        }

        meshService?.onPeerDisconnected = { [weak self] peer in
            self?.peerDisconnectedStreamHandler?.sendEvent(peer.toMap())
        }

        meshService?.onMeshEvent = { [weak self] event in
            self?.meshEventStreamHandler?.sendEvent(event.toMap())
        }

        meshService?.onMessageReceived = { [weak self] message in
            self?.messageStreamHandler?.sendEvent(message.toMap())
        }
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        methodChannel?.setMethodCallHandler(nil)
        messageEventChannel?.setStreamHandler(nil)
        peerConnectedEventChannel?.setStreamHandler(nil)
        peerDisconnectedEventChannel?.setStreamHandler(nil)
        meshEventChannel?.setStreamHandler(nil)

        meshService?.cleanup()
        meshService = nil

        print("[\(tag)] Plugin detached from engine")
    }
}

/// Event stream handler for sending events to Flutter
/// Ensures all events are sent on the main thread
class EventStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    func sendEvent(_ event: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }

    func sendError(code: String, message: String?, details: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(FlutterError(code: code, message: message, details: details))
        }
    }
}
