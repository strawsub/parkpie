class AdaptiveKalmanFilter {
  double _estimateLat;
  double _estimateLng;
  double _q = 0.0001; // initial process noise
  double _r = 0.01;   // initial measurement noise
  double _p = 1;      // estimation error
  final double _lambda = 0.95; // smoothing factor for R
  final double _beta = 0.95;   // smoothing factor for Q

  AdaptiveKalmanFilter(double initialLat, double initialLng)
      : _estimateLat = initialLat,
        _estimateLng = initialLng;

  List<double> filter(double lat, double lng) {
    // Predict
    _p = _p + _q;

    // Compute Kalman Gain
    final k = _p / (_p + _r);

    // Compute innovation (residual)
    final vLat = lat - _estimateLat;
    final vLng = lng - _estimateLng;

    // Update estimates
    _estimateLat = _estimateLat + k * vLat;
    _estimateLng = _estimateLng + k * vLng;

    // Update estimation error
    _p = (1 - k) * _p;

    // Adapt measurement noise R and process noise Q
    final innovationVar = (vLat * vLat + vLng * vLng) / 2.0;
    _r = _lambda * _r + (1 - _lambda) * innovationVar;
    _q = _beta * _q + (1 - _beta) * (k * innovationVar);

    return [_estimateLat, _estimateLng];
  }
}
