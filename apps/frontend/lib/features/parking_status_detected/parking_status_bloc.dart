import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'parking_status_event.dart';
import 'parking_status_state.dart';

class ParkingBloc extends Bloc<ParkingEvent, ParkingState> {
  // Sensor subscriptions
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription? _bluetoothSubscription; // pseudo

  // Voting map: sensor name -> latest vote
  final Map<String, SensorVote> _votes = {};

  ParkingBloc() : super(UnknownParkingState()) {
    // Event handlers
    on<GyroscopeChanged>(_onGyroscopeChanged);
    on<AccelerometerChanged>(_onAccelerometerChanged);
    // on<BluetoothChanged>(_onBluetoothChanged);
    on<UserConfirmedParking>((event, emit) => emit(ParkedState()));
    on<ResetParking>((event, emit) => emit(DrivingState()));

    // Start listening to sensors
    _gyroSubscription = SensorsPlatform.instance.gyroscopeEventStream().listen(
      (event) {
        add(GyroscopeChanged(x: event.x, y: event.y, z: event.z));
      },
    );

    _accelSubscription = SensorsPlatform.instance.accelerometerEventStream().listen(
      (event) {
        add(AccelerometerChanged(x: event.x, y: event.y, z: event.z));
      },
    );

    // TODO: Bluetooth subscription for proximity / car detection
    // _bluetoothSubscription = ...
  }

  // Voting aggregation
  void _updateState(Emitter<ParkingState> emit) {
    // Count votes
    int drivingVotes = _votes.values.where((v) => v == SensorVote.driving).length;
    int parkingVotes = _votes.values.where((v) => v == SensorVote.parked).length;

    if (parkingVotes > drivingVotes) {
      if (state is! ParkingDetectedState) emit(ParkingDetectedState());
    } else {
      if (state is! DrivingState) emit(DrivingState());
    }
  }

  // --- Sensor event handlers ---
  void _onGyroscopeChanged(GyroscopeChanged event, Emitter<ParkingState> emit) {
    // Example: detect parking vs driving from gyro
    const double threshold = 1.5;
    SensorVote vote = (event.x.abs() > threshold || event.y.abs() > threshold || event.z.abs() > threshold)
        ? SensorVote.parked
        : SensorVote.driving;
    _votes['gyroscope'] = vote;
    _updateState(emit);
  }

  void _onAccelerometerChanged(AccelerometerChanged event, Emitter<ParkingState> emit) {
    const double threshold = 1.2;
    SensorVote vote = (event.x.abs() > threshold || event.y.abs() > threshold || event.z.abs() > threshold)
        ? SensorVote.driving
        : SensorVote.parked;
    _votes['accelerometer'] = vote;
    _updateState(emit);
  }

  // void _onBluetoothChanged(BluetoothChanged event, Emitter<ParkingState> emit) {
  //   // Example: connected to car -> driving, disconnected -> parked
  //   SensorVote vote = event.connected ? SensorVote.driving : SensorVote.parked;
  //   _votes['bluetooth'] = vote;
  //   _updateState(emit);
  // }

  @override
  Future<void> close() {
    _gyroSubscription?.cancel();
    _accelSubscription?.cancel();
    _bluetoothSubscription?.cancel();
    return super.close();
  }
}

// Enum for sensor votes
enum SensorVote { driving, parked }
