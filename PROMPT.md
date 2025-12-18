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

## Design Patterns Applied

### Networking & Routing Patterns

1. **Flood Routing Pattern**
   - **Purpose**: Simple, reliable message propagation without routing tables
   - **Implementation**: Broadcast messages to all peers except sender
   - **Benefits**: Works well for small networks (<20 devices), no complex routing logic
   - **Trade-offs**: Higher bandwidth usage (acceptable for small networks)

2. **TTL-Based Forwarding Pattern**
   - **Purpose**: Prevent infinite message loops in mesh networks
   - **Implementation**: Decrement TTL on each hop, drop when TTL ≤ 0
   - **Default TTL**: 7 hops (configurable)
   - **Benefits**: Automatic loop prevention, controlled message propagation

3. **Message Deduplication Pattern (LRU Cache)**
   - **Purpose**: Prevent duplicate message processing and forwarding loops
   - **Implementation**: LRU cache with 1000 entries, 5-minute expiration
   - **Key**: Message ID (timestamp + random)
   - **Benefits**: Memory-efficient, automatic cleanup, prevents message storms

### Architectural Patterns

4. **Event-Driven Architecture (Observer Pattern)**
   - **Purpose**: Decouple message producers from consumers
   - **Implementation**: Event streams for messages, peer connections, mesh events
   - **Dart API**: `messageStream`, `peerConnectedStream`, `peerDisconnectedStream`, `meshEventStream`
   - **Benefits**: Reactive UI updates, loose coupling, scalable event handling

5. **Platform Channel Pattern**
   - **Purpose**: Bridge Flutter (Dart) with native platforms (Android/iOS)
   - **Implementation**: MethodChannel for bidirectional calls, EventChannel for streams
   - **Flow**: Dart ↔ MethodChannel ↔ Platform-specific handler ↔ Native code
   - **Benefits**: Platform-agnostic Dart API, native performance

6. **Dual Role Pattern (GATT Server/Client)**
   - **Purpose**: Enable bidirectional communication in peer-to-peer networks
   - **Implementation**: Each device acts as BOTH GATT server and client
   - **Server Role**: Advertises and provides MSG_CHARACTERISTIC for others to write
   - **Client Role**: Scans and connects to others' GATT servers
   - **Benefits**: True peer-to-peer, no client/server hierarchy, symmetric communication

### Object-Oriented Design Patterns

7. **Encapsulation Pattern**
   - **Purpose**: Hide implementation details, expose clean APIs
   - **Implementation**: Message class handles its own serialization/deserialization
   - **API**: `message.toByteArray()`, `Message.fromByteArray(data)`
   - **Benefits**: Single Responsibility Principle, testable, maintainable

8. **Factory Pattern**
   - **Purpose**: Centralize object creation logic
   - **Implementation**: `Message.fromByteArray()`, `MessageHeader.fromByteArray()`
   - **Benefits**: Consistent object creation, validation in one place

9. **Information Hiding Principle**
   - **Purpose**: Expose only necessary interfaces
   - **Implementation**: MessageHeader internals hidden, only public methods exposed
   - **Benefits**: Prevents misuse, allows internal refactoring without breaking API

### Concurrency & Threading Patterns

10. **Thread Safety Pattern (UI Thread Marshaling)**
    - **Purpose**: Ensure UI updates happen on correct thread
    - **Android**: `Handler(Looper.getMainLooper()).post { ... }`
    - **iOS**: `DispatchQueue.main.async { ... }`
    - **Problem Solved**: Fixed `RuntimeException: Methods marked with @UiThread must be executed on the main thread`
    - **Benefits**: Crash-free event delivery, reliable UI updates

11. **Async/Await Pattern**
    - **Purpose**: Non-blocking asynchronous operations
    - **Dart**: `Future<void>` for all async methods
    - **Kotlin**: Coroutines for BLE operations
    - **Swift**: async/await for CoreBluetooth
    - **Benefits**: Responsive UI, efficient resource usage

### Data Management Patterns

12. **Single Responsibility Principle**
    - **Separation of Concerns**: Each class has one clear purpose
      - `BleScanner`: Scanning only
      - `BleAdvertiser`: Advertising only
      - `BleConnectionManager`: Connection management only
      - `BluetoothMeshService`: Orchestration and coordination
    - **Benefits**: Easier testing, maintainable, clear responsibilities

13. **Cache Pattern (GATT Cache Management)**
    - **Purpose**: Clear stale GATT service cache on Android
    - **Implementation**: Reflection to call hidden `refresh()` method
    - **Problem Solved**: Fixed device address mismatch and stale characteristic issues
    - **Benefits**: Reliable service discovery, correct device-characteristic association

### Protocol & Serialization Patterns

14. **Binary Protocol Pattern**
    - **Purpose**: Efficient, cross-platform data serialization
    - **Implementation**: 20-byte fixed header + variable payload
    - **Byte Order**: Big-endian (network byte order)
    - **Benefits**: Compact, fast, platform-independent, BLE-friendly

15. **Version Negotiation Pattern**
    - **Purpose**: Support protocol evolution
    - **Implementation**: Version byte in message header
    - **Current Version**: 0x01
    - **Benefits**: Backward compatibility, graceful upgrades

### Testing Patterns

16. **Platform-Specific Testing Strategy**
    - **Dart Tests**: Business logic, data models, map serialization (62 tests)
    - **Native Tests**: Binary serialization for BLE (Android: 27, iOS: 30)
    - **Rationale**: Centralized test suite at Flutter layer, native tests only for BLE-specific logic
    - **Coverage**: ~95% for MessageHeader and Message classes
    - **Benefits**: Fast iteration, consistent behavior, efficient testing

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

### Packet Structure (MessageHeader)

**Current Implementation** (Phase 2 - Complete ✅):

```
[Header (20 bytes)] [Payload (variable)]

Header (Big-Endian):
- Version (1 byte): Protocol version (currently 0x01)
- Type (1 byte): Message type
- TTL (1 byte): Time-to-live (hops remaining, default: 7)
- Hop Count (1 byte): Number of hops taken
- Message ID (8 bytes): Unique identifier (timestamp 4 bytes + random 4 bytes)
- Sender ID (6 bytes): Bluetooth MAC address of original sender
- Payload Length (2 bytes): Length of payload (0-65535 bytes)

Message Types:
- 0x01: Public message
- 0x02: Private message
- 0x03: Channel message
- 0x04: Peer announcement
- 0x05: Acknowledgment
- 0x06: Key exchange
- 0x07: Store-and-forward request
```

**Implementation Status:**
- ✅ Android: `MessageHeader.kt` (199 lines) + tests (279 lines)
- ✅ iOS: `MessageHeader.swift` (275 lines) + tests (317 lines)
- ✅ Dart: `MessageHeader.dart` (268 lines) + tests (339 lines)
- ✅ Total: 1,677 lines of code, 42 tests (all passing)

**Key Methods:**
- Serialization: `toByteArray()` / `toData()` / `toBytes()`
- Deserialization: `fromByteArray()` / `fromData()` / `fromBytes()`
- Forwarding: `canForward()`, `prepareForForward()`
- Message ID: `generateMessageId()` (timestamp + random)

### Bluetooth LE Characteristics

**Current Implementation:**

```
Service UUID: 00001234-0000-1000-8000-00805f9b34fb
Characteristics:
- MSG_CHARACTERISTIC (00001235): Bidirectional message communication
  Properties: WRITE | WRITE_NO_RESPONSE | READ | NOTIFY
  Used for both sending and receiving messages

- CONTROL_CHARACTERISTIC (00001237): Connection control and metadata
  Properties: READ | WRITE
  Used for connection management
```

**Architecture:**
- Each device acts as BOTH GATT server (provides characteristics) AND client (discovers others)
- Enables true bidirectional communication
- Follows Nordic UART Service pattern

### Cross-Platform Compatibility

The binary protocol ensures 100% compatibility between:
- ✅ Android ↔ Android (Verified)
- ✅ iOS ↔ iOS (Verified)
- ✅ Android ↔ iOS (Verified)

**Binary Format:** Identical across all platforms (big-endian byte order)
**Test Coverage:** 119 tests passing (100% success rate)

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
  final DateTime? lastForwardTime; // Phase 2: Last message forward time
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
  // Phase 2: Routing fields
  final int ttl;              // Time-to-live (hops remaining)
  final int hopCount;         // Number of hops taken
  final String messageId;     // Unique routing identifier
  final bool isForwarded;     // Whether message was forwarded
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
  peerConnected,
  peerDisconnected,
  messageReceived,
  forwardingMetrics, // Phase 2: Forwarding metrics event
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

### Phase 2: Mesh Networking 🚧 IN PROGRESS (85% Complete)

**Completed Tasks:**
- [x] **Task 1.1: Design routing architecture** ✅ (2-3 hours)
  - ✅ Documented in `docs/ROUTING_ARCHITECTURE.md` (999 lines)
  - ✅ Flood routing strategy defined
  - ✅ Message header structure specified (20 bytes)
  - ✅ Forwarding algorithm designed
  - ✅ Deduplication strategy (LRU cache, 1000 entries, 5-min expiration)

- [x] **Task 1.2: Implement message header with routing info** ✅ (3-4 hours)
  - ✅ Android: `MessageHeader.kt` (199 lines) + tests (279 lines)
  - ✅ iOS: `MessageHeader.swift` (275 lines) + tests (317 lines)
  - ✅ Dart: `MessageHeader.dart` (268 lines) + tests (339 lines)
  - ✅ Total: 1,677 lines of code, 42 tests (all passing)
  - ✅ Cross-platform binary compatibility verified
  - ✅ Message class refactored to encapsulate MessageHeader
  - ✅ `sendPublicMessage` updated to use MessageHeader
  - ✅ Device ID redesign: UUID-based identification (replaces unreliable MAC addresses)
    - ✅ Dart: `DeviceIdManager.dart` (147 lines) + tests (18 tests)
    - ✅ Android: `DeviceIdManager.kt` (149 lines)
    - ✅ iOS: `DeviceIdManager.swift` (154 lines)
    - ✅ 6-byte compact ID format for MessageHeader (fits 20-byte protocol)
    - ✅ Privacy-friendly, stable, cross-platform compatible

**Completed Tasks:**
- [x] **Task 1.3: Implement message forwarding logic** ✅ (5 hours)
  - [x] 1.3.1: Add message cache for deduplication (Android/iOS) ✅
    - ✅ Android: `MessageCache.kt` (188 lines) with composite key (senderId, messageId)
    - ✅ iOS: `MessageCache.swift` (211 lines) with composite key (senderId, messageId)
    - ✅ LRU eviction (1000 entries), 5-minute expiration, thread-safe
  - [x] 1.3.2: Update message receiving to parse MessageHeader ✅
    - ✅ Android: Both GATT server write and characteristic changed handlers
    - ✅ iOS: Both central role and peripheral role reception paths
    - ✅ Full MessageHeader parsing with senderId, messageId, TTL, hopCount
  - [x] 1.3.3: Implement forwarding decision logic ✅
    - ✅ Composite key deduplication check before processing
    - ✅ TTL > 1 check before forwarding
    - ✅ Loop prevention (own messages cached before transmission)
  - [x] 1.3.4: Forward messages to peers ✅
    - ✅ Android: `forwardMessage()` method (Lines 465-512)
    - ✅ iOS: `forwardMessage()` method (Lines 407-454)
    - ✅ TTL decrement, hop count increment, original sender ID preserved
    - ✅ Excludes sender from forwarding to prevent immediate loops
  - [x] 1.3.5: Add logging for forwarding events ✅
    - ✅ Message reception logging with full header details
    - ✅ Deduplication check results
    - ✅ Forwarding decisions (TTL check)
    - ✅ Per-peer forwarding status
    - ✅ Total forward count

**Remaining Tasks:**

- [x] **Task 1.4: Update data models** ✅ (2 hours)
  - [x] 1.4.1: Add routing fields to Peer model (lastForwardTime) ✅
    - ✅ Added `lastForwardTime` field to track message forwarding timestamps
    - ✅ `hopCount` field already existed
    - ✅ Updated `fromMap()` and `toMap()` serialization
  - [x] 1.4.2: Add forwarding metrics to MeshEvent ✅
    - ✅ Added `forwardingMetrics` event type to `MeshEventType` enum
    - ✅ Added `MeshEvent.forwardingMetrics()` factory constructor
    - ✅ Added getter properties: `messagesForwarded`, `messagesCached`, `cacheHits`, `cacheMisses`
  - [x] 1.4.3: Message model routing fields ✅
    - ✅ All routing fields already exposed (`ttl`, `hopCount`, `senderId`, `messageId`, `isForwarded`)
  - [x] 1.4.4: Update API documentation ✅
    - ✅ Updated PROMPT.md with new Peer and MeshEvent fields
    - ✅ Documented Phase 2 routing fields in data models section

- [ ] **Task 1.5: Test multi-hop routing** (4-6 hours)
  - [ ] 1.5.1: Setup 3-4 physical devices for testing
  - [ ] 1.5.2: Test 2-hop scenario (A → B → C)
  - [ ] 1.5.3: Test 3-hop scenario (A → B → C → D)
  - [ ] 1.5.4: Verify loop prevention (message not forwarded back to sender)
  - [ ] 1.5.5: Verify TTL expiration (message dies after 7 hops)
  - [ ] 1.5.6: Verify deduplication (duplicate messages not forwarded)
  - [ ] 1.5.7: Measure network performance (latency, bandwidth, battery)

**Additional Phase 2 Tasks:**
- [ ] **Store-and-forward** (6-8 hours) - Phase 2.2
  - [ ] Implement message persistence for offline peers
  - [ ] Detect peer reconnection
  - [ ] Deliver cached messages on reconnection
  - [ ] Add message expiration (configurable TTL)

**See `docs/PHASE_2_IMPLEMENTATION_PLAN.md.backup` for detailed breakdown**

**Test Coverage:**
- ✅ MessageHeader: 42 tests (Android: 14, iOS: 15, Dart: 13)
- ✅ Message: 77 tests (Android: 13, iOS: 15, Dart: 49)
- ✅ Total: 119 tests, 100% passing, ~95% code coverage

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

**Current Status**: Phase 2 In Progress (60% Complete) 🚧

**Completed Phases:**
- ✅ **Phase 1: Core Functionality** - BLE scanning, advertising, peer discovery, message transmission, Flutter API
  - ✅ Android implementation complete with MSG_CHARACTERISTIC
  - ✅ iOS implementation complete with MSG_CHARACTERISTIC
  - ✅ Multi-device testing verified (Android ↔ Android, iOS ↔ iOS, Android ↔ iOS)
  - ✅ Thread-safe event delivery (UI thread marshaling)
  - ✅ GATT server and client dual role architecture
  - ✅ Device address validation and GATT cache management

**Phase 2 Progress (85% Complete):**
- ✅ **Task 1.1**: Routing Architecture Design (ROUTING_ARCHITECTURE.md - 999 lines)
- ✅ **Task 1.2**: MessageHeader Implementation (1,677 lines code, 42 tests passing)
  - ✅ Android: MessageHeader.kt + tests
  - ✅ iOS: MessageHeader.swift + tests
  - ✅ Dart: MessageHeader.dart + tests
  - ✅ Cross-platform binary compatibility verified
  - ✅ Message refactoring complete (encapsulation pattern)
  - ✅ Device ID redesign: UUID-based system (DeviceIdManager on all platforms)
- ✅ **Task 1.3**: Forwarding Logic Implementation (COMPLETE)
  - ✅ MessageCache with composite keys (senderId, messageId)
  - ✅ MessageHeader parsing in all reception paths
  - ✅ Forwarding decision logic with TTL and deduplication
  - ✅ forwardMessage() methods on both platforms
  - ✅ Comprehensive logging for debugging
  - ✅ iOS bidirectional reception (central + peripheral paths)
- ⏳ **Task 1.4**: Data Model Updates (NEXT)
- ⏳ **Task 1.5**: Multi-hop Testing

**Next Immediate Steps:**
1. Update Dart Message model to expose routing info (ttl, hopCount, senderId)
2. Add routing fields to Peer model (hopCount, lastForwardTime)
3. Add forwarding metrics to MeshEvent (messagesForwarded, messagesCached)
4. Update API documentation with new fields
5. Physical device testing (3+ devices) to verify multi-hop routing

**Key Achievements:**
- ✅ 16 comprehensive technical documentation files
- ✅ 119 tests passing (100% success rate)
  - Android: 27 tests
  - iOS: 30 tests
  - Dart: 62 tests
- ✅ ~95% code coverage for MessageHeader and Message classes
- ✅ Cross-platform binary protocol (20-byte header)
- ✅ Thread-safe event delivery (fixed UI thread violations)
- ✅ GATT server callbacks properly connected
- ✅ Package structure cleaned up (com.ble_mesh)
- ✅ Message flow verified end-to-end
- ✅ 16 design patterns documented and applied

**Issues Fixed:**
1. ✅ Threading violations (THREADING_FIX.md)
2. ✅ GATT server missing (GATT_SERVER_FIX.md)
3. ✅ Callbacks not connected (GATT_SERVER_CALLBACK_FIX.md)
4. ✅ Device address mismatch (DEVICE_ADDRESS_FIX.md)
5. ✅ Package naming (PACKAGE_RENAME.md)
6. ✅ Characteristic refactoring (MSG_CHARACTERISTIC_REFACTORING.md)
7. ✅ Test suite fixes (BLE_MESH_TEST_FIX.md, DART_TEST_MIGRATION.md)

**Code Statistics:**
- MessageHeader Implementation: 1,677 lines (across 3 platforms)
- Test Code: 2,166 lines
- Documentation: 16 files, ~6,000 lines
- Design Patterns Applied: 16 patterns documented

**Architecture Highlights:**
- Flood routing with TTL-based forwarding
- LRU cache deduplication (1000 entries, 5-min expiration)
- Event-driven architecture with reactive streams
- Dual GATT server/client roles
- Binary protocol with version negotiation
- Thread-safe UI marshaling
- Encapsulation and factory patterns

This is a Flutter plugin project that aims to bring Bluetooth LE mesh networking capabilities to Flutter applications, providing the same powerful features as the native bitchat implementations for both Android and iOS platforms.

---

**Last Updated**: 2025-12-17
**Plugin Version**: 0.1.0
**Flutter SDK**: >=3.3.0
**Dart SDK**: ^3.9.2

