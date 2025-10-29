import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

/// Service for managing app permissions and monitoring permission state changes
class PermissionService {
  /// Checks if location permission is granted
  static Future<bool> hasLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Checks if camera permission is granted
  static Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Checks if both camera and location permissions are granted
  static Future<bool> hasCameraAndLocationPermissions() async {
    final location = await hasLocationPermission();
    final camera = await hasCameraPermission();
    return location && camera;
  }

  /// Requests location permission
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Requests camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Requests both camera and location permissions
  static Future<Map<String, bool>> requestCameraAndLocationPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.location,
    ].request();

    return {
      'camera': statuses[Permission.camera]?.isGranted ?? false,
      'location': statuses[Permission.location]?.isGranted ?? false,
    };
  }

  /// Creates a stream that monitors location permission changes
  static Stream<bool> monitorLocationPermission() async* {
    while (true) {
      yield await hasLocationPermission();
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// Creates a stream that monitors camera and location permission changes
  static Stream<Map<String, bool>> monitorCameraAndLocationPermissions() async* {
    while (true) {
      final location = await hasLocationPermission();
      final camera = await hasCameraPermission();
      yield {'camera': camera, 'location': location};
      await Future.delayed(const Duration(seconds: 1));
    }
  }
}
