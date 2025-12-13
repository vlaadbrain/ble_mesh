import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Service to handle all permission requests for BLE Mesh
class PermissionService {
  /// Check if all required permissions are granted
  static Future<bool> hasAllPermissions() async {
    if (Platform.isAndroid) {
      return await _hasAndroidPermissions();
    } else if (Platform.isIOS) {
      return await _hasIOSPermissions();
    }
    return false;
  }

  /// Request all required permissions
  static Future<PermissionResult> requestAllPermissions() async {
    if (Platform.isAndroid) {
      return await _requestAndroidPermissions();
    } else if (Platform.isIOS) {
      return await _requestIOSPermissions();
    }
    return PermissionResult(
      granted: false,
      deniedPermissions: [],
      permanentlyDenied: false,
    );
  }

  /// Check Android permissions
  static Future<bool> _hasAndroidPermissions() async {
    // Get Android version to determine which permissions to check
    final androidInfo = await _getAndroidVersion();

    if (androidInfo >= 31) {
      // Android 12+ (API 31+)
      return await Permission.bluetoothScan.isGranted &&
          await Permission.bluetoothAdvertise.isGranted &&
          await Permission.bluetoothConnect.isGranted &&
          await Permission.location.isGranted;
    } else {
      // Android 11 and below
      return await Permission.bluetooth.isGranted &&
          await Permission.location.isGranted;
    }
  }

  /// Request Android permissions
  static Future<PermissionResult> _requestAndroidPermissions() async {
    final androidInfo = await _getAndroidVersion();
    final List<Permission> permissionsToRequest = [];
    final List<String> deniedPermissions = [];
    bool permanentlyDenied = false;

    if (androidInfo >= 31) {
      // Android 12+ (API 31+)
      permissionsToRequest.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.location,
      ]);
    } else {
      // Android 11 and below
      permissionsToRequest.addAll([
        Permission.bluetooth,
        Permission.location,
      ]);
    }

    // Request all permissions
    final Map<Permission, PermissionStatus> statuses =
        await permissionsToRequest.request();

    // Check results
    for (final entry in statuses.entries) {
      if (entry.value.isDenied) {
        deniedPermissions.add(_getPermissionName(entry.key));
      } else if (entry.value.isPermanentlyDenied) {
        deniedPermissions.add(_getPermissionName(entry.key));
        permanentlyDenied = true;
      }
    }

    final allGranted = deniedPermissions.isEmpty;

    return PermissionResult(
      granted: allGranted,
      deniedPermissions: deniedPermissions,
      permanentlyDenied: permanentlyDenied,
    );
  }

  /// Check iOS permissions
  static Future<bool> _hasIOSPermissions() async {
    return await Permission.bluetooth.isGranted;
  }

  /// Request iOS permissions
  static Future<PermissionResult> _requestIOSPermissions() async {
    final status = await Permission.bluetooth.request();

    if (status.isGranted) {
      return PermissionResult(
        granted: true,
        deniedPermissions: [],
        permanentlyDenied: false,
      );
    } else if (status.isPermanentlyDenied) {
      return PermissionResult(
        granted: false,
        deniedPermissions: ['Bluetooth'],
        permanentlyDenied: true,
      );
    } else {
      return PermissionResult(
        granted: false,
        deniedPermissions: ['Bluetooth'],
        permanentlyDenied: false,
      );
    }
  }

  /// Get Android SDK version
  static Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;

    // For simplicity, we'll check which permissions are available
    // Android 12+ has the new Bluetooth permissions
    try {
      await Permission.bluetoothScan.status;
      return 31; // Android 12+
    } catch (e) {
      return 30; // Android 11 or below
    }
  }

  /// Get human-readable permission name
  static String _getPermissionName(Permission permission) {
    if (permission == Permission.bluetooth) return 'Bluetooth';
    if (permission == Permission.bluetoothScan) return 'Bluetooth Scan';
    if (permission == Permission.bluetoothAdvertise) return 'Bluetooth Advertise';
    if (permission == Permission.bluetoothConnect) return 'Bluetooth Connect';
    if (permission == Permission.location) return 'Location';
    return permission.toString();
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Get detailed permission status for debugging
  static Future<Map<String, bool>> getDetailedPermissionStatus() async {
    final Map<String, bool> status = {};

    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();

      if (androidInfo >= 31) {
        status['Bluetooth Scan'] = await Permission.bluetoothScan.isGranted;
        status['Bluetooth Advertise'] =
            await Permission.bluetoothAdvertise.isGranted;
        status['Bluetooth Connect'] =
            await Permission.bluetoothConnect.isGranted;
      } else {
        status['Bluetooth'] = await Permission.bluetooth.isGranted;
      }
      status['Location'] = await Permission.location.isGranted;
    } else if (Platform.isIOS) {
      status['Bluetooth'] = await Permission.bluetooth.isGranted;
    }

    return status;
  }
}

/// Result of permission request
class PermissionResult {
  /// Whether all permissions were granted
  final bool granted;

  /// List of denied permission names
  final List<String> deniedPermissions;

  /// Whether any permission was permanently denied
  final bool permanentlyDenied;

  const PermissionResult({
    required this.granted,
    required this.deniedPermissions,
    required this.permanentlyDenied,
  });

  /// Get user-friendly message
  String getMessage() {
    if (granted) {
      return 'All permissions granted';
    } else if (permanentlyDenied) {
      return 'Some permissions were permanently denied. Please enable them in Settings.';
    } else {
      return 'The following permissions are required: ${deniedPermissions.join(", ")}';
    }
  }
}

