# iOS Info.plist Requirements

The following keys must be added to the app's Info.plist file to use the ble_mesh plugin:

## Required Permissions

```xml
<!-- Bluetooth Usage Description -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to communicate with nearby devices in a mesh network.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to communicate with nearby devices in a mesh network.</string>

<!-- For iOS 13+ -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to communicate with nearby devices in a mesh network.</string>
```

## Background Modes (Optional - for background operation)

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>bluetooth-peripheral</string>
</array>
```

## Implementation

Add these keys to your app's `Info.plist` file located at:
- `ios/Runner/Info.plist` (for Flutter apps)
- `example/ios/Runner/Info.plist` (for the example app)

You can customize the description strings to better match your app's use case.

