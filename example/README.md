# BLE Mesh Example App

A comprehensive example application demonstrating how to use the **ble_mesh** plugin for Bluetooth Low Energy mesh networking in Flutter.

## Features

This example app showcases:

- ✅ **Automatic Permission Handling**: Intelligent permission requests with user-friendly dialogs
- ✅ **Nickname Configuration**: Set and change your display name
- ✅ **Mesh Network Control**: Start/stop the BLE mesh network
- ✅ **Peer Discovery**: Automatically discover and connect to nearby peers
- ✅ **Real-time Chat**: Send and receive messages across the mesh network
- ✅ **Connection Status**: Monitor connected peers and their signal strength (RSSI)
- ✅ **Message History**: View conversation history with timestamps
- ✅ **Clean UI**: Modern Material Design 3 interface

## Screenshots

The app includes three main screens:

1. **Home Screen**: Control mesh network, view connected peers, and monitor status
2. **Chat Screen**: Send and receive messages with a familiar chat interface
3. **Settings Screen**: Configure your nickname and view app information

## Getting Started

### Prerequisites

- Flutter SDK (>=3.3.0)
- Dart SDK (^3.9.2)
- Physical devices with Bluetooth Low Energy support (iOS 10.0+ or Android 5.0+)
- **Important**: BLE mesh networking requires physical devices - simulators/emulators will not work

### Required Permissions

#### Android

The plugin automatically requests the following permissions (already configured in `AndroidManifest.xml`):

- `BLUETOOTH`
- `BLUETOOTH_ADMIN`
- `BLUETOOTH_SCAN`
- `BLUETOOTH_ADVERTISE`
- `BLUETOOTH_CONNECT`
- `ACCESS_FINE_LOCATION` (required for BLE scanning on Android)

#### iOS

Add the following to your `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to communicate with nearby devices in a mesh network</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to communicate with nearby devices</string>
```

### Installation

1. Clone the repository and navigate to the example directory:

```bash
cd ble_mesh/example
```

2. Install dependencies:

```bash
flutter pub get
```

3. Run the app on a physical device:

```bash
# For Android
flutter run

# For iOS
flutter run
```

## How to Use

### Step 1: Configure Your Nickname

1. Open the app
2. Tap the **Settings** icon (gear icon) in the app bar, or tap **Change** next to your nickname
3. Enter a nickname (2-20 characters)
4. Tap **Save Settings**

### Step 2: Start the Mesh Network

1. On the home screen, tap **Start Mesh Network**
2. Grant Bluetooth permissions when prompted
3. The status will change to "Mesh started - Scanning for peers"

### Step 3: Connect to Peers

1. Ensure another device has the app installed and the mesh network started
2. Wait for automatic peer discovery (typically 5-30 seconds)
3. Connected peers will appear in the "Connected Peers" card
4. You'll see notifications when peers connect/disconnect

### Step 4: Send Messages

1. Tap **Open Chat** on the home screen
2. Type your message in the text field
3. Tap the send button or press Enter
4. Your message will be broadcast to all connected peers
5. Messages from other peers will appear in the chat

### Troubleshooting

**No peers connecting?**
- Ensure both devices have Bluetooth enabled
- Both devices must have the mesh network started
- Check that devices are within BLE range (typically 10-30 meters)
- Try restarting the mesh network on both devices

**Messages not sending?**
- Verify that peers are connected (check the home screen)
- Ensure the mesh network is running
- Check Bluetooth permissions are granted

**App crashes on startup?**
- Make sure you're running on a physical device, not a simulator
- Verify Bluetooth permissions are configured correctly
- Check that Bluetooth is enabled on your device

## Code Structure

```
example/lib/
├── main.dart                    # App entry point
└── screens/
    ├── home_screen.dart         # Main screen with mesh control
    ├── chat_screen.dart         # Chat interface
    └── settings_screen.dart     # Settings and configuration
```

## Key Components

### Home Screen

- Displays current nickname
- Shows mesh network status
- Lists connected peers with RSSI values
- Controls for starting/stopping the mesh
- Navigation to chat and settings

### Chat Screen

- Real-time message display
- Message bubbles with sender avatars
- Timestamp and delivery status indicators
- Text input with send button
- Auto-scrolling to latest messages

### Settings Screen

- Nickname configuration with validation
- Information about BLE Mesh technology
- Usage instructions
- App details

## API Usage Examples

### Initialize and Start Mesh

```dart
final BleMesh _bleMesh = BleMesh();

// Initialize with configuration
await _bleMesh.initialize(
  nickname: 'YourNickname',
  enableEncryption: false,  // Phase 1: Not implemented yet
  powerMode: PowerMode.balanced,
);

// Start the mesh network
await _bleMesh.startMesh();
```

### Listen to Events

```dart
// Listen to incoming messages
_bleMesh.messageStream.listen((message) {
  print('Received: ${message.content} from ${message.senderNickname}');
});

// Listen to peer connections
_bleMesh.peerConnectedStream.listen((peer) {
  print('Peer connected: ${peer.nickname}');
});

// Listen to peer disconnections
_bleMesh.peerDisconnectedStream.listen((peer) {
  print('Peer disconnected: ${peer.nickname}');
});
```

### Send Messages

```dart
// Send a public message to all connected peers
await _bleMesh.sendPublicMessage('Hello, mesh network!');
```

### Get Connected Peers

```dart
// Get list of currently connected peers
List<Peer> peers = await _bleMesh.getConnectedPeers();
```

### Stop Mesh

```dart
// Stop the mesh network
await _bleMesh.stopMesh();
```

## Current Limitations (Phase 1)

- **No Encryption**: Messages are sent in plain text
- **No Multi-hop Relay**: Messages only reach directly connected peers
- **No Store-and-Forward**: Messages are not cached for offline peers
- **No Private Messaging**: Only public broadcast messaging is available
- **No Channel Support**: No topic-based group messaging yet

These features are planned for future phases (see main project PROMPT.md).

## Testing

To test the mesh functionality:

1. Install the app on **two or more physical devices**
2. Start the mesh network on all devices
3. Wait for automatic peer discovery
4. Send messages from any device
5. Verify messages appear on all connected devices

## Learn More

For more information about the ble_mesh plugin:

- [Plugin Documentation](../README.md)
- [Project Roadmap](../PROMPT.md)
- [Flutter Plugin Development](https://docs.flutter.dev/packages-and-plugins/developing-packages)

## License

This example app is part of the ble_mesh plugin project.
