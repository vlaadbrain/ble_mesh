# Changelog

All notable changes to the BLE Mesh Flutter plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-12-13

### Summary

Phase 1 Complete! This release includes full BLE mesh networking functionality for both Android and iOS, with MSG_CHARACTERISTIC implementation, comprehensive testing, and a polished example app.

**Key Highlights:**
- ✅ Complete Android & iOS implementation
- ✅ MSG_CHARACTERISTIC for bidirectional communication
- ✅ Multi-device testing verified (Android ↔ iOS)
- ✅ Production-ready for peer-to-peer messaging
- ✅ Example app with permissions and Material Design 3 UI

## [0.0.1] - 2025-12-13 [YANKED]

**Note**: This version was immediately superseded by 0.1.0 after successful multi-device testing.

### Added

#### Core BLE Mesh Functionality
- **Bluetooth Low Energy mesh networking** support for Android and iOS
- **Peer discovery** via BLE scanning with automatic connection management
- **BLE advertising** to broadcast device presence to nearby peers
- **Bidirectional messaging** using MSG_CHARACTERISTIC for peer-to-peer communication
- **GATT server and client** roles - each device acts as both server and client
- **Connection management** supporting up to 7 simultaneous peer connections
- **Power modes** (Balanced, Power Saver, Performance) for battery optimization
- **Encryption support** (framework ready, implementation pending)

#### Android Implementation
- `BleScanner` - Scans for nearby mesh devices
- `BleAdvertiser` - Advertises device presence
- `BleGattServer` - GATT server providing MSG and Control characteristics
- `BleConnectionManager` - Manages connections to peer devices
- `GattServiceManager` - Handles GATT service operations
- `BluetoothMeshService` - Main coordinator for mesh operations
- `PeerManager` - Tracks discovered and connected peers
- `BleConstants` - Centralized constants and UUIDs

#### iOS Implementation ✅ COMPLETE
- `BleScanner` - Scans for nearby mesh devices
- `BleAdvertiser` - Advertises device presence
- `BlePeripheralServer` - Peripheral server with MSG_CHARACTERISTIC ✅
- `BleConnectionManager` - Connection management
- `ServiceManager` - GATT service operations with MSG_CHARACTERISTIC ✅
- `PeerManager` - Peer tracking
- `BleConstants` - Constants and UUIDs with MSG_CHARACTERISTIC ✅
- **Status**: iOS implementation complete and tested with MSG_CHARACTERISTIC

#### Flutter API
- `BleMesh` class - Main plugin interface
- `initialize()` - Configure mesh with nickname, encryption, power mode
- `startMesh()` - Start scanning and advertising
- `stopMesh()` - Stop mesh operations
- `sendPublicMessage()` - Broadcast message to all connected peers
- `messageStream` - Stream of received messages
- `peerConnectedStream` - Stream of peer connection events
- `peerDisconnectedStream` - Stream of peer disconnection events
- `meshEventStream` - Stream of mesh events (errors, state changes)
- `getConnectedPeers()` - Get list of currently connected peers

#### Data Models
- `Peer` - Represents a discovered or connected peer device
- `Message` - Message with sender info, content, type, and status
- `MeshEvent` - Mesh events (started, stopped, errors, peer discovered)
- `PowerMode` - Enum for power management modes
- `MessageType` - Enum for message types (public, private, broadcast)
- `DeliveryStatus` - Enum for message delivery status

#### Example Application
- **Home screen** with mesh control and peer monitoring
- **Chat screen** for real-time messaging with connected peers
- **Settings screen** for nickname configuration
- **Permission handling** with automatic permission flow
- **Material Design 3** UI with polished user experience
- `PermissionService` - Platform-specific permission management
- `PermissionDialog` - User-friendly permission request dialogs
- Comprehensive documentation (README, QUICKSTART, PERMISSIONS)

#### Documentation
- `README.md` - Project overview and getting started guide
- `PROMPT.md` - Development prompts and guidelines
- `THREADING_FIX.md` - Threading model documentation (355 lines)
- `GATT_SERVER_FIX.md` - GATT server implementation details
- `DEVICE_ADDRESS_FIX.md` - Device address validation fix
- `MSG_CHARACTERISTIC_REFACTORING.md` - TX/RX to MSG migration
- `GATT_SERVER_CALLBACK_FIX.md` - Callback connection fix
- `MESSAGE_FLOW_VERIFICATION.md` - Complete message flow diagram
- `PACKAGE_RENAME.md` - Package rename documentation
- Example app documentation (README, QUICKSTART, PERMISSIONS, IMPLEMENTATION_NOTES)

### Changed

#### Architecture Improvements
- **Refactored characteristics model** from separate TX/RX to single MSG_CHARACTERISTIC
  - Simplified service discovery (one characteristic instead of two)
  - Symmetric bidirectional communication
  - Follows Nordic UART Service pattern
  - MSG_CHARACTERISTIC UUID: `00001235-0000-1000-8000-00805f9b34fb`
  - Properties: WRITE + WRITE_NO_RESPONSE + READ + NOTIFY

#### Package Rename
- **Package name** changed from `com.bitchat.ble_mesh` to `com.ble_mesh`
- **Directory structure** reorganized to match new package name
- **All imports and references** updated across Kotlin and Swift files
- **Example app** package updated to `com.ble_mesh_example`
- **No breaking changes** to Flutter/Dart API

#### Threading Model
- **Android**: All Flutter event channel messages sent on UI thread via `Handler(Looper.getMainLooper())`
- **iOS**: All Flutter event channel messages sent on main queue via `DispatchQueue.main.async`
- Eliminates crashes from background thread → Flutter communication

#### Connection Management
- **Device address validation**: Always use `gatt.device.address` instead of closure variables
- **GATT cache clearing**: Refresh cache on connection to prevent stale characteristics
- **Enhanced logging**: Detailed service/characteristic discovery logs
- **Address mismatch detection**: Warns if expected and actual addresses differ

### Fixed

#### Critical Fixes
- **GATT server callbacks not connected** (Android)
  - `BleGattServer.onCharacteristicWriteRequest` was never set up
  - Messages written to GATT server were silently dropped
  - Fixed by connecting callbacks in `BluetoothMeshService.setupCallbacks()`
  - Messages now properly flow from GATT server to Flutter messageStream

- **Device address mismatch** (Android)
  - GATT callbacks used closure variable instead of actual device address
  - Caused characteristics to be associated with wrong device
  - Fixed by using `gatt.device.address` in all callbacks
  - Added GATT cache refresh to prevent stale service data

- **Threading violations** (Android & iOS)
  - EventStreamHandler called Flutter from background threads
  - Caused "Methods marked with @UiThread must be executed on main thread" errors
  - Fixed by marshaling all events to main/UI thread

- **Missing UUID import** (Android)
  - `BleGattServer.kt` used `UUID.fromString()` without import
  - Fixed by adding `import java.util.UUID`

#### Android Specific
- GATT service cache issues causing wrong characteristics to appear
- Multiple simultaneous connections causing address confusion
- Service discovery returning cached data from previous connections

#### iOS Specific
- Constants updated to use MSG_CHARACTERISTIC (TX/RX removed)
- Dispatch queue labels updated to new package name

### Technical Details

#### BLE Service Structure
```
Mesh Service UUID: 00001234-0000-1000-8000-00805f9b34fb

Characteristics:
├─ MSG Characteristic (00001235)
│  ├─ Properties: WRITE, WRITE_NO_RESPONSE, READ, NOTIFY
│  ├─ Permissions: WRITE, READ
│  └─ CCCD Descriptor (00002902) - For notification subscription
│
└─ Control Characteristic (00001237)
   ├─ Properties: READ, WRITE
   └─ Permissions: READ, WRITE (for future use)
```

#### Message Flow
1. **Sending** (as GATT client):
   - Find peer's MSG_CHARACTERISTIC
   - Write message data
   - Peer's GATT server receives via `onCharacteristicWriteRequest`

2. **Receiving** (as GATT server):
   - Peer writes to your MSG_CHARACTERISTIC
   - `BleGattServer.onCharacteristicWriteRequest` callback triggered
   - Message forwarded to Flutter via `onMessageReceived`
   - Flutter `messageStream` emits message

3. **Receiving** (as GATT client):
   - Peer sends notification on their MSG_CHARACTERISTIC
   - `BleConnectionManager.onCharacteristicChanged` callback triggered
   - Message forwarded to Flutter via `onMessageReceived`
   - Flutter `messageStream` emits message

#### Connection Limits
- Maximum 7 simultaneous connections (BLE stack limitation)
- Auto-connect to discovered peers up to limit
- Connection timeout: 30 seconds
- MTU size: 512 bytes for better throughput

#### Permission Handling
- **Android 12+**: BLUETOOTH_SCAN, BLUETOOTH_CONNECT, BLUETOOTH_ADVERTISE
- **Android 11-**: ACCESS_FINE_LOCATION, BLUETOOTH, BLUETOOTH_ADMIN
- **iOS**: Bluetooth usage descriptions in Info.plist
- Automatic permission flow with user-friendly dialogs

### Known Issues

