// gyroscope_handler.dart
import 'dart:collection';
import 'dart:math' as math;
import 'parking_status_event.dart';
import 'parking_status_state.dart';
import 'utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GyroHandler {
  final KalmanFilter3D _gyroKalman = KalmanFilter3D(
    processNoise: 0.002,
    measurementNoise: 0.08,
  );

  final ListQueue<_GyroSample> _gyroWin = ListQueue();

  static const double gyroWinSec = 3.0;
  static const double gyroMoveThresh = 0.8;

  void onGyro(
    GyroscopeChanged e,
    Map<String, SensorVote> votes,
    Emitter<ParkingState> emit,
    void Function(Emitter<ParkingState>) updateState,
  ) {
    final (fx, fy, fz) = _gyroKalman.filter(e.x, e.y, e.z);
    _gyroWin.addLast(_GyroSample(e.t, fx, fy, fz));
    _evictOldGyro(e.t);

    if (_gyroWin.isEmpty) return;

    double maxRotation = 0.0;
    for (final sample in _gyroWin) {
      final rotation = math.sqrt(sample.x * sample.x + sample.y * sample.y + sample.z * sample.z);
      maxRotation = math.max(maxRotation, rotation);
    }

    if (maxRotation > gyroMoveThresh) {
      votes['gyroscope'] = SensorVote.parked;
    } else {
      votes['gyroscope'] = SensorVote.driving;
    }

    updateState(emit);
  }

  void _evictOldGyro(DateTime now) {
    final cutoff = now.millisecondsSinceEpoch - (gyroWinSec * 1000).toInt();
    while (_gyroWin.isNotEmpty && _gyroWin.first.t.millisecondsSinceEpoch < cutoff) {
      _gyroWin.removeFirst();
    }
  }
}

class _GyroSample {
  final DateTime t;
  final double x, y, z;
  _GyroSample(this.t, this.x, this.y, this.z);
}