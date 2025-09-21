class KalmanFilter {
  double _estimateLat;
  double _estimateLng;
  final double _q = 0.0001; // process noise
  final double _r = 0.01;   // measurement noise
  double _p = 1;            // estimation error

  KalmanFilter(double initialLat, double initialLng)
      : _estimateLat = initialLat,
        _estimateLng = initialLng;

  List<double> filter(double lat, double lng) {
    _p = _p + _q;
    double k = _p / (_p + _r);
    _estimateLat = _estimateLat + k * (lat - _estimateLat);
    _estimateLng = _estimateLng + k * (lng - _estimateLng);
    _p = (1 - k) * _p;

    return [_estimateLat, _estimateLng];
  }
}
