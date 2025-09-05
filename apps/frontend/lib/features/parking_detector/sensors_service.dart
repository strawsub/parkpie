import 'dart:async';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A simple listening layer:
/// - `position$` provides GPS positions with speed (about once per second).
/// - `userAccMag$` provides a smoothed magnitude of gravity-compensated acceleration.
class SensorsService {
  // make two streams of broadcast to be public
  final _positionCtrl = StreamController<Position>.broadcast();
  final _accCtrl = StreamController<double>.broadcast();

  Stream<Position> get position$ => _positionCtrl.stream;
  Stream<double> get userAccMag$ => _accCtrl.stream;

  StreamSubscription<Position>? _posSub;
  StreamSubscription<UserAccelerometerEvent>? _accSub;

  // sample control, send a location per second, to avoid frequent use of UI and power resumption
  final Duration _gpsSample = const Duration(seconds: 1);
  DateTime _lastGpsEmit = DateTime.fromMillisecondsSinceEpoch(0);

  // Acc to be smoothed by the slide window, set the window to be 10s
  final List<double> _accWindow = [];
  final int _accWindowSeconds = 10;

  Future<void> start() async {
    // 1) Location permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      throw Exception('Location is Refused');
      // return; // TBD
    }

    // 2) Location Stream
    final locationSettings = _buildLocationSettings();
    _posSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((pos) {
      final now = DateTime.now();
      // Time stream: send every second
      if (now.difference(_lastGpsEmit) >= _gpsSample) {
        _lastGpsEmit = now;
        _positionCtrl.add(pos);
      }
    });

    // 3) Acceleration Stream (without G)
    _accSub = userAccelerometerEvents.listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z); // m/s^2
      _accWindow.add(mag);

      // slide window: 10Hz
      final int maxLen = 10 * _accWindowSeconds;
      if (_accWindow.length > maxLen) _accWindow.removeAt(0);

      // Output after slide window
      final double avg =
      _accWindow.isEmpty ? 0.0 : _accWindow.reduce((a, b) => a + b) / _accWindow.length;
      _accCtrl.add(avg);
    });
  }

  Future<void> stop() async { //TBD：waiting for 10s after confirming the parking status,
    // or user closes the app, or both?
    await _posSub?.cancel();
    await _accSub?.cancel();
    await _positionCtrl.close();
    await _accCtrl.close();
  }

  LocationSettings _buildLocationSettings() {
    // Settings of different platform
    if (!kIsWeb && Platform.isAndroid) {
      // Android
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: _gpsSample,
        forceLocationManager: false,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      // iOS
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: false,
        showBackgroundLocationIndicator: false,
      );
    } else {
      return const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      );
    }
  }
}
