import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/parking_status_detection/accelerometer/acc_bloc.dart';
import 'package:frontend/features/parking_status_detection/accelerometer/acc_state.dart';
import 'package:frontend/features/parking_status_detection/accelerometer/acc_event.dart';
import 'package:frontend/features/parking_status_detection/gyroscope/gyro_bloc.dart';
import 'package:frontend/features/parking_status_detection/gyroscope/gyro_state.dart';
import 'package:frontend/features/parking_status_detection/gyroscope/gyro_event.dart';
import 'package:frontend/features/parking_status_detection/bluetooth/bluetooth_bloc.dart';
import 'package:frontend/features/parking_status_detection/bluetooth/bluetooth_state.dart';
import 'package:frontend/features/parking_status_detection/bluetooth/bluetooth_event.dart';
import 'package:frontend/features/parking_status_detection/gps/gps_speed_bloc.dart';
import 'package:frontend/features/parking_status_detection/gps/gps_speed_state.dart';
import 'package:frontend/features/parking_status_detection/gps/gps_speed_event.dart';
import 'package:frontend/features/parking_status_detection/parking_status_event.dart';
import 'package:frontend/features/parking_status_detection/parking_status_state.dart';
import 'package:frontend/features/parking_status_detection/utils.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class ParkingBloc extends Bloc<ParkingEvent, ParkingState>{
  // Sensor blocs
  final GyroBloc gyroBloc;
  final AccBloc accBloc;
  final BluetoothBloc bluetoothBloc;
  final GpsSpeedBloc gpsSpeedBloc;

  // Subscriptions
  StreamSubscription<GyroState>? _gyroSubscription;
  StreamSubscription<AccState>? _accSubscription;
  StreamSubscription<BluetoothState>? _bluetoothSubscription;
  StreamSubscription<GpsSpeedState>? _gpsSpeedSubscription;

  // Configuration - Timers
  static const Duration _periodicTickInterval = Duration(milliseconds: 1500); // Wall-clock timer
  static const Duration _candidateTimeout = Duration(seconds: 60); // T_limit: auto-promote after 60s

  // Timers
  Timer? _parkingDetectionTimer;
  Timer? _candidateProgressTimer;

  ParkingBloc({
    required this.gyroBloc,
    required this.accBloc,
    required this.bluetoothBloc,
    required this.gpsSpeedBloc,
  }) : super(const ParkingUnknown()) {
    on<UpdateSensorVote>(_onUpdateSensorVote);
    on<UserConfirmedParking>(_onUserConfirmedParking);
    on<ResetParking>(_onResetParking);
    on<RevertToDriving>(_onRevertToDriving);
    on<CandidateProgressTick>(_onCandidateProgressTick);
    on<TriggerTestParkingDetection>(_onTriggerTestParkingDetection);

    _initializeSensorListeners();
  }

  void _initializeSensorListeners() {
    // Listen to gyroscope state changes
    _gyroSubscription = gyroBloc.stream.listen((gyroState) {
      if (gyroState is GyroReading) {
        add(UpdateSensorVote(
          sensorName: 'gyroscope',
          vote: gyroState.vote,
        ));
      }
    });

    // Listen to accelerometer state changes
    _accSubscription = accBloc.stream.listen((accState) {
      if (accState is AccReading) {
        add(UpdateSensorVote(
          sensorName: 'accelerometer',
          vote: accState.vote,
        ));
      }
    });

    // Listen to Bluetooth state changes
    _bluetoothSubscription = bluetoothBloc.stream.listen((bluetoothState) {
      // Listen to all bluetooth states (including BluetoothInitial for reset)
      add(UpdateSensorVote(
        sensorName: 'bluetooth',
        vote: bluetoothState.vote,
      ));
    });

    // Listen to GPS speed sta te changes
    _gpsSpeedSubscription = gpsSpeedBloc.stream.listen((gpsSpeedState) {
      if (gpsSpeedState is GpsSpeedReading) {
        add(UpdateSensorVote(
          sensorName: 'gps_speed',
          vote: gpsSpeedState.vote,
        ));
      }
    });
  }

  void _onUpdateSensorVote(
      UpdateSensorVote event,
      Emitter<ParkingState> emit,
      ) {
    // IGNORE sensor votes when in Parked state (terminal state)
    if (state is Parked) {
      return;  // Don't process sensor votes in terminal state
    }

    // IGNORE sensor votes when in ParkingDetected state (awaiting user confirmation)
    if (state is ParkingDetected) {
      return;  // Don't process sensor votes while showing confirmation dialog
    }

    // Update sensor votes
    final updatedVotes = Map<String, SensorVote>.from(state.sensorVotes);

    // CONDITIONAL GYRO VOTING: Only use gyro in StoppedCandidate state
    if (event.sensorName == 'gyroscope' && event.vote == SensorVote.parked) {
      if (state is StoppedCandidate) {
        // Only accept gyro spike in StoppedCandidate - triggers immediate promotion
        updatedVotes[event.sensorName] = event.vote;
      } else {
        // Ignore gyro spike in all other states (Unknown/Driving/ParkingDetected/Parked)
        updatedVotes[event.sensorName] = SensorVote.unknown;
      }
    } else {
      updatedVotes[event.sensorName] = event.vote;
    }

    // Count votes
    int parkedVotes = 0;
    int drivingVotes = 0;

    for (final vote in updatedVotes.values) {
      if (vote == SensorVote.parked) {
        parkedVotes++;
      } else if (vote == SensorVote.driving) {
        drivingVotes++;
      }
    }

    // Determine new state based on voting
    final newState = _determineState(
      updatedVotes,
      parkedVotes,
      drivingVotes,
    );

    emit(newState);
  }

  ParkingState _determineState(
      Map<String, SensorVote> sensorVotes,
      int parkedVotes,
      int drivingVotes,
      ) {
    final now = DateTime.now();

    // Helper: Check stopped condition (GPS + IMU)
    final gpsVote = sensorVotes['gps_speed'] ?? SensorVote.unknown;
    final accVote = sensorVotes['accelerometer'] ?? SensorVote.unknown;
    final isLowSpeed = gpsVote == SensorVote.parked;
    final isNotDriving = gpsVote != SensorVote.driving;  // unknown or parked = not actively driving
    final isStill = accVote == SensorVote.parked;
    final isStopped = isLowSpeed && isStill;  // For strict checks (like timeout condition)
    final isStoppedOrSlowing = isNotDriving && isStill;  // For Driving→StoppedCandidate transition

    // Helper: Check for leave-vehicle evidence
    final gyroVote = sensorVotes['gyroscope'] ?? SensorVote.unknown;
    final btVote = sensorVotes['bluetooth'] ?? SensorVote.unknown;
    final hasGyroSpike = gyroVote == SensorVote.parked;
    final hasBtDisconnect = btVote == SensorVote.parked;

    // Helper: Get current accelerometer RMS for hysteresis
    final accState = accBloc.state;
    double currentAccRMS = 0.0;
    if (accState is AccReading) {
      currentAccRMS = accState.currentRMS ?? 0.0;
    }

    // Helper: Check GPS staleness
    final gpsState = gpsSpeedBloc.state;
    final isGpsStale = gpsState is! GpsSpeedReading;

    // ------------------------------
    // UNKNOWN → DRIVING
    // ------------------------------
    if (state is ParkingUnknown) {
      // Only GPS detection: speed ≥ 4.1 m/s AND distance > 10m for 3s
      if (gpsVote == SensorVote.driving) {
        return Driving(
          sensorVotes: sensorVotes,
          drivingVotes: drivingVotes,
          parkedVotes: parkedVotes,
        );
      }
      // Stay in Unknown until GPS confirms driving
    }

    // ------------------------------
    // DRIVING → STOPPED CANDIDATE
    // ------------------------------
    if (state is Driving) {
      // Transition when GPS is not actively voting "driving" AND accelerometer is still
      // This allows transition even when GPS votes "unknown" (waiting for parked confirmation)
      if (isStoppedOrSlowing) {
        // NO BT fast path from Driving - always enter StoppedCandidate first
        _startCandidateProgressTimer();
        return StoppedCandidate(
          sensorVotes: sensorVotes,
          drivingVotes: drivingVotes,
          parkedVotes: parkedVotes,
          candidateStartTime: now,
          latchedGyroSpikeTime: null, // No longer used (no freeze mechanism)
        );
      }

      // Stay in Driving state (don't fall through to Unknown)
      return Driving(
        sensorVotes: sensorVotes,
        drivingVotes: drivingVotes,
        parkedVotes: parkedVotes,
      );
    }

    // ------------------------------
    // STOPPED CANDIDATE (Complex logic)
    // ------------------------------
    if (state is StoppedCandidate) {
      final candidateState = state as StoppedCandidate;

      // 1. CHECK FOR REVERT TO DRIVING (with hysteresis)
      final shouldRevert = _checkRevertConditions(
        sensorVotes,
        currentAccRMS,
        isGpsStale,
        now,
      );

      if (shouldRevert) {
        _cancelCandidateProgressTimer();
        _resetRevertTracking();
        return Driving(
          sensorVotes: sensorVotes,
          drivingVotes: drivingVotes,
          parkedVotes: parkedVotes,
        );
      }

      // 2. CHECK FOR BT DISCONNECT (instant promotion in StoppedCandidate)
      // Accept bluetooth disconnect even if not fully stopped yet (transitioning)

      // DEBUG LOGGING
      debugPrint('=== BLUETOOTH DISCONNECT CHECK ===');
      debugPrint('Current state: StoppedCandidate');
      debugPrint('btVote: ${sensorVotes['bluetooth']}');
      debugPrint('hasBtDisconnect: $hasBtDisconnect');
      debugPrint('All sensor votes: $sensorVotes');
      debugPrint('===================================');

      if (hasBtDisconnect) {
        debugPrint('>>> BLUETOOTH DISCONNECT DETECTED - Transitioning to ParkingDetected');
        _cancelCandidateProgressTimer();
        // No auto-confirm timer - stay in ParkingDetected until user confirms
        return ParkingDetected(
          sensorVotes: sensorVotes,
          drivingVotes: drivingVotes,
          parkedVotes: parkedVotes,
        );
      }

      // 3. GYRO SPIKE LOGIC: Instant Promotion (no freeze window)
      if (hasGyroSpike) {
        _cancelCandidateProgressTimer();
        // Immediate promotion to ParkingDetected on gyro spike
        return ParkingDetected(
          sensorVotes: sensorVotes,
          drivingVotes: drivingVotes,
          parkedVotes: parkedVotes,
        );
      }

      // 4. CHECK CANDIDATE TIMEOUT (T_limit = 60s) → AUTO-PROMOTE if no motion
      final candidateDuration = now.difference(candidateState.candidateStartTime);
      if (candidateDuration >= _candidateTimeout && (isLowSpeed || isGpsStale)) {
        // After 60s with no gyro spike but still stopped, promote to ParkingDetected
        _cancelCandidateProgressTimer();
        // No auto-confirm timer - stay in ParkingDetected until user confirms
        return ParkingDetected(
          sensorVotes: sensorVotes,
          drivingVotes: drivingVotes,
          parkedVotes: parkedVotes,
        );
      }

      // Stay in StoppedCandidate
      return StoppedCandidate(
        sensorVotes: sensorVotes,
        drivingVotes: drivingVotes,
        parkedVotes: parkedVotes,
        candidateStartTime: candidateState.candidateStartTime,
        latchedGyroSpikeTime: null, // No longer used
      );
    }

    // ------------------------------
    // PARKING DETECTED → PARKED (user confirms)
    // ------------------------------
    if (state is ParkingDetected) {
      // No automatic revert - user must explicitly confirm or deny parking
      // Stay in ParkingDetected until user confirms or denies
      return ParkingDetected(
        sensorVotes: sensorVotes,
        drivingVotes: drivingVotes,
        parkedVotes: parkedVotes,
      );
    }

    // ------------------------------
    // PARKED (Terminal State - No transitions out)
    // ------------------------------
    if (state is Parked) {
      // Parked is a terminal state - no automatic transitions
      // User must manually reset if they want to return to driving detection
      return Parked(
        sensorVotes: sensorVotes,
        drivingVotes: drivingVotes,
        parkedVotes: parkedVotes,
      );
    }

    // ------------------------------
    // Default: maintain current state
    // ------------------------------
    return ParkingUnknown(sensorVotes: sensorVotes, drivingVotes: drivingVotes, parkedVotes: parkedVotes);
  }

  // Check revert conditions with hysteresis
  // Same logic as Unknown → Driving: GPS votes "driving" (speed ≥ 4.1 m/s AND distance > 10m)
  bool _checkRevertConditions(
      Map<String, SensorVote> sensorVotes,
      double currentAccRMS,
      bool isGpsStale,
      DateTime now,
      ) {
    final gpsVote = sensorVotes['gps_speed'] ?? SensorVote.unknown;

    // Only revert if GPS votes "driving" (speed ≥ 4.1 m/s AND distance > 10m for 3s)
    // No GPS stale handling, no accelerometer-only revert
    if (gpsVote == SensorVote.driving) {
      return true; // REVERT to Driving
    }

    return false; // Don't revert
  }

  void _resetRevertTracking() {
    // Reset revert tracking logic removed - no longer tracking hysteresis
  }

  // Removed old complex _processGyroSpikeLogic - now using simplified spike+freeze logic inline

  void _cancelParkingDetectionTimer() {
    _parkingDetectionTimer?.cancel();
    _parkingDetectionTimer = null;
  }

  void _startCandidateProgressTimer() {
    _cancelCandidateProgressTimer();
    _candidateProgressTimer = Timer.periodic(_periodicTickInterval, (_) {
      // Periodic tick to check candidate progression even if GPS is stale
      if (state is StoppedCandidate) {
        add(const CandidateProgressTick());
      }
    });
  }

  void _cancelCandidateProgressTimer() {
    _candidateProgressTimer?.cancel();
    _candidateProgressTimer = null;
  }

  void _onCandidateProgressTick(
      CandidateProgressTick event,
      Emitter<ParkingState> emit,
      ) {
    // IGNORE timer ticks when in Parked state (terminal state)
    if (state is Parked) {
      return;  // Don't process timer ticks in terminal state
    }

    // IGNORE timer ticks when in ParkingDetected state (awaiting user confirmation)
    if (state is ParkingDetected) {
      return;  // Don't process timer ticks while showing confirmation dialog
    }

    // Re-evaluate state using current sensor votes and wall-clock time
    // This allows progression even if GPS samples are stale
    if (state is StoppedCandidate) {
      final newState = _determineState(
        state.sensorVotes,
        state.parkedVotes,
        state.drivingVotes,
      );

      // Only emit if state changed
      if (newState.runtimeType != state.runtimeType) {
        emit(newState);
      } else if (newState is StoppedCandidate && state is StoppedCandidate) {
        // Emit even if same type to update timestamps
        emit(newState);
      }
    }
  }

  void _onUserConfirmedParking(
      UserConfirmedParking event,
      Emitter<ParkingState> emit,
      ) {
    // Transition to Parked state (no timer to cancel)
    emit(Parked(
      sensorVotes: state.sensorVotes,
      drivingVotes: state.drivingVotes,
      parkedVotes: state.parkedVotes,
    ));
  }

  void _onResetParking(
      ResetParking event,
      Emitter<ParkingState> emit,
      ) {
    _cancelParkingDetectionTimer();
    _cancelCandidateProgressTimer();
    _resetRevertTracking();

    // Reset all sensor blocs
    gyroBloc.add(const ResetGyro());
    accBloc.add(const ResetAcc());
    bluetoothBloc.add(const ResetBluetooth());
    gpsSpeedBloc.add(const GpsSpeedReset());

    // Reset to unknown state
    emit(const ParkingUnknown());
  }

  void _onRevertToDriving(
      RevertToDriving event,
      Emitter<ParkingState> emit,
      ) {
    _cancelParkingDetectionTimer();
    _cancelCandidateProgressTimer();
    _resetRevertTracking();

    // Revert to Driving state (don't reset sensor blocs)
    emit(Driving(
      sensorVotes: state.sensorVotes,
      drivingVotes: state.drivingVotes,
      parkedVotes: state.parkedVotes,
    ));
  }

  // TEST EVENT HANDLER: Directly trigger ParkingDetected state for UI testing
  void _onTriggerTestParkingDetection(
      TriggerTestParkingDetection event,
      Emitter<ParkingState> emit,
      ) {
    // Emit ParkingDetected state to trigger the popup dialog
    emit(ParkingDetected(
      sensorVotes: state.sensorVotes,
      drivingVotes: state.drivingVotes,
      parkedVotes: state.parkedVotes,
    ));
  }

  @override
  Future<void> close() async {
    _cancelParkingDetectionTimer();
    _cancelCandidateProgressTimer();
    await _gyroSubscription?.cancel();
    await _accSubscription?.cancel();
    await _bluetoothSubscription?.cancel();
    await _gpsSpeedSubscription?.cancel();
    return super.close();
  }
}
