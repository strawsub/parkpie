import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'parking_status_event.dart';
import 'parking_status_state.dart';
import '../bluetooth_detection/audio_bluetooth_service.dart';

/// Voting-based aggregator:
/// - Accelerometer vote = your sliding-window stillness algorithm
/// - Gyroscope vote = "moving -> driving", otherwise no vote (neutral)
class ParkingBloc extends Bloc<ParkingEvent, ParkingState> {
  // Subscriptions
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<UserAccelerometerEvent>? _accSub;
  StreamSubscription<BluetoothStatus>? _bluetoothSub;
  
  // Bluetooth service
  final AudioBluetoothService _bluetoothService = AudioBluetoothService();

  // Voting map: sensor name -> latest vote
  final Map<String, SensorVote> _votes = {};
  
  // Public getter for current votes (read-only)
  Map<String, SensorVote> get currentVotes => Map.unmodifiable(_votes);

  // Sliding window samples of |a| (gravity removed)
  final ListQueue<_Sample> _win = ListQueue();
  double _sumSq = 0.0;     // sum of squares for RMS
  int _quietCount = 0;     // |a| < quietEps samples in window

  // Substates
  bool _inStopCandidate = false;
  DateTime? _stopCandidateStart;

  // Tunables
  static const double WIN_SEC = 5.0;                 // window seconds
  static const double stillRmsMaxIn  = 0.05;         // enter stillness
  static const double stillRmsMaxOut = 0.07;         // exit stillness (hysteresis)
  static const double driveRmsMin    = 0.08;         // clearly moving

  static const double quietEps      = 0.02;          // quiet amplitude
  static const double quietRatioIn  = 0.80;          // enter stillness
  static const double quietRatioOut = 0.60;          // exit stillness

  static const double T_still_for_candidate = 6.0;   // become candidate
  static const double T_confirm_still       = 30.0;  // confirm parked (no-spike version)

  // Gyro helper: if big rotation -> driving
  static const double gyroMoveThresh = 1.0;          // rad/s approx

  ParkingBloc() : super(UnknownParkingState()) {
    // Handlers
    on<GyroscopeChanged>(_onGyro);
    on<AccelerometerChanged>(_onAcc);
    on<BluetoothAudioChanged>(_onBluetoothAudio);
    on<UserConfirmedParking>((e, emit) => emit(ParkedState()));
    on<ResetParking>((e, emit) {
      emit(DrivingState());
      _clearAll();
    });

    // Subscribe sensors
    _gyroSub = gyroscopeEvents.listen((e) {
      add(GyroscopeChanged(x: e.x, y: e.y, z: e.z));
    });

    // Use user accelerometer (gravity removed)
    _accSub = userAccelerometerEvents.listen((e) {
      add(AccelerometerChanged(x: e.x, y: e.y, z: e.z, t: DateTime.now()));
    });

    // Initialize and subscribe to Bluetooth audio service
    _bluetoothService.initialize().then((_) {
      _bluetoothSub = _bluetoothService.statusStream.listen((status) {
        add(BluetoothAudioChanged(
          isConnected: status.isBluetoothConnected,
          deviceName: status.currentRouteName,
        ));
      });
    }).catchError((e) {
      // Bluetooth service initialization failed, continue without it
      // This ensures the app works even if audio route detection fails
    });
  }

  // --- Voting aggregation ---
  void _updateState(Emitter<ParkingState> emit) {
    // Freeze once user confirmed parked; require Reset to leave.
    if (state is ParkedState) return;

    final drivingVotes =
        _votes.values.where((v) => v == SensorVote.driving).length;
    final parkedVotes  =
        _votes.values.where((v) => v == SensorVote.parked).length;

    if (parkedVotes > drivingVotes) {
      if (state is! ParkingDetectedState && state is! ParkedState) {
        emit(ParkingDetectedState());
      }
    } else if (drivingVotes > parkedVotes) {
      if (state is! DrivingState) emit(DrivingState());
    } else {
      // tie or no votes
      if (state is UnknownParkingState) {
        emit(DrivingState()); // startup fallback
      }
    }
  }


  // --- Gyro: strong rotation -> driving; otherwise be neutral (no vote) ---
  void _onGyro(GyroscopeChanged e, Emitter<ParkingState> emit) {
    final moving = e.x.abs() > gyroMoveThresh ||
        e.y.abs() > gyroMoveThresh ||
        e.z.abs() > gyroMoveThresh;
    if (moving) {
      _votes['gyroscope'] = SensorVote.driving;
    } else {
      // neutral: remove its vote so it doesn't bias towards parked
      _votes.remove('gyroscope');
    }
    _updateState(emit);
  }

  // --- Accelerometer: your stillness algorithm as a vote ---
  void _onAcc(AccelerometerChanged e, Emitter<ParkingState> emit) {
    final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    _appendSample(e.t, mag);
    _evictOld(e.t);
    if (_win.isEmpty) return;

    final rms = _currentRms();
    final qRatio = _quietCount / _win.length; // 0..1
    final now = e.t;

    // clearly moving -> vote driving and reset internal stillness
    if (rms > driveRmsMin) {
      _votes['accelerometer'] = SensorVote.driving;
      _inStopCandidate = false;
      _stopCandidateStart = null;
      _updateState(emit);
      return;
    }

    // candidate enter/maintain with hysteresis and quiet ratio
    final quietHit  = qRatio >= quietRatioIn;
    final rmsHit    = rms < stillRmsMaxIn;
    final quietLost = qRatio <= quietRatioOut;
    final rmsLost   = rms > stillRmsMaxOut;

    if (!_inStopCandidate) {
      if (quietHit || rmsHit) {
        _stopCandidateStart ??= now;
        final dt = _secsSince(_stopCandidateStart!, now);
        if (dt >= T_still_for_candidate) {
          _inStopCandidate = true;
        }
      } else {
        _stopCandidateStart = null;
      }
    } else {
      if (quietLost && rmsLost) {
        _inStopCandidate = false;
        _stopCandidateStart = null;
      }
    }

    // vote based on total stillness since candidate start
    if (_inStopCandidate && _stopCandidateStart != null) {
      final dtAll = _secsSince(_stopCandidateStart!, now);
      if (dtAll >= T_confirm_still && (quietHit || rmsHit)) {
        _votes['accelerometer'] = SensorVote.parked;
      } else {
        _votes['accelerometer'] = SensorVote.driving;
      }
    } else {
      _votes['accelerometer'] = SensorVote.driving;
    }

    _updateState(emit);
  }

  // --- Bluetooth Audio: connection state -> driving/parked vote ---
  void _onBluetoothAudio(BluetoothAudioChanged e, Emitter<ParkingState> emit) {
    // Previous state for comparison
    final hadBluetoothVote = _votes.containsKey('bluetooth_audio');
    final previouslyConnected = hadBluetoothVote ? _votes['bluetooth_audio'] == SensorVote.driving : false;
    
    if (e.isConnected) {
      // User connected to Bluetooth audio (likely getting in car) -> driving
      _votes['bluetooth_audio'] = SensorVote.driving;
    } else if (previouslyConnected) {
      // User was connected and now disconnected (likely parked/turned off car) -> parked
      _votes['bluetooth_audio'] = SensorVote.parked;
    } else {
      // No Bluetooth device connected and wasn't connected before -> neutral (no vote)
      _votes.remove('bluetooth_audio');
    }
    _updateState(emit);
  }

  // ==== sliding window helpers ====
  void _appendSample(DateTime t, double mag) {
    _win.addLast(_Sample(t, mag));
    _sumSq += mag * mag;
    if (mag < quietEps) _quietCount += 1;
  }

  void _evictOld(DateTime now) {
    final cutoff = now.millisecondsSinceEpoch - (WIN_SEC * 1000).toInt();
    while (_win.isNotEmpty && _win.first.t.millisecondsSinceEpoch < cutoff) {
      final old = _win.removeFirst();
      _sumSq -= old.mag * old.mag;
      if (old.mag < quietEps) _quietCount -= 1;
    }
  }

  double _currentRms() {
    if (_win.isEmpty) return 0.0;
    return math.sqrt(_sumSq / _win.length);
  }

  double _secsSince(DateTime from, DateTime to) =>
      to.difference(from).inMilliseconds / 1000.0;

  void _clearAll() {
    _votes.clear();
    _win.clear();
    _sumSq = 0.0;
    _quietCount = 0;
    _inStopCandidate = false;
    _stopCandidateStart = null;
  }

  @override
  Future<void> close() async {
    await _gyroSub?.cancel();
    await _accSub?.cancel();
    await _bluetoothSub?.cancel();
    await _bluetoothService.dispose();
    return super.close();
  }
}

// Votes
enum SensorVote { driving, parked }

class _Sample {
  final DateTime t;
  final double mag;
  _Sample(this.t, this.mag);
}