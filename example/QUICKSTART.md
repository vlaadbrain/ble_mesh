# Quick Start Guide

This guide will help you quickly get started with the BLE Mesh example app.

## Prerequisites

- Two or more physical devices with Bluetooth LE support
- Flutter SDK installed
- Devices running iOS 10.0+ or Android 5.0+

## Installation

1. **Navigate to the example directory:**
   ```bash
   cd ble_mesh/example
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on your device:**
   ```bash
   flutter run
   ```

   **Note:** You must use physical devices. Simulators/emulators do not support BLE.

## First Time Setup

### On Device 1:

1. Open the app
2. Tap the settings icon or "Change" next to your nickname
3. Set your nickname (e.g., "Alice")
4. Tap "Save Settings"
5. On the home screen, tap "Start Mesh Network"
6. **NEW**: See permission explanation dialog → Tap "Grant Permissions"
7. Grant Bluetooth permissions when system dialogs appear
8. Wait for the status to show "Mesh started - Scanning for peers"

### On Device 2:

1. Repeat the same steps as Device 1
2. Set a different nickname (e.g., "Bob")
3. Start the mesh network
4. Wait 5-30 seconds for automatic peer discovery

### Verify Connection:

- On both devices, you should see the peer appear in the "Connected Peers" section
- You'll see a notification: "Peer connected: [nickname]"

## Sending Your First Message

1. On either device, tap "Open Chat"
2. Type a message in the text field
3. Tap the send button or press Enter
4. The message should appear on both devices

## Troubleshooting

### Devices not connecting?

**Check Bluetooth:**
- Ensure Bluetooth is enabled on both devices
- Verify you're within BLE range (10-30 meters)

**Check Permissions:**
- Android: Location permission is required for BLE scanning
- iOS: Bluetooth permission must be granted

**Restart the mesh:**
1. Stop the mesh on both devices
2. Wait 5 seconds
3. Start the mesh again on both devices

### Messages not appearing?

- Verify both devices show as connected in the "Connected Peers" list
- Check that the mesh network is running (green status card)
- Try restarting the app

## Testing Scenarios

### Scenario 1: Basic Chat
1. Connect two devices
2. Send messages back and forth
3. Verify messages appear in real-time

### Scenario 2: Multiple Peers
1. Connect 3+ devices (up to 7 supported)
2. Send a message from one device
3. Verify it appears on all other devices

### Scenario 3: Reconnection
1. Connect two devices
2. Turn off Bluetooth on one device
3. Observe disconnection notification
4. Turn Bluetooth back on
5. Devices should reconnect automatically

### Scenario 4: Range Testing
1. Connect two devices
2. Slowly walk away from each other
3. Note when disconnection occurs (typically 10-30 meters)
4. Walk back together
5. Devices should reconnect

## App Features

### Home Screen
- **Nickname Display:** Shows your current nickname
- **Mesh Status:** Indicates if the mesh is running
- **Connected Peers:** Lists all connected devices with signal strength
- **Start/Stop Button:** Controls the mesh network
- **Open Chat Button:** Opens the messaging interface

### Chat Screen
- **Message List:** Shows all sent and received messages
- **Message Input:** Type and send messages
- **Clear Button:** Removes all messages from the chat
- **Auto-scroll:** Automatically scrolls to newest messages

### Settings Screen
- **Nickname Configuration:** Change your display name
- **About Information:** Details about BLE Mesh technology
- **Usage Instructions:** Step-by-step guide

## Performance Tips

1. **Battery Life:**
   - The app uses "Balanced" power mode by default
   - Stopping the mesh when not in use saves battery

2. **Connection Quality:**
   - Stay within 10-30 meters for best results
   - Avoid obstacles between devices (walls, metal objects)
   - Fewer connected devices = more stable connections

3. **Message Delivery:**
   - Messages are sent immediately when connected
   - Currently no store-and-forward (Phase 1 limitation)
   - Messages only reach directly connected peers

## Known Limitations (Phase 1)

- **No Encryption:** Messages are sent in plain text
- **Direct Connections Only:** No multi-hop relay yet
- **No Offline Messages:** Messages aren't cached for offline peers
- **Public Messages Only:** No private/direct messaging yet

These features are planned for future phases.

## Next Steps

- Read the [full README](README.md) for detailed documentation
- Check out the [main project documentation](../PROMPT.md)
- Explore the source code in `lib/screens/`

## Need Help?

If you encounter issues:

1. Check the troubleshooting section above
2. Verify your Flutter SDK is up to date
3. Ensure devices meet minimum requirements
4. Check the console for error messages

## Example Use Cases

- **Emergency Communication:** Test offline messaging
- **Local Multiplayer Games:** Coordinate without internet
- **Event Coordination:** Communicate at gatherings
- **Privacy-Focused Chat:** No servers, no tracking

Happy meshing! 🎉

