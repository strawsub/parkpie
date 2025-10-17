import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../utils.dart';
import 'gps_speed_event.dart';
import 'gps_speed_state.dart';
import 'gps_speed_config.dart';

class LocationSample {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;

  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });
}

class GpsSpeedBloc extends Bloc<GpsSpeedEvent, GpsSpeedState> {
  // Configuration
  static const _config = GpsSpeedConfig();

  // Kalman filter for speed smoothing
  final KalmanFilter1D _speedFilter = KalmanFilter1D(
    processNoise: _config.processNoise,
    measurementNoise: _config.measurementNoise,
  );

  // Sliding window of location samples
  final ListQueue<LocationSample> _window = ListQueue();

  // State tracking for time-based confirmation
  DateTime? _parkedCandidateStartTime;
  DateTime? _drivingCandidateStartTime;
  DateTime? _lastUpdateTime; // Track last update for minimum interval

  // Linear distance tracking for driving confirmation (piecewise segments)
  LocationSample? _drivingDistanceStartSample; // First sample when speed >= vOut
  double _drivingLinearDistance = 0.0; // Accumulated piecewise segment distances
  LocationSample? _lastDrivingSegmentSample; // Last sample used for piecewise distance

  // Initialization tracking
  DateTime? _startTime;
  bool _isInitializing = true;

  // Outlier detection parameters
  static const double _maxReasonableSpeed = 50.0; // m/s (~180 km/h)
  static const double _minReasonableSpeed = 0.0;

  // GPS subscription
  StreamSubscription<Position>? _positionSubscription;

  GpsSpeedBloc() : super(const GpsSpeedInitial()) {
    on<GpsSpeedLocationSampleArrived>(_onLocationSampleArrived);
    on<GpsSpeedReset>(_onReset);
    _startTime = DateTime.now();
    _initializeGps();
  }

  Future<void> _initializeGps() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('GPS location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('GPS location permission denied forever');
        return;
      }

