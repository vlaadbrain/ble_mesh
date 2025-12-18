import Foundation

/// Manages persistent device identity for BLE mesh networking
///
/// Generates and stores a stable UUID-based device identifier that persists
/// across app restarts. This replaces the unreliable MAC address-based
/// identification system.
///
/// Device ID Format:
/// - Full ID: UUID v4 (128-bit), e.g., "550e8400-e29b-41d4-a716-446655440000"
/// - Compact ID: First 6 bytes (48-bit), e.g., [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
/// - String format: "55:0E:84:00:E2:9B" (for display/logging)
class DeviceIdManager {
    private let userDefaults = UserDefaults.standard
    private let deviceIdKey = "ble_mesh_device_id"
    
    /// Get or create the device UUID
    ///
    /// On first call, generates a new UUID v4 and stores it persistently.
    /// Subsequent calls return the stored UUID.
    ///
    /// - Returns: UUID string in format "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    func getOrCreateDeviceId() -> String {
        if let existing = userDefaults.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        
        // Generate new UUID v4
        let newId = UUID().uuidString.lowercased()
        userDefaults.set(newId, forKey: deviceIdKey)
        return newId
    }
    
    /// Get the compact device ID (first 6 bytes of UUID)
    ///
    /// This is used in the MessageHeader senderId field for efficient
    /// binary serialization.
    ///
    /// - Returns: 6-byte Data
    func getCompactId() -> Data {
        let uuid = getOrCreateDeviceId()
        return DeviceIdManager.compactIdFromUuid(uuid)
    }
    
    /// Get the compact device ID as a formatted string
    ///
    /// - Returns: String in format "XX:XX:XX:XX:XX:XX" (e.g., "55:0E:84:00:E2:9B")
    func getCompactIdString() -> String {
        let data = getCompactId()
        return DeviceIdManager.compactIdToString(data)
    }
    
    /// Reset the device ID (for testing or user-initiated reset)
    ///
    /// Deletes the stored UUID. Next call to getOrCreateDeviceId() will
    /// generate a new UUID.
    func resetDeviceId() {
        userDefaults.removeObject(forKey: deviceIdKey)
    }
    
    /// Check if a device ID exists
    func hasDeviceId() -> Bool {
        if let existing = userDefaults.string(forKey: deviceIdKey), !existing.isEmpty {
            return true
        }
        return false
    }
    
    // MARK: - Static Utility Methods
    
    /// Convert UUID string to compact 6-byte representation
    ///
    /// Takes the first 12 hex characters (after removing hyphens) and converts
    /// them to a 6-byte array.
    ///
    /// Example:
    /// - Input: "550e8400-e29b-41d4-a716-446655440000"
    /// - Output: [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
    static func compactIdFromUuid(_ uuid: String) -> Data {
        // Remove hyphens and take first 12 hex chars (6 bytes)
        let hex = uuid.replacingOccurrences(of: "-", with: "")
        guard hex.count >= 12 else {
            fatalError("Invalid UUID format: \(uuid)")
        }
        
        let compactHex = String(hex.prefix(12))
        var data = Data()
        
        for i in stride(from: 0, to: 12, by: 2) {
            let start = compactHex.index(compactHex.startIndex, offsetBy: i)
            let end = compactHex.index(start, offsetBy: 2)
            let byteString = String(compactHex[start..<end])
            
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            } else {
                fatalError("Invalid hex in UUID: \(uuid)")
            }
        }
        
        return data
    }
    
    /// Convert compact ID bytes to string format
    ///
    /// Example:
    /// - Input: [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
    /// - Output: "55:0E:84:00:E2:9B"
    static func compactIdToString(_ data: Data) -> String {
        guard data.count == 6 else {
            fatalError("Compact ID must be exactly 6 bytes, got \(data.count)")
        }
        
        return data.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
    
    /// Convert compact ID string to bytes
    ///
    /// Example:
    /// - Input: "55:0E:84:00:E2:9B"
    /// - Output: [0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b]
    static func compactIdStringToData(_ compactId: String) -> Data {
        let parts = compactId.split(separator: ":").map { String($0) }
        guard parts.count == 6 else {
            fatalError("Invalid compact ID format: \(compactId) (expected XX:XX:XX:XX:XX:XX)")
        }
        
        var data = Data()
        for part in parts {
            if let byte = UInt8(part, radix: 16) {
                data.append(byte)
            } else {
                fatalError("Invalid hex in compact ID: \(compactId)")
            }
        }
        
        return data
    }
}

