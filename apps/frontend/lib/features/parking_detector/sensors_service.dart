import 'dart:async';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// 一个简单的监听层：
/// - position$ 提供带速度的 GPS 位置（约每秒一次）
/// - userAccMag$ 提供去重力后的加速度模值的平滑输出
class SensorsService {
  // 对外公开的两个广播流
  final _positionCtrl = StreamController<Position>.broadcast();
  final _accCtrl = StreamController<double>.broadcast();

  Stream<Position> get position$ => _positionCtrl.stream;
  Stream<double> get userAccMag$ => _accCtrl.stream;

  StreamSubscription<Position>? _posSub;
  StreamSubscription<UserAccelerometerEvent>? _accSub;

  // 采样控制
  final Duration _gpsSample = const Duration(seconds: 1);
  DateTime _lastGpsEmit = DateTime.fromMillisecondsSinceEpoch(0);

  // 加速度滚动窗口做平滑，目标约 10 秒窗口
  final List<double> _accWindow = [];
  final int _accWindowSeconds = 10;

  Future<void> start() async {
    // 1) 定位权限
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      throw Exception('定位权限被拒绝');
    }

    // 2) 位置流
    final locationSettings = _buildLocationSettings();
    _posSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((pos) {
      final now = DateTime.now();
      // 时间节流：最多每秒发一次
      if (now.difference(_lastGpsEmit) >= _gpsSample) {
        _lastGpsEmit = now;
        _positionCtrl.add(pos); // pos.speed 是 m/s
      }
    });

    // 3) 加速度流（去重力）
    _accSub = userAccelerometerEvents.listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z); // 单位 m/s^2
      _accWindow.add(mag);

      // 粗略按 10Hz 估计窗口长度
      final int maxLen = 10 * _accWindowSeconds;
      if (_accWindow.length > maxLen) _accWindow.removeAt(0);

      // 输出平滑值
      final double avg =
      _accWindow.isEmpty ? 0.0 : _accWindow.reduce((a, b) => a + b) / _accWindow.length;
      _accCtrl.add(avg);
    });
  }

  Future<void> stop() async {
    await _posSub?.cancel();
    await _accSub?.cancel();
    await _positionCtrl.close();
    await _accCtrl.close();
  }

  LocationSettings _buildLocationSettings() {
    // 不同平台的建议设置
    if (!kIsWeb && Platform.isAndroid) {
      // Android 可显式设定间隔
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: _gpsSample,
        forceLocationManager: false,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      // iOS 没有固定间隔参数，这里用距离过滤为 0，然后在监听里用时间节流
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
