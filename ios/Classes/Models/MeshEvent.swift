import Foundation

/// Type of mesh event
enum MeshEventType: Int {
    case meshStarted = 0
    case meshStopped = 1
    case peerDiscovered = 2
    case peerConnected = 3
    case peerDisconnected = 4
    case messageReceived = 5
    case error = 6
}

/// Represents an event in the mesh network
struct MeshEvent {
    let type: MeshEventType
    let message: String?
    let data: [String: Any]?

    init(type: MeshEventType, message: String? = nil, data: [String: Any]? = nil) {
        self.type = type
        self.message = message
        self.data = data
    }

    /// Convert to a dictionary for sending to Flutter
    func toMap() -> [String: Any?] {
        return [
            "type": type.rawValue,
            "message": message,
            "data": data
        ]
    }
}

