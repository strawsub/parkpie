// Utilities shared by sensor handlers: Kalman filter, vote enum, sample

import 'dart:math' as math;

class KalmanFilter1D {
  double _estimate = 0.0;
  double _errorCovariance = 1.0;

  final double processNoise;
  final double measurementNoise;

  KalmanFilter1D({
    this.processNoise = 0.001,
    this.measurementNoise = 0.1,
  });

  double filter(double measurement) {
    // Prediction
    _errorCovariance += processNoise;

    // Update
    final kalmanGain = _errorCovariance / (_errorCovariance + measurementNoise);
    _estimate += kalmanGain * (measurement - _estimate);
    _errorCovariance *= (1 - kalmanGain);

    return _estimate;
  }

  void reset() {
    _estimate = 0.0;
    _errorCovariance = 1.0;
  }
}

class KalmanFilter3D {
  final KalmanFilter1D _xFilter;
  final KalmanFilter1D _yFilter;
  final KalmanFilter1D _zFilter;

  KalmanFilter3D({
    double processNoise = 0.001,
    double measurementNoise = 0.1,
  })  : _xFilter = KalmanFilter1D(
          processNoise: processNoise,
          measurementNoise: measurementNoise,
        ),
        _yFilter = KalmanFilter1D(
          processNoise: processNoise,
          measurementNoise: measurementNoise,
        ),
        _zFilter = KalmanFilter1D(
          processNoise: processNoise,
          measurementNoise: measurementNoise,
        );

  (double x, double y, double z) filter(double x, double y, double z) {
    return (
      _xFilter.filter(x),
      _yFilter.filter(y),
      _zFilter.filter(z),
    );
  }

  void reset() {
    _xFilter.reset();
    _yFilter.reset();
    _zFilter.reset();
  }
}


enum SensorVote {
  driving,
  parked,
  unknown;

  bool get isDriving => this == SensorVote.driving;
  bool get isParked => this == SensorVote.parked;
  bool get isUnknown => this == SensorVote.unknown;
}

class AccSample {
  final DateTime timestamp;
  final double magnitude;

  const AccSample({
    required this.timestamp,
    required this.magnitude,
  });
}

class GyroSample {
  final DateTime timestamp;
  final double x;
  final double y;
  final double z;

  const GyroSample({
    required this.timestamp,
    required this.x,
    required this.y,
    required this.z,
  });

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}