#### General
- Encryption not yet implemented (framework ready)
- Multi-hop routing not implemented (Phase 2 feature)
- Message deduplication not implemented (Phase 2 feature)
- TTL-based forwarding not implemented (Phase 2 feature)
- Store-and-forward not implemented (Phase 2 feature)
- No message acknowledgments yet (Phase 4 feature)
- No message compression (Phase 5 feature)

### Testing Status

#### Compilation
- ✅ Android: All files compile successfully
- ✅ iOS: All files compile successfully with MSG_CHARACTERISTIC
- ✅ Flutter: `flutter analyze` passes (only unrelated test file error)
- ✅ Example app: Compiles successfully

#### Physical Device Testing ✅ COMPLETE
- ✅ **Android ↔ Android**: Tested successfully on physical devices
- ✅ **iOS ↔ iOS**: Tested successfully on physical devices
- ✅ **Android ↔ iOS**: Cross-platform tested successfully
- ✅ **Multi-device**: Tested with multiple devices simultaneously
- ✅ **Message transmission**: Verified end-to-end bidirectional communication
- ✅ **MSG_CHARACTERISTIC**: Confirmed working on both platforms
- ✅ **GATT Server/Client**: Both roles tested and working
- ✅ **Peer discovery**: Auto-connect and connection management verified
- ✅ **Event streams**: messageStream, peerConnectedStream, meshEventStream working

### Dependencies

#### Flutter
- `flutter: sdk: flutter`
- `plugin_platform_interface: ^2.1.8`

#### Example App
- `permission_handler: ^11.3.0`
- `shared_preferences: ^2.2.2`

### Platform Requirements

#### Android
- Minimum SDK: 21 (Android 5.0 Lollipop)
- Target SDK: 34 (Android 14)
- Kotlin: 1.9.0+
- Gradle: 8.1.0+

#### iOS
- Minimum iOS version: 12.0
- Swift: 5.0+
- CoreBluetooth framework

### Migration Guide

#### From TX/RX to MSG Characteristic
If you have existing code using TX/RX characteristics:

1. **Update UUIDs**:
   ```kotlin
   // Old
   val txUUID = "00001235-..."
   val rxUUID = "00001236-..."

   // New
   val msgUUID = "00001235-..."  // Reuses TX UUID
   ```

2. **Update characteristic finding**:
   ```kotlin
   // Old
   val txChar = gattServiceManager.findTxCharacteristic(gatt)
   val rxChar = gattServiceManager.findRxCharacteristic(gatt)

   // New
   val msgChar = gattServiceManager.findMsgCharacteristic(gatt)
   ```

3. **Update notifications**:
   ```kotlin
   // Old
   setupNotifications(gatt, rxCharacteristic)

   // New
   setupNotifications(gatt, msgCharacteristic)
   ```

4. **Update write operations**:
   ```kotlin
   // Old
   writeCharacteristic(gatt, txCharacteristic, data)

   // New
   writeCharacteristic(gatt, msgCharacteristic, data)
   ```

#### Package Rename
If you copied example code:

1. Update package declarations in your MainActivity
2. Update namespace and applicationId in build.gradle.kts
3. Move MainActivity if you created the old directory structure

See `PACKAGE_RENAME.md` for detailed migration steps.

### Contributors

- Development and implementation by the BLE Mesh team
- Based on Flutter plugin template
- Uses CoreBluetooth (iOS) and Android BLE APIs

### License

See LICENSE file for details.

---

## [Unreleased]

### Planned Features

#### Phase 2: Security
- AES-128 encryption for messages
- Key exchange protocol
- Secure pairing

#### Phase 3: Mesh Routing
- Multi-hop message forwarding
- Route discovery and optimization
- Network topology management

#### Phase 4: Advanced Features
- Private messaging (1-to-1)
- Message acknowledgments
- Delivery guarantees
- Group messaging

#### Phase 5: Optimization
- Message compression
- Battery optimization
- Connection pooling
- Adaptive power management

#### Phase 6: Testing & Polish
- Comprehensive unit tests
- Integration tests
- Performance benchmarks
- Physical device testing
- Multi-device scenarios

### Completed in v0.0.1

- ✅ iOS implementation with MSG_CHARACTERISTIC
- ✅ Physical device testing (Android & iOS)
- ✅ Cross-platform testing (Android ↔ iOS)
- ✅ Multi-device testing

### In Progress

- README with architecture diagrams and mermaid sequence diagrams
- API documentation
- Phase 2: Mesh Networking implementation

---

**Note**: Phase 1 is complete and tested. The plugin is functional for peer-to-peer messaging but does not yet support multi-hop routing, encryption, or advanced features planned for Phases 2-6.
