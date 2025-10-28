import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'gyro_event.dart';
import 'gyro_state.dart';
import '../utils.dart';

class GyroBloc extends Bloc<GyroEvent, GyroState> {
  // Configuration
  static const _windowSizeSeconds = 3.0;
  static const _movementThreshold = 0.8;

  // Kalman filter
  final KalmanFilter3D _kalmanFilter = KalmanFilter3D(
    processNoise: 0.002,
    measurementNoise: 0.08,
  );

  // Sample window
  final ListQueue<GyroSample> _window = ListQueue();

  // Sensor subscription
  StreamSubscription<GyroscopeEvent>? _sensorSubscription;

  GyroBloc() : super(const GyroInitial()) {
    on<GyroDataReceived>(_onDataReceived);
    on<ResetGyro>(_onReset);
    _initializeSensor();
  }

  void _initializeSensor() {
    _sensorSubscription = gyroscopeEventStream().listen(
      (event) {
        add(GyroDataReceived(
          x: event.x,
          y: event.y,
          z: event.z,
          timestamp: DateTime.now(),
        ));
      },
      onError: (error) {
        // debugPrint('Gyroscope sensor error: $error');
      },
    );
  }

  void _onDataReceived(
    GyroDataReceived event,
    Emitter<GyroState> emit,
  ) {
    // Apply Kalman filtering
    final (fx, fy, fz) = _kalmanFilter.filter(event.x, event.y, event.z);

    // Add to window
    _window.addLast(GyroSample(
      timestamp: event.timestamp,
      x: fx,
      y: fy,
      z: fz,
    ));

    // Remove old samples
    _removeOldSamples(event.timestamp);

    if (_window.isEmpty) return;

    // Calculate max rotation in window
    final maxRotation = _calculateMaxRotation();

    // Determine vote (high rotation = phone movement = getting out of car = parked)
    final vote = maxRotation > _movementThreshold
        ? SensorVote.parked
        : SensorVote.driving;

    emit(GyroReading(
      vote: vote,
      maxRotation: maxRotation,
    ));
  }

  void _removeOldSamples(DateTime currentTime) {
    final cutoff = currentTime.subtract(
      Duration(seconds: _windowSizeSeconds.toInt()),
    );

    while (_window.isNotEmpty && _window.first.timestamp.isBefore(cutoff)) {
      _window.removeFirst();
    }
  }

  double _calculateMaxRotation() {
    double maxRotation = 0.0;
    for (final sample in _window) {
      maxRotation = math.max(maxRotation, sample.magnitude);
    }
    return maxRotation;
  }

  void _onReset(ResetGyro event, Emitter<GyroState> emit) {
    _window.clear();
    _kalmanFilter.reset();
    emit(const GyroInitial());
  }

  @override
  Future<void> close() async {
    await _sensorSubscription?.cancel();
    return super.close();
  }
}
