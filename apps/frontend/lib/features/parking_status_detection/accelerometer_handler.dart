// accelerometer_handler.dart
import 'dart:collection';
import 'dart:math' as math;
import 'parking_status_event.dart';
import 'parking_status_state.dart';
import 'utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AccelHandler {
  final KalmanFilter3D _accKalman = KalmanFilter3D(
    processNoise: 0.001,
    measurementNoise: 0.05,
  );

  final ListQueue<_Sample> _win = ListQueue();
  double _sumSq = 0.0;
  int _quietCount = 0;

  bool _inStopCandidate = false;
  DateTime? _stopCandidateStart;

  // Tunables
  static const double winSec = 5.0;
  static const double stillRmsMaxIn = 0.045;
  static const double stillRmsMaxOut = 0.065;
  static const double driveRmsMin = 0.075;
  static const double quietEps = 0.018;
  static const double quietRatioIn = 0.82;
  static const double quietRatioOut = 0.58;
  static const double tStillForCandidate = 5.0;
  static const double tConfirmStill = 25.0;

  void onAcc(
    AccelerometerChanged e,
    Map<String, SensorVote> votes,
    Emitter<ParkingState> emit,
    void Function(Emitter<ParkingState>) updateState,
  ) {
    final (fx, fy, fz) = _accKalman.filter(e.x, e.y, e.z);
    final mag = math.sqrt(fx * fx + fy * fy + fz * fz);

    _appendSample(e.t, mag);
    _evictOld(e.t);
    if (_win.isEmpty) return;

    final rms = _currentRms();
    final qRatio = _quietCount / _win.length;
    final now = e.t;

    if (rms > driveRmsMin) {
      votes['accelerometer'] = SensorVote.driving;
      _inStopCandidate = false;
      _stopCandidateStart = null;
      updateState(emit);
      return;
    }

    if (!_inStopCandidate) {
      final quietHit = qRatio >= quietRatioIn;
      final rmsHit = rms < stillRmsMaxIn;
      if (quietHit && rmsHit) {
        _stopCandidateStart ??= now;
        if (_secsSince(_stopCandidateStart!, now) >= tStillForCandidate) {
          _inStopCandidate = true;
        }
      } else {
        _stopCandidateStart = null;
      }
    } else {
      final quietLost = qRatio < quietRatioOut;
      final rmsLost = rms > stillRmsMaxOut;
      if (quietLost && rmsLost) {
        _inStopCandidate = false;
        _stopCandidateStart = null;
      }
    }

    if (_inStopCandidate && _stopCandidateStart != null) {
      if (_secsSince(_stopCandidateStart!, now) >= tConfirmStill) {
        votes['accelerometer'] = SensorVote.parked;
      } else {
        votes['accelerometer'] = SensorVote.driving;
      }
    } else {
      votes['accelerometer'] = SensorVote.driving;
    }

    updateState(emit);
  }

  void _appendSample(DateTime t, double mag) {
    _win.addLast(_Sample(t, mag));
    _sumSq += mag * mag;
    if (mag < quietEps) _quietCount += 1;
  }

  void _evictOld(DateTime now) {
    final cutoff = now.millisecondsSinceEpoch - (winSec * 1000).toInt();
    while (_win.isNotEmpty && _win.first.t.millisecondsSinceEpoch < cutoff) {
      final old = _win.removeFirst();
      _sumSq -= old.mag * old.mag;
      if (old.mag < quietEps) _quietCount -= 1;
    }
  }

  double _currentRms() => _win.isEmpty ? 0.0 : math.sqrt(_sumSq / _win.length);
  double _secsSince(DateTime from, DateTime to) => to.difference(from).inMilliseconds / 1000.0;
}

class _Sample {
  final DateTime t;
  final double mag;
  _Sample(this.t, this.mag);
}
