# Permission Handling Guide

This document explains how the BLE Mesh example app handles runtime permissions on Android and iOS.

## Overview

The app uses the `permission_handler` package to request and manage Bluetooth and location permissions required for BLE mesh networking. The permission flow is designed to be user-friendly and transparent.

## Architecture

### Components

1. **PermissionService** (`lib/services/permission_service.dart`)
   - Platform-specific permission checking and requesting
   - Handles Android API level differences
   - Provides detailed permission status

2. **PermissionDialog** (`lib/widgets/permission_dialog.dart`)
   - User-friendly permission explanation dialog
   - Shows why each permission is needed
   - Privacy assurance messaging

3. **PermissionDeniedDialog** (`lib/widgets/permission_dialog.dart`)
   - Handles permission denial scenarios
   - Guides users to app settings if permanently denied
   - Allows retry for temporary denials

## Permission Flow

### Initial Request

```
User taps "Start Mesh Network"
         ↓
Check if permissions already granted
         ↓
    [If granted] → Start mesh
         ↓
    [If not granted]
         ↓
Show explanation dialog
         ↓
User taps "Grant Permissions"
         ↓
System permission dialogs
         ↓
[If all granted] → Start mesh
         ↓
[If denied] → Show denial dialog
```

### Retry Flow

```
User denies permissions
         ↓
Show PermissionDeniedDialog
         ↓
User taps "Try Again"
         ↓
Repeat permission request
         ↓
[Success] → Start mesh
[Failure] → Show denial dialog again
```

### Permanent Denial

```
User permanently denies permissions
         ↓
Show PermissionDeniedDialog with "Open Settings"
         ↓
User taps "Open Settings"
         ↓
System settings app opens
         ↓
User manually enables permissions
         ↓
Returns to app
```

## Platform-Specific Details

### Android

#### API Level 31+ (Android 12+)

Required permissions:
- `BLUETOOTH_SCAN` - Scan for nearby BLE devices
- `BLUETOOTH_ADVERTISE` - Advertise as a BLE peripheral
- `BLUETOOTH_CONNECT` - Connect to BLE devices
- `ACCESS_FINE_LOCATION` - Required by Android for BLE scanning

#### API Level 30 and below (Android 11-)

Required permissions:
- `BLUETOOTH` - Basic Bluetooth operations
- `ACCESS_FINE_LOCATION` - Required for BLE scanning

#### Permission Detection

The app automatically detects the Android version by attempting to access the new Bluetooth permissions. If they exist, it uses the Android 12+ permission set; otherwise, it falls back to the legacy permissions.

#### Configuration

Permissions are declared in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
```

### iOS

#### Required Permissions

- `NSBluetoothAlwaysUsageDescription` - Bluetooth usage explanation

#### Configuration

Permissions are declared in `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to communicate with nearby devices in a mesh network</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to communicate with nearby devices</string>
```

#### Behavior

iOS handles Bluetooth permissions differently:
- No location permission required for BLE
- Single permission dialog for Bluetooth
- More restrictive background access

## User Experience

### Permission Explanation Dialog

**Title**: "Permissions Required"

**Content**:
- Clear explanation of why each permission is needed
- Icons for visual clarity
- Privacy assurance message
- "Grant Permissions" and "Cancel" buttons

**Example Messages**:
- **Bluetooth**: "Required to scan and connect to nearby devices"
- **Location**: "Required by Android for Bluetooth scanning (your location is not tracked)"

### Permission Denied Dialog

**For Temporary Denial**:
- Shows which permissions were denied
- "Try Again" button to retry
- "Cancel" button to abort

**For Permanent Denial**:
- Explains that manual action is required
- "Open Settings" button to launch system settings
- Instructions for enabling permissions

## Code Examples

### Checking Permissions

```dart
final hasPermissions = await PermissionService.hasAllPermissions();
if (hasPermissions) {
  // Permissions granted, proceed
} else {
  // Need to request permissions
}
```

### Requesting Permissions

```dart
// Show explanation dialog
final shouldRequest = await PermissionDialog.show(context);
if (!shouldRequest) return;

// Request permissions
final result = await PermissionService.requestAllPermissions();

if (result.granted) {
  // All permissions granted
  print('Success!');
} else if (result.permanentlyDenied) {
  // Show settings dialog
  await PermissionDeniedDialog.show(context, result);
} else {
  // Show retry dialog
  await PermissionDeniedDialog.show(context, result);
}
```

### Getting Detailed Status

```dart
final status = await PermissionService.getDetailedPermissionStatus();
// Returns: {'Bluetooth Scan': true, 'Location': false, ...}

for (final entry in status.entries) {
  print('${entry.key}: ${entry.value ? "Granted" : "Denied"}');
}
```

## Error Handling

### Common Issues

1. **Permission Request Fails**
   - Show user-friendly error message
   - Provide retry option
   - Guide to settings if needed

2. **Permanently Denied**
   - Detect permanent denial status
   - Show "Open Settings" button
   - Explain manual steps required

3. **User Cancels**
   - Respect user choice
   - Show message explaining why permissions are needed
   - Allow retry later

### Implementation

```dart
try {
  final result = await PermissionService.requestAllPermissions();

  if (!result.granted) {
    if (result.permanentlyDenied) {
      // Handle permanent denial
      _showSnackBar('Please enable permissions in Settings');
    } else {
      // Handle temporary denial
      _showSnackBar('Permissions are required to use BLE Mesh');
    }
  }
} catch (e) {
  // Handle unexpected errors
  _showSnackBar('Error requesting permissions: $e');
}
```

## Testing

### Manual Testing Steps

1. **First Launch**
   - Tap "Start Mesh Network"
   - Verify explanation dialog appears
   - Tap "Grant Permissions"
   - Verify system permission dialogs appear
   - Grant all permissions
   - Verify mesh starts successfully

2. **Permission Denial**
   - Deny one or more permissions
   - Verify denial dialog appears
   - Verify correct permissions listed
   - Tap "Try Again"
   - Verify permission request repeats

3. **Permanent Denial**
   - Permanently deny a permission (deny twice on Android)
   - Verify "Open Settings" button appears
   - Tap "Open Settings"
   - Verify app settings page opens
   - Enable permissions manually
   - Return to app and verify functionality

4. **Already Granted**
   - With permissions already granted
   - Tap "Start Mesh Network"
   - Verify no dialogs appear
   - Verify mesh starts immediately

### Automated Testing

```dart
testWidgets('Permission flow test', (tester) async {
  await tester.pumpWidget(MyApp());

  // Tap start mesh button
  await tester.tap(find.text('Start Mesh Network'));
  await tester.pumpAndSettle();

  // Verify permission dialog appears
  expect(find.text('Permissions Required'), findsOneWidget);

  // Grant permissions
  await tester.tap(find.text('Grant Permissions'));
  await tester.pumpAndSettle();

  // Verify mesh started
  expect(find.text('Mesh started'), findsOneWidget);
});
```

## Privacy Considerations

### Location Permission on Android

**Why Required**: Android requires location permission for BLE scanning due to potential location tracking via BLE beacons.

**Our Usage**: We do NOT track or access the user's location. The permission is solely required by the Android system for BLE operations.

**User Communication**: The app explicitly states: "your location is not tracked" in the permission explanation dialog.

### Data Collection

- **No personal data collected**
- **No location tracking**
- **No permission data stored**
- **No analytics on permission status**

### Best Practices

1. **Transparency**: Clear explanation of why each permission is needed
2. **Minimal Permissions**: Only request what's absolutely necessary
3. **Graceful Degradation**: App explains limitations if permissions denied
4. **No Persistence**: Don't repeatedly ask if user declines
5. **Privacy First**: Emphasize that location is not tracked

## Troubleshooting

### Permissions Not Requested

**Symptom**: No permission dialog appears

**Solutions**:
- Verify `permission_handler` is in `pubspec.yaml`
- Run `flutter pub get`
- Check platform-specific configuration files
- Verify running on physical device (not simulator)

### Permissions Denied But App Continues

**Symptom**: App tries to start mesh without permissions

**Solutions**:
- Check permission flow in `home_screen.dart`
- Verify `_checkAndRequestPermissions()` is called
- Check return value is properly handled

### "Permanently Denied" Not Detected

**Symptom**: Shows "Try Again" instead of "Open Settings"

**Solutions**:
- Verify Android permission denial count (deny twice)
- Check iOS permission status detection
- Update `permission_handler` package

### Settings Button Doesn't Work

**Symptom**: Tapping "Open Settings" does nothing

**Solutions**:
- Verify `openAppSettings()` is called
- Check platform-specific settings access
- Ensure proper context is passed

## Future Enhancements

- [ ] Remember permission denial to avoid repeated requests
- [ ] Show permission status in settings screen
- [ ] Add permission status debugging view
- [ ] Implement permission change listener
- [ ] Add analytics for permission grant rates (privacy-preserving)

## References

- [permission_handler package](https://pub.dev/packages/permission_handler)
- [Android Bluetooth permissions](https://developer.android.com/guide/topics/connectivity/bluetooth/permissions)
- [iOS Bluetooth permissions](https://developer.apple.com/documentation/bundleresources/information_property_list/nsbluetoothalwaysusagedescription)
- [Flutter permission best practices](https://docs.flutter.dev/platform-integration/platform-channels)

---

**Last Updated**: 2025-12-10
**Version**: 1.0.0