      // Start listening to position updates
      // Dynamic sampling: dense during initialization (0m filter), then relaxed (1m filter)
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _config.distanceFilterInitialization, // Start with 0m for dense sampling
        // Note: No timeLimit set - allows GPS time to acquire initial fix
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) {
          add(GpsSpeedLocationSampleArrived(
            lat: position.latitude,
            lon: position.longitude,
            horizAcc: position.accuracy,
            timestamp: position.timestamp,
          ));
        },
        onError: (error) {
          debugPrint('GPS position error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize GPS: $e');
    }
  }

  void _onLocationSampleArrived(
    GpsSpeedLocationSampleArrived event,
    Emitter<GpsSpeedState> emit,
  ) {
    // Check if initialization period has ended and switch to normal sampling
    if (_isInitializing && _startTime != null) {
      final elapsed = event.timestamp.difference(_startTime!).inMilliseconds / 1000.0;
      if (elapsed >= _config.initializationDuration) {
        _isInitializing = false;
        // Note: Cannot dynamically change location settings in Geolocator stream
        // This flag is used for logic adjustments only
        debugPrint('GPS initialization complete, switching to normal mode');
      }
    }

    // Check minimum update interval to prevent timer stalling
    if (_lastUpdateTime != null) {
      final timeSinceLastUpdate = event.timestamp.difference(_lastUpdateTime!).inMilliseconds / 1000.0;
      if (timeSinceLastUpdate < _config.minUpdateInterval) {
        // Too soon, skip this sample to avoid over-processing
        return;
      }
    }
    _lastUpdateTime = event.timestamp;

    // Check GPS accuracy - allow null (Web), reject only if accuracy is too poor
    // Relaxed threshold (50m) to accept samples during cold start
    final acc = event.horizAcc;
    final isReliable = (acc == null) || (acc <= _config.maxAccuracyThreshold);

    if (!isReliable) {
      debugPrint('GPS sample rejected: accuracy ${acc.toStringAsFixed(1)}m > ${_config.maxAccuracyThreshold}m');
      return;
    }

    // Add new sample to window
    final sample = LocationSample(
      latitude: event.lat,
      longitude: event.lon,
      timestamp: event.timestamp,
      accuracy: event.horizAcc,
    );
    _window.addLast(sample);

    // Remove old samples outside the time/distance window
    _pruneWindow(event.timestamp);

    // Need at least 2 samples to calculate speed
    if (_window.length < 2) {
      return;
    }

    // Calculate instantaneous speed from last two samples
    final lastSample = _window.last;
    final prevSample = _window.elementAt(_window.length - 2);

    final distance = _calculateDistance(
      prevSample.latitude,
      prevSample.longitude,
      lastSample.latitude,
      lastSample.longitude,
    );

    final timeDiff = lastSample.timestamp.difference(prevSample.timestamp).inMilliseconds / 1000.0;

    if (timeDiff <= 0) {
      return; // Avoid division by zero
    }

    final rawSpeed = distance / timeDiff;

    // Discard outliers (stricter check for unrealistic speeds)
    // Also check: if accuracy is very poor, lower the max reasonable speed
    final maxSpeedForAccuracy = (event.horizAcc != null && event.horizAcc! > 30.0)
        ? 15.0  // Poor GPS (>30m accuracy): max 15 m/s (~54 km/h)
        : _maxReasonableSpeed;  // Good GPS: max 50 m/s (~180 km/h)

    if (rawSpeed < _minReasonableSpeed || rawSpeed > maxSpeedForAccuracy) {
      debugPrint('GPS speed outlier discarded: ${rawSpeed.toStringAsFixed(2)} m/s (accuracy: ${event.horizAcc?.toStringAsFixed(1) ?? "null"}m)');
      _window.removeLast(); // Remove the outlier sample
      return;
    }

    // Smooth speed using Kalman filter
    double filteredSpeed = _speedFilter.filter(rawSpeed);

    // Zero-speed detection: Suppress GPS drift when stationary
    // If speed is very low AND GPS accuracy is poor, force speed to 0
    if (filteredSpeed < _config.zeroSpeedThreshold &&
        (event.horizAcc == null || event.horizAcc! > _config.zeroSpeedAccuracyThreshold)) {
      filteredSpeed = 0.0; // Force to zero (GPS drift, not real movement)
    }

    // Calculate accuracy-weighted window displacement
    final windowStats = _calculateWeightedWindowStats();

    // Determine accuracy scenario
    final accuracyScenario = _determineAccuracyScenario(event.horizAcc);

    // Determine vote using BOTH rawSpeed (for candidate start) and filteredSpeed (for confirmation)
    final vote = _determineVote(
      rawSpeed,           // Use raw for early candidate detection
      filteredSpeed,      // Use filtered for confirmation
      windowStats.displacement,
      event.timestamp,
      accuracyScenario,
    );

    // Calculate candidate seconds
    final candidateSeconds = _getCandidateSeconds(event.timestamp);

    // Debug logging
    // debugPrint('GPS: raw=${rawSpeed.toStringAsFixed(2)}m/s, '
    //     'filtered=${filteredSpeed.toStringAsFixed(2)}m/s, '
    //     'disp=${windowStats.displacement.toStringAsFixed(1)}m, '
    //     'acc=${event.horizAcc?.toStringAsFixed(1) ?? "null"}m, '
    //     'scenario=$accuracyScenario, '
    //     'vote=${vote.toString().split('.').last}, '
    //     'candidate=${candidateSeconds.toStringAsFixed(1)}s');

    emit(GpsSpeedReading(
      vote: vote,
      rawSpeed: rawSpeed,
      filteredSpeed: filteredSpeed,
      windowDisplacement: windowStats.displacement,
      candidateSeconds: candidateSeconds,
      accuracy: event.horizAcc,
      accuracyScenario: accuracyScenario,
    ));
  }

  void _pruneWindow(DateTime currentTime) {
    if (_window.isEmpty) return;

    // Prune based on time: keep enough history for both parking and driving detection
    // Use max of all scenario timers + margin for flexibility
    const marginSeconds = 2.0; // Safety buffer for irregular GPS samples
    final maxTime = math.max(
      math.max(_config.tConfirmGood, _config.tConfirmMedium),
      math.max(_config.tConfirmPoor, _config.tCandidateGood)
    ) + marginSeconds;
    final maxWindowDuration = Duration(milliseconds: (maxTime * 1000).toInt());
    final cutoffTime = currentTime.subtract(maxWindowDuration);

    while (_window.isNotEmpty && _window.first.timestamp.isBefore(cutoffTime)) {
      _window.removeFirst();
    }

    // Prune based on cumulative displacement: remove old samples if path exceeds dWindow
    if (_window.length >= 2) {
      while (_window.length > 2) {
        // Calculate cumulative displacement from oldest to newest
        double cumulativeDisplacement = 0.0;
        for (int i = 0; i < _window.length - 1; i++) {
          final current = _window.elementAt(i);
          final next = _window.elementAt(i + 1);
          cumulativeDisplacement += _calculateDistance(
            current.latitude,
            current.longitude,
            next.latitude,
            next.longitude,
          );
        }

        // If cumulative path exceeds max dWindow threshold (use largest), remove oldest sample
        final maxDWindow = math.max(
          math.max(_config.dWindowGood, _config.dWindowMedium),
          _config.dWindowPoor
        );
        if (cumulativeDisplacement > maxDWindow) {
          _window.removeFirst();
        } else {
          break;
        }
      }
    }
  }

  /// Determine accuracy scenario: "good", "medium", or "poor"
  String _determineAccuracyScenario(double? accuracy) {
    if (accuracy == null) return "good"; // Assume good for null (web)
    if (accuracy <= _config.goodAccuracyThreshold) return "good";
    if (accuracy <= _config.mediumAccuracyThreshold) return "medium";
    return "poor";
  }

  /// Calculate sample weight based on accuracy
  /// Returns 1.0 for good accuracy, reduced weight for poor accuracy
  double _calculateSampleWeight(double? accuracy) {
    if (accuracy == null) return 1.0; // Full weight for null (web)
    if (accuracy <= _config.accuracyWeightThreshold) return 1.0; // Full weight

    // Linear decay from 1.0 to minSampleWeight as accuracy worsens
    final excessAccuracy = accuracy - _config.accuracyWeightThreshold;
    final maxExcess = _config.maxAccuracyThreshold - _config.accuracyWeightThreshold;
    final decayFactor = (excessAccuracy / maxExcess).clamp(0.0, 1.0);

    return 1.0 - (decayFactor * (1.0 - _config.minSampleWeight));
  }

  /// Calculate accuracy-weighted displacement (down-weight poor accuracy samples)
  ({double displacement, double duration}) _calculateWeightedWindowStats() {
    if (_window.length < 2) {
      return (displacement: 0.0, duration: 0.0);
    }

    final firstSample = _window.first;
    final lastSample = _window.last;

    // Calculate weighted displacement: sum of pairwise distances with accuracy weighting
    double totalWeightedDisplacement = 0.0;
    double totalWeight = 0.0;

    for (int i = 0; i < _window.length - 1; i++) {
      final current = _window.elementAt(i);
      final next = _window.elementAt(i + 1);

      final segmentDistance = _calculateDistance(
        current.latitude,
        current.longitude,
        next.latitude,
        next.longitude,
      );

      // Weight by average accuracy of the two samples
      final weight1 = _calculateSampleWeight(current.accuracy);
      final weight2 = _calculateSampleWeight(next.accuracy);
      final avgWeight = (weight1 + weight2) / 2.0;

      totalWeightedDisplacement += segmentDistance * avgWeight;
      totalWeight += avgWeight;
    }

    // Normalize by total weight to get effective displacement
    final effectiveDisplacement = totalWeight > 0 ? totalWeightedDisplacement / totalWeight : 0.0;

    // Calculate total duration
    final duration = lastSample.timestamp.difference(firstSample.timestamp).inMilliseconds / 1000.0;

    return (displacement: effectiveDisplacement, duration: duration);
  }

  double _getCandidateSeconds(DateTime timestamp) {
    if (_parkedCandidateStartTime != null) {
      return timestamp.difference(_parkedCandidateStartTime!).inMilliseconds / 1000.0;
    } else if (_drivingCandidateStartTime != null) {
      return timestamp.difference(_drivingCandidateStartTime!).inMilliseconds / 1000.0;
    }
    return 0.0;
  }

  SensorVote _determineVote(
    double rawSpeed,
    double filteredSpeed,
    double displacement,
    DateTime timestamp,
    String scenario,
  ) {
    // Select thresholds based on accuracy scenario
    final double vIn, vOut, tCandidate, tConfirm, dWindow;

    switch (scenario) {
      case "good":
        vIn = _config.vInGood;
        vOut = _config.vOutGood;
        tCandidate = _config.tCandidateGood;
        tConfirm = _config.tConfirmGood;
        dWindow = _config.dWindowGood;
        break;
      case "medium":
        vIn = _config.vInMedium;
        vOut = _config.vOutMedium;
        tCandidate = _config.tCandidateMedium;
        tConfirm = _config.tConfirmMedium;
        dWindow = _config.dWindowMedium;
        break;
      case "poor":
      default:
        vIn = _config.vInPoor;
        vOut = _config.vOutPoor;
        tCandidate = _config.tCandidatePoor;
        tConfirm = _config.tConfirmPoor;
        dWindow = _config.dWindowPoor;
        break;
    }

    // Check for driving speed using RAW speed for early candidate start
    // Use FILTERED speed for confirmation to avoid false positives

    // START candidate if RAW speed crosses threshold (fast response)
    if (rawSpeed >= vOut + _config.rawSpeedMargin) {  // 4.6 m/s with margin
      _parkedCandidateStartTime = null;

      // Start or continue driving candidate
      _drivingCandidateStartTime ??= timestamp;

      // Track piecewise linear distance (sum of segments, not single chord)
      if (_drivingDistanceStartSample == null && _window.isNotEmpty) {
        _drivingDistanceStartSample = _window.last;
        _lastDrivingSegmentSample = _window.last;
        _drivingLinearDistance = 0.0;
      } else if (_lastDrivingSegmentSample != null && _window.isNotEmpty) {
        // Add this segment's distance to total
        final segmentDistance = _calculateDistance(
          _lastDrivingSegmentSample!.latitude,
          _lastDrivingSegmentSample!.longitude,
          _window.last.latitude,
          _window.last.longitude,
        );
        _drivingLinearDistance += segmentDistance;
        _lastDrivingSegmentSample = _window.last;
      }

      final durDriving = timestamp.difference(_drivingCandidateStartTime!).inMilliseconds / 1000.0;

      // CONFIRM with FILTERED speed and distance (avoid noise spikes)
      if (durDriving >= tCandidate &&
          filteredSpeed >= vOut &&
          _drivingLinearDistance > _config.dDrivingThreshold) {
        return SensorVote.driving;
      }
      return SensorVote.unknown;
    }

    // Check for parked: BOTH low speed AND small displacement required (scenario-aware)
    if (filteredSpeed <= vIn && displacement <= dWindow) {
      _drivingCandidateStartTime = null;
      _drivingDistanceStartSample = null;
      _lastDrivingSegmentSample = null;
      _drivingLinearDistance = 0.0;

      // Start or continue parked candidate
      _parkedCandidateStartTime ??= timestamp;
      final durParked = timestamp.difference(_parkedCandidateStartTime!).inMilliseconds / 1000.0;

      if (durParked >= tConfirm) {
        return SensorVote.parked;
      }
      return SensorVote.unknown;
    }

    // Speed in middle range (between vIn and vOut)
    // KEEP driving candidate alive if it exists (don't reset)
    // This prevents oscillation when speed fluctuates while driving
    if (_drivingCandidateStartTime != null) {
      // Continue tracking piecewise distance if we have a driving candidate
      if (_lastDrivingSegmentSample != null && _window.isNotEmpty) {
        // Add this segment's distance to total
        final segmentDistance = _calculateDistance(
          _lastDrivingSegmentSample!.latitude,
          _lastDrivingSegmentSample!.longitude,
          _window.last.latitude,
          _window.last.longitude,
        );
        _drivingLinearDistance += segmentDistance;
        _lastDrivingSegmentSample = _window.last;
      }

      final durDriving = timestamp.difference(_drivingCandidateStartTime!).inMilliseconds / 1000.0;

      // Check if we've met the driving criteria (use filtered speed for confirmation)
      if (durDriving >= tCandidate &&
          filteredSpeed >= vOut &&
          _drivingLinearDistance > _config.dDrivingThreshold) {
        return SensorVote.driving;
      }
      return SensorVote.unknown;
    }

    // No active candidates, speed in middle range
    return SensorVote.unknown;
  }

  void _resetCandidates() {
    _parkedCandidateStartTime = null;
    _drivingCandidateStartTime = null;
    _drivingDistanceStartSample = null;
    _lastDrivingSegmentSample = null;
    _drivingLinearDistance = 0.0;
  }

  /// Calculate distance between two GPS coordinates using Haversine formula
  /// Returns distance in meters
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // Earth's radius in meters

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  void _onReset(GpsSpeedReset event, Emitter<GpsSpeedState> emit) {
    _window.clear();
    _resetCandidates();
    _speedFilter.reset();
    _lastUpdateTime = null;
    _startTime = DateTime.now();
    _isInitializing = true;
    emit(const GpsSpeedInitial());
  }

  @override
  Future<void> close() async {
    await _positionSubscription?.cancel();
    return super.close();
  }
}
