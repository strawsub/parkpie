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

  // Configuration
  static const int _numVotesParking = 3;
  static const int _numVotesDriving = 3;
  static const Duration _parkingDetectionDuration = Duration(seconds: 5);

  Timer? _parkingDetectionTimer;

  ParkingBloc({
    required this.gyroBloc,
    required this.accBloc,
    required this.bluetoothBloc,
    required this.gpsSpeedBloc,
  }) : super(const ParkingUnknown()) {
    on<UpdateSensorVote>(_onUpdateSensorVote);
    on<UserConfirmedParking>(_onUserConfirmedParking);
    on<ResetParking>(_onResetParking);

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
      if (bluetoothState is BluetoothConnectionStatus) {
        add(UpdateSensorVote(
          sensorName: 'bluetooth',
          vote: bluetoothState.vote,
        ));
      }
    });

    // Listen to GPS speed state changes
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
    // Update sensor votes
    final updatedVotes = Map<String, SensorVote>.from(state.sensorVotes);
    updatedVotes[event.sensorName] = event.vote;

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

    // ------------------------------
    // UNKNOWN → DRIVING
    // ------------------------------
    if (state is ParkingUnknown) {
      if (drivingVotes >= _numVotesDriving) { 
        return Driving(
          sensorVotes: sensorVotes,
          drivingVotes: drivingVotes,
          parkedVotes: parkedVotes,
        );
      }
    }

    // ------------------------------
    // DRIVING → PARKED
    // ------------------------------
    if (state is Driving) {
      if (parkedVotes >= _numVotesParking) { // majority vote for parked
        _startParkingDetectionTimer();
        return ParkingDetected(
          sensorVotes: sensorVotes,
          drivingVotes: drivingVotes,
          parkedVotes: parkedVotes,
        );
      }
    }

    // ------------------------------
    // PARKED → DRIVING
    // ------------------------------
    if (state is Parked || state is ParkingDetected) {
      if (drivingVotes >= _numVotesDriving) {
        _cancelParkingDetectionTimer();
        return Driving(
          sensorVotes: sensorVotes,
          drivingVotes: drivingVotes,
          parkedVotes: parkedVotes,
        );
      }
    }

    // ------------------------------
    // Maintain current state if votes are mixed
    // ------------------------------
    if (state is Driving) {
      return Driving(
        sensorVotes: sensorVotes,
        drivingVotes: drivingVotes,
        parkedVotes: parkedVotes,
      );
    } else if (state is Parked) {
      return Parked(
        sensorVotes: sensorVotes,
        drivingVotes: drivingVotes,
        parkedVotes: parkedVotes,
      );
    } else if (state is ParkingDetected) {
      return ParkingDetected(
        sensorVotes: sensorVotes,
        drivingVotes: drivingVotes,
        parkedVotes: parkedVotes,
      );
    }

    return ParkingUnknown(sensorVotes: sensorVotes, drivingVotes: drivingVotes, parkedVotes: parkedVotes);
  }

  void _startParkingDetectionTimer() {
    _cancelParkingDetectionTimer();
    _parkingDetectionTimer = Timer(_parkingDetectionDuration, () {
      // Auto-transition to Parked after detection duration
      if (state is ParkingDetected) {
        add(const UserConfirmedParking());
      }
    });
  }

  void _cancelParkingDetectionTimer() {
    _parkingDetectionTimer?.cancel();
    _parkingDetectionTimer = null;
  }

  void _onUserConfirmedParking(
    UserConfirmedParking event,
    Emitter<ParkingState> emit,
  ) {
    _cancelParkingDetectionTimer();
    
    // Transition to Parked state
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
    
    // Reset all sensor blocs
    gyroBloc.add(const ResetGyro());
    accBloc.add(const ResetAcc());
    bluetoothBloc.add(const ResetBluetooth());
    gpsSpeedBloc.add(const GpsSpeedReset());

    // Reset to unknown state
    emit(const ParkingUnknown());
  }

  @override
  Future<void> close() async {
    _cancelParkingDetectionTimer();
    await _gyroSubscription?.cancel();
    await _accSubscription?.cancel();
    await _bluetoothSubscription?.cancel();
    await _gpsSpeedSubscription?.cancel();
    return super.close();
  }
}