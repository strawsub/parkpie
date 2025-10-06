import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../utils.dart';
import 'acc_event.dart';
import 'acc_state.dart';

class AccBloc extends Bloc<AccEvent, AccState> {
  // Configuration
  static const _config = AccConfig();
  
  // Kalman filter for noise reduction
  final KalmanFilter3D _kalmanFilter = KalmanFilter3D(
    processNoise: 0.001,
    measurementNoise: 0.05,
  );

  // Sample window for RMS calculation
  final ListQueue<AccSample> _window = ListQueue();
  double _sumSquared = 0.0;
  int _quietSampleCount = 0;

  // Stop detection state
  bool _isStopCandidate = false;
  DateTime? _stopCandidateStartTime;

  // Sensor subscription
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;

  AccBloc() : super(const AccInitial()) {
    on<AccDataReceived>(_onDataReceived);
    on<ResetAcc>(_onReset);
    _initializeSensor();
  }

  void _initializeSensor() {
    _sensorSubscription = userAccelerometerEventStream().listen(
      (event) {
        add(AccDataReceived(
          x: event.x,
          y: event.y,
          z: event.z,
          timestamp: DateTime.now(),
        ));
      },
      onError: (error) {
        debugPrint('Acc sensor error: $error');
      },
    );
  }

  void _onDataReceived(
    AccDataReceived event,
    Emitter<AccState> emit,
  ) {
    // Apply Kalman filtering
    final (fx, fy, fz) = _kalmanFilter.filter(event.x, event.y, event.z);
    final magnitude = math.sqrt(fx * fx + fy * fy + fz * fz);

    // Update window
    _addSample(event.timestamp, magnitude);
    _removeOldSamples(event.timestamp);

    if (_window.isEmpty) return;

    // Calculate metrics
    final rms = _calculateRMS();
    final quietRatio = _calculateQuietRatio();

    // Determine vote
    final vote = _determineVote(rms, quietRatio, event.timestamp);

    emit(AccReading(
      vote: vote,
      currentRMS: rms,
      quietRatio: quietRatio,
      isStopCandidate: _isStopCandidate,
    ));
  }

  SensorVote _determineVote(double rms, double quietRatio, DateTime timestamp) {
    // High motion detected - definitely driving
    if (rms > _config.drivingRmsThreshold) {
      _resetStopCandidate();
      return SensorVote.driving;
    }

    // Check for stop candidate
    if (!_isStopCandidate) {
      _checkForStopCandidate(rms, quietRatio, timestamp);
    } else {
      _validateStopCandidate(rms, quietRatio);
    }

    // Determine vote based on stop candidate duration
    if (_isStopCandidate && _stopCandidateStartTime != null) {
      final duration = timestamp.difference(_stopCandidateStartTime!).inSeconds;
      return duration >= _config.confirmStillDuration
          ? SensorVote.parked
          : SensorVote.driving;
    }

    return SensorVote.unknown;
  }

  void _checkForStopCandidate(double rms, double quietRatio, DateTime timestamp) {
    final isQuiet = quietRatio >= _config.quietRatioThresholdIn;
    final isStill = rms < _config.stillRmsThresholdIn;

    if (isQuiet && isStill) {
      _stopCandidateStartTime ??= timestamp;
      
      final duration = timestamp.difference(_stopCandidateStartTime!).inSeconds;
      if (duration >= _config.stillForCandidateDuration) {
        _isStopCandidate = true;
      }
    } else {
      _stopCandidateStartTime = null;
    }
  }

  void _validateStopCandidate(double rms, double quietRatio) {
    final isNoLongerQuiet = quietRatio < _config.quietRatioThresholdOut;
    final isNoLongerStill = rms > _config.stillRmsThresholdOut;

    if (isNoLongerQuiet && isNoLongerStill) {
      _resetStopCandidate();
    }
  }

  void _addSample(DateTime timestamp, double magnitude) {
    _window.addLast(AccSample(
      timestamp: timestamp,
      magnitude: magnitude,
    ));
    _sumSquared += magnitude * magnitude;
    
    if (magnitude < _config.quietEpsilon) {
      _quietSampleCount++;
    }
  }

  void _removeOldSamples(DateTime currentTime) {
    final cutoff = currentTime.subtract(
      Duration(seconds: _config.windowSizeSeconds.toInt()),
    );

    while (_window.isNotEmpty && _window.first.timestamp.isBefore(cutoff)) {
      final old = _window.removeFirst();
      _sumSquared -= old.magnitude * old.magnitude;
      
      if (old.magnitude < _config.quietEpsilon) {
        _quietSampleCount--;
      }
    }
  }

  double _calculateRMS() {
    return _window.isEmpty ? 0.0 : math.sqrt(_sumSquared / _window.length);
  }

  double _calculateQuietRatio() {
    return _window.isEmpty ? 0.0 : _quietSampleCount / _window.length;
  }

  void _resetStopCandidate() {
    _isStopCandidate = false;
    _stopCandidateStartTime = null;
  }

  void _onReset(ResetAcc event, Emitter<AccState> emit) {
    _window.clear();
    _sumSquared = 0.0;
    _quietSampleCount = 0;
    _resetStopCandidate();
    _kalmanFilter.reset();
    emit(const AccInitial());
  }

  @override
  Future<void> close() async {
    await _sensorSubscription?.cancel();
    return super.close();
  }
}

class AccConfig {
  final double windowSizeSeconds;
  final double stillRmsThresholdIn;
  final double stillRmsThresholdOut;
  final double drivingRmsThreshold;
  final double quietEpsilon;
  final double quietRatioThresholdIn;
  final double quietRatioThresholdOut;
  final double stillForCandidateDuration;
  final double confirmStillDuration;

  const AccConfig({
    this.stillRmsThresholdIn = 0.40,      // Changed from 0.07 to 0.40
    this.stillRmsThresholdOut = 0.45,     // Changed from 0.1 to 0.45 (maintain hysteresis gap)
    this.drivingRmsThreshold = 0.5,       // Changed from 0.2 to 0.5
    this.quietEpsilon = 0.50,             // Changed from 0.15 to 0.50
    this.quietRatioThresholdIn = 0.7,
    this.quietRatioThresholdOut = 0.58,
    this.stillForCandidateDuration = 3.0, // lower so it triggers faster
    this.confirmStillDuration = 5.0,
    this.windowSizeSeconds = 5.0,
  });
}
