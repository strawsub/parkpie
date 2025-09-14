import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'parking_status_event.dart';
import 'parking_status_state.dart';
import 'accelerometer_handler.dart';
import 'gyroscope_handler.dart';
import 'bluetooth_handler.dart';
import 'utils.dart';

class ParkingBloc extends Bloc<ParkingEvent, ParkingState> {
  // Sensor handlers
  final AccelHandler _accelHandler = AccelHandler();
  final GyroHandler _gyroHandler = GyroHandler();
  late final BluetoothHandlerService _bluetoothHandler;

  // Sensor vote map
  final Map<String, SensorVote> _votes = {};

  // Sensor subscriptions
  StreamSubscription? _accSub;
  StreamSubscription? _gyroSub;

  ParkingBloc() : super(UnknownParkingState()) {
    _bluetoothHandler = BluetoothHandlerService(votes: _votes);

    // Event handlers
    on<GyroscopeChanged>(
      (e, emit) => _gyroHandler.onGyro(e, _votes, emit, _updateState),
    );

    on<AccelerometerChanged>(
      (e, emit) => _accelHandler.onAcc(e, _votes, emit, _updateState),
    );

    on<BluetoothAudioChanged>(
      (e, emit) => _bluetoothHandler.handleEvent(e, _updateState),
    );

    // User actions
    on<UserConfirmedParking>((_, emit) => emit(ParkedState()));

    on<ResetParking>((_, emit) {
      emit(DrivingState());
      _clearAll();
    });

    // Subscribe to raw sensor streams
    _gyroSub = gyroscopeEventStream().listen((e) {
      add(GyroscopeChanged(x: e.x, y: e.y, z: e.z, t: DateTime.now()));
    });

    _accSub = userAccelerometerEventStream().listen((e) {
      add(AccelerometerChanged(x: e.x, y: e.y, z: e.z, t: DateTime.now()));
    });

    // Initialize Bluetooth
    _bluetoothHandler.initialize((e) => add(e));
  }

  /// Aggregates votes from sensors and updates state
  void _updateState(Emitter<ParkingState> emit) {
    if (state is ParkedState) return; // Freeze if user confirmed

    final drivingVotes = _votes.values.where((v) => v == SensorVote.driving).length;
    final parkedVotes = _votes.values.where((v) => v == SensorVote.parked).length;

    if (parkedVotes > drivingVotes) {
      if (state is! ParkingDetectedState && state is! ParkedState) {
        emit(ParkingDetectedState());
      }
    } else if (drivingVotes > parkedVotes) {
      if (state is! DrivingState) emit(DrivingState());
    } else {
      if (state is UnknownParkingState) emit(DrivingState());
    }
  }

  /// Clears votes and resets all sensors
  void _clearAll() {
    _votes.clear();
    _accelHandler.reset();
    _gyroHandler.reset();
    _bluetoothHandler.dispose();
  }

  @override
  Future<void> close() async {
    await _accSub?.cancel();
    await _gyroSub?.cancel();
    await _bluetoothHandler.dispose();
    return super.close();
  }
}