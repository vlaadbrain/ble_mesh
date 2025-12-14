# ble_mesh Flutter Plugin - Project Prompt Template

## Project Overview

**ble_mesh** is a Flutter plugin that provides Bluetooth Low Energy (BLE) mesh networking capabilities for Android and iOS platforms. This plugin enables decentralized, peer-to-peer communication over Bluetooth mesh networks without requiring internet connectivity.

The plugin is inspired by and aims to provide similar functionality to:
- **Android**: [bitchat-android](https://github.com/permissionlesstech/bitchat-android) - Kotlin-based BLE mesh implementation
- **iOS**: [bitchat](https://github.com/permissionlesstech/bitchat) - Swift-based BLE mesh with Noise Protocol

## Core Purpose

Enable Flutter applications to:
1. Create and participate in Bluetooth LE mesh networks
2. Send and receive messages across multi-hop mesh topologies
3. Provide end-to-end encrypted private messaging
4. Support channel-based group communication
5. Operate completely offline without internet or central servers
6. Automatically discover and connect to nearby peers
7. Implement store-and-forward message delivery

## Architecture

### Plugin Structure

```
ble_mesh/
├── lib/                          # Dart API (Flutter interface)
│   ├── ble_mesh.dart            # Main plugin class
│   ├── ble_mesh_platform_interface.dart  # Platform interface
│   └── ble_mesh_method_channel.dart     # Method channel implementation
├── android/                      # Android platform implementation
│   └── src/main/kotlin/com/ble_mesh/
│       └── BleMeshPlugin.kt     # Android plugin entry point
├── ios/                         # iOS platform implementation
│   └── Classes/
│       └── BleMeshPlugin.swift  # iOS plugin entry point
├── example/                     # Example Flutter app
└── test/                        # Unit tests
```

### Three-Layer Architecture

1. **Dart Layer (Flutter)**
   - Public API exposed to Flutter apps
   - Method channel communication
   - Dart models and types
   - Stream-based event handling

2. **Platform Layer (Android/iOS)**
   - Native BLE mesh implementation
   - Platform-specific Bluetooth APIs
   - Method channel handlers
   - Event streaming to Flutter

3. **Mesh Network Layer**
   - Peer discovery and management
   - Message routing and relay
   - Encryption and authentication
   - Store-and-forward delivery

## Key Features

### Bluetooth Mesh Networking

- **Automatic Peer Discovery**: Scan and connect to nearby BLE mesh nodes
- **Multi-Hop Message Relay**: Messages route through intermediate peers (max 7 hops)
- **Dual Role Operation**: Each device acts as both central and peripheral
- **Store-and-Forward**: Messages cached for offline peers and delivered on reconnection
- **Message Deduplication**: Bloom filters prevent message loops and duplicates
- **Adaptive Scanning**: Battery-optimized duty cycling based on power state

### Encryption & Security

- **Private Messages**: End-to-end encryption using modern cryptographic protocols
  - Android: X25519 key exchange + AES-256-GCM
  - iOS: Noise Protocol Framework with forward secrecy
- **Channel Encryption**: Password-protected channels with Argon2id key derivation
- **Digital Signatures**: Ed25519 signatures for message authenticity
- **Ephemeral Keys**: Fresh key pairs generated each session
- **No Persistent Identifiers**: Privacy-first design with no phone numbers or accounts

### Communication Modes

1. **Public Mesh Chat**: Broadcast messages to all nearby peers
2. **Private Messages**: Encrypted direct messages to specific peers
3. **Channel-Based Groups**: Topic-based group messaging (e.g., `#general`, `#tech`)
4. **Password-Protected Channels**: Secure group conversations

### Message Management

- **Message Compression**: LZ4 compression for messages >100 bytes (30-70% bandwidth savings)
- **Message Fragmentation**: Automatic splitting of large messages for BLE packet size constraints
- **TTL-Based Routing**: Time-to-live prevents infinite message propagation
- **Message Acknowledgments**: Optional delivery confirmation
- **Message History**: Optional channel-wide message retention

### Battery Optimization

- **Adaptive Power Modes**:
  - Performance: Full features (charging or >60% battery)
  - Balanced: Default operation (30-60% battery)
  - Power Saver: Reduced scanning (<30% battery)
  - Ultra-Low Power: Emergency mode (<10% battery)
- **Background Efficiency**: Automatic power saving when app backgrounded
- **Configurable Scan Intervals**: Duty cycle adapts to battery state

## Platform-Specific Implementations

### Android Implementation

**Technology Stack:**
- Kotlin/Java
- Android BLE APIs (BluetoothLeScanner, BluetoothGatt)
- BouncyCastle for cryptography
- Kotlin Coroutines for async operations
- Nordic BLE Library (optional)

**Key Components:**
- `BluetoothMeshService`: Core BLE mesh networking service
- `EncryptionService`: Cryptographic operations
- `BinaryProtocol`: Packet encoding/decoding
- `PeerManager`: Connection and peer lifecycle management
- `MessageRouter`: Multi-hop message routing
- `StorageManager`: Message persistence and caching

**Android-Specific Features:**
- Foreground service for background operation
- Location permissions handling (required for BLE scanning)
- Battery optimization exemptions
- Notification channels for persistent service

### iOS Implementation

**Technology Stack:**
- Swift
- CoreBluetooth framework
- CryptoKit/Noise Protocol Framework
- Swift Concurrency (async/await)

**Key Components:**
- `BluetoothMeshManager`: Core BLE mesh networking
- `NoiseProtocolHandler`: Noise Protocol encryption
- `MessageRouter`: Multi-hop routing logic
- `PeerManager`: Connection management
- `StorageManager`: Persistent message storage

**iOS-Specific Features:**
- Background Bluetooth modes
- State restoration for background operation
- Privacy-preserving Bluetooth permissions
- Integration with iOS Keychain for secure storage

## Binary Protocol Specification

### Packet Structure

```
[Header (13 bytes)] [Payload (variable)]

Header:
- Version (1 byte): Protocol version
- Type (1 byte): Message type
- TTL (1 byte): Time-to-live (hops remaining)
- Message ID (8 bytes): Unique message identifier
- Payload Length (2 bytes): Length of payload

Message Types:
- 0x01: Public message
- 0x02: Private message
- 0x03: Channel message
- 0x04: Peer announcement
- 0x05: Acknowledgment
- 0x06: Key exchange
- 0x07: Store-and-forward request
```

### Bluetooth LE Characteristics

```
Service UUID: [To be defined]
Characteristics:
- TX (Write): Send messages to peer
- RX (Notify): Receive messages from peer
- Control (Read/Write): Connection control and metadata
```

### Cross-Platform Compatibility

The binary protocol ensures 100% compatibility between:
- Android ↔ Android
- iOS ↔ iOS
- Android ↔ iOS

## Flutter API Design

### Main Plugin Class

```dart
class BleMesh {
  // Initialize the mesh network
  Future<void> initialize({
    String? nickname,
    bool enableEncryption = true,
    PowerMode powerMode = PowerMode.balanced,
  });

  // Start mesh networking
  Future<void> startMesh();

  // Stop mesh networking
  Future<void> stopMesh();

  // Send public message
  Future<void> sendPublicMessage(String message);

  // Send private message
  Future<void> sendPrivateMessage(String peerId, String message);

  // Join/create channel
  Future<void> joinChannel(String channel, {String? password});

  // Send channel message
  Future<void> sendChannelMessage(String channel, String message);

  // Leave channel
  Future<void> leaveChannel(String channel);

  // Get connected peers
  Future<List<Peer>> getConnectedPeers();

  // Get discovered channels
  Future<List<String>> getDiscoveredChannels();

  // Block/unblock peer
  Future<void> blockPeer(String peerId);
  Future<void> unblockPeer(String peerId);

  // Event streams
  Stream<Message> get messageStream;
  Stream<Peer> get peerConnectedStream;
  Stream<Peer> get peerDisconnectedStream;
  Stream<String> get channelDiscoveredStream;
  Stream<MeshEvent> get meshEventStream;
}
```

### Data Models

```dart
class Peer {
  final String id;
  final String nickname;
  final int rssi;
  final DateTime lastSeen;
  final bool isConnected;
  final int hopCount;
}

class Message {
  final String id;
  final String senderId;
  final String senderNickname;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final String? channel;
  final bool isEncrypted;
  final DeliveryStatus status;
}

enum MessageType {
  public,
  private,
  channel,
  system,
}

enum DeliveryStatus {
  pending,
  sent,
  delivered,
  failed,
}

enum PowerMode {
  performance,
  balanced,
  powerSaver,
  ultraLowPower,
}

class MeshEvent {
  final MeshEventType type;
  final String? message;
  final Map<String, dynamic>? data;
}

enum MeshEventType {
  meshStarted,
  meshStopped,
  peerDiscovered,
  messageReceived,
  error,
}
```

## Development Guidelines

### Code Organization

1. **Dart Layer**
   - Keep platform-agnostic logic in Dart
   - Use method channels for platform communication
   - Provide clean, well-documented public API
   - Use streams for event delivery

2. **Android Layer**
   - Follow Android architecture best practices
   - Use Kotlin coroutines for async operations
   - Implement proper lifecycle management
   - Handle permissions gracefully

3. **iOS Layer**
   - Follow Swift best practices
   - Use async/await for concurrent operations
   - Implement proper state restoration
   - Handle privacy permissions appropriately

### Testing Strategy

1. **Unit Tests**
   - Test Dart API logic
   - Test protocol encoding/decoding
   - Test encryption/decryption
   - Mock platform channels

2. **Integration Tests**
   - Test cross-platform communication
   - Test multi-hop message routing
   - Test store-and-forward delivery
   - Test battery optimization modes

3. **Platform Tests**
   - Android instrumentation tests
   - iOS XCTest tests
   - Test BLE connectivity
   - Test background operation

### Performance Considerations

1. **Memory Management**
   - Limit message cache size
   - Implement message TTL expiration
   - Clean up disconnected peer data
   - Optimize Bloom filter size

2. **Battery Optimization**
   - Adaptive scan intervals
   - Connection pooling
   - Batch message transmission
   - Background operation limits

3. **Network Efficiency**
   - Message compression
   - Packet aggregation
   - Duplicate prevention
   - Efficient routing algorithms

## Security Considerations

1. **Encryption**
   - Use established cryptographic libraries
   - Implement proper key exchange
   - Ensure forward secrecy
   - Regular security audits

2. **Privacy**
   - No persistent identifiers
   - Ephemeral session keys
   - Optional message retention
   - Cover traffic support

3. **Attack Prevention**
   - Rate limiting
   - Message size limits
   - TTL enforcement
   - Peer blocking mechanism

## Example Use Cases

1. **Emergency Communication**: Disaster scenarios without internet
2. **Protests & Gatherings**: Secure communication in crowds
3. **Remote Areas**: Communication without cellular coverage
4. **Privacy-Focused Chat**: No server, no tracking
5. **Local Community**: Neighborhood or event-based chat
6. **Offline Gaming**: Peer-to-peer game coordination
7. **IoT Mesh Networks**: Device-to-device communication

## Implementation Roadmap

### Phase 1: Core Functionality ✅ COMPLETE
- [x] Basic BLE scanning and advertising
  - ✅ Android: BleScanner.kt, BleAdvertiser.kt
  - ✅ iOS: BleScanner.swift, BleAdvertiser.swift
  - ✅ Integrated into BluetoothMeshService
- [x] Peer discovery and connection
  - ✅ PeerManager tracks discovered and connected peers
  - ✅ BleConnectionManager handles GATT connections
  - ✅ Auto-connect logic with max 7 connections
  - ✅ Device address validation and GATT cache clearing
- [x] Simple message transmission
  - ✅ sendPublicMessage() implemented
  - ✅ MSG_CHARACTERISTIC for bidirectional communication
  - ✅ BleGattServer receives messages (Android)
  - ✅ GATT server callbacks properly connected
  - ✅ Message flow verified end-to-end
- [x] Method channel setup
  - ✅ BleMeshPlugin.kt/swift with method handlers
  - ✅ MethodChannelBleMesh.dart implementation
  - ✅ Event channels for streams (messages, peers, events)
  - ✅ Thread-safe event delivery (UI thread marshaling)
- [x] Basic Flutter API
  - ✅ BleMesh class with public API
  - ✅ All core methods (initialize, start, stop, send, getPeers)
  - ✅ Event streams (messageStream, peerConnectedStream, etc.)
  - ✅ Data models (Peer, Message, MeshEvent, PowerMode)
  - ✅ Example app with chat, settings, permissions

### Phase 2: Mesh Networking 🚧 IN PROGRESS
- [ ] **Multi-hop message routing** ⬅️ CURRENT FOCUS
  - [ ] 1.1 Design routing architecture (2-3 hours)
  - [ ] 1.2 Implement message header with routing info (3-4 hours)
  - [ ] 1.3 Implement message forwarding logic (4-5 hours)
  - [ ] 1.4 Update data models (2-3 hours)
  - [ ] 1.5 Test multi-hop routing (4-6 hours)
- [ ] TTL-based forwarding (included in multi-hop routing)
- [ ] Message deduplication (included in multi-hop routing)
- [ ] Store-and-forward (6-8 hours)
- [ ] Binary protocol implementation (4-5 hours)

**See `PHASE_2_IMPLEMENTATION_PLAN.md` for detailed breakdown**

### Phase 3: Encryption & Security
- [ ] Key exchange implementation
- [ ] End-to-end encryption
- [ ] Channel password protection
- [ ] Digital signatures
- [ ] Secure storage

### Phase 4: Optimization
- [ ] Message compression
- [ ] Battery optimization
- [ ] Adaptive power modes
- [ ] Connection pooling
- [ ] Memory management

### Phase 5: Advanced Features
- [ ] Channel management
- [ ] Peer blocking
- [ ] Message acknowledgments
- [ ] File transfer support
- [ ] Cross-platform testing

### Phase 6: Polish & Release
- [ ] Comprehensive documentation
- [ ] Example applications
- [ ] Performance testing
- [ ] Security audit
- [ ] Pub.dev release

## References & Resources

### Bluetooth LE Mesh
- [Bluetooth Core Specification](https://www.bluetooth.com/specifications/specs/)
- [Android BLE Guide](https://developer.android.com/guide/topics/connectivity/bluetooth/ble-overview)
- [iOS CoreBluetooth](https://developer.apple.com/documentation/corebluetooth)

### Cryptography
- [Noise Protocol Framework](https://noiseprotocol.org/)
- [libsodium Documentation](https://doc.libsodium.org/)
- [BouncyCastle](https://www.bouncycastle.org/)

### Flutter Plugin Development
- [Flutter Plugin Development](https://docs.flutter.dev/packages-and-plugins/developing-packages)
- [Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
- [Method Channels](https://api.flutter.dev/flutter/services/MethodChannel-class.html)

### Reference Implementations
- [bitchat-android](https://github.com/permissionlesstech/bitchat-android) - Android reference
- [bitchat iOS](https://github.com/permissionlesstech/bitchat) - iOS reference

## Contributing

When contributing to this project:

1. **Follow Platform Conventions**
   - Dart: Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
   - Kotlin: Follow [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
   - Swift: Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

2. **Maintain Cross-Platform Compatibility**
   - Ensure protocol compatibility between platforms
   - Test on both Android and iOS
   - Document platform-specific behavior

3. **Write Tests**
   - Unit tests for new features
   - Integration tests for cross-platform features
   - Document test scenarios

4. **Documentation**
   - Update API documentation
   - Add code comments
   - Update README and examples

## License

This project follows the same licensing approach as the reference implementations:
- Android implementation: MIT License
- iOS implementation: Unlicense (Public Domain)

Choose the appropriate license for your use case.

## Project Status

**Current Status**: Phase 1 Complete ✅ - Production Ready

**Completed Phases:**
- ✅ **Phase 1: Core Functionality** - BLE scanning, advertising, peer discovery, message transmission, Flutter API (2025-12-13)
  - ✅ Android implementation complete with MSG_CHARACTERISTIC
  - ✅ iOS implementation complete with MSG_CHARACTERISTIC
  - ✅ Multi-device testing verified (Android ↔ Android, iOS ↔ iOS, Android ↔ iOS)

**Next Steps:**
- Begin Phase 2: Mesh Networking (multi-hop routing, TTL forwarding, deduplication)
- Implement Phase 3: Encryption & Security

**Key Achievements:**
- ✅ Full Android implementation with MSG_CHARACTERISTIC
- ✅ GATT server and client roles working
- ✅ Thread-safe event delivery
- ✅ Device address validation and GATT cache management
- ✅ Example app with permissions, chat, and settings
- ✅ Comprehensive documentation (9 technical docs)
- ✅ Package structure cleaned up (com.ble_mesh)

This is a Flutter plugin project that aims to bring Bluetooth LE mesh networking capabilities to Flutter applications, providing the same powerful features as the native bitchat implementations for both Android and iOS platforms.

---

**Last Updated**: 2025-12-13
**Plugin Version**: 0.1.0
**Flutter SDK**: >=3.3.0
**Dart SDK**: ^3.9.2

