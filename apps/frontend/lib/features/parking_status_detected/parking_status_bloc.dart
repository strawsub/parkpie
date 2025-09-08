import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'parking_status_event.dart';
import 'parking_status_state.dart';

class ParkingBloc extends Bloc<ParkingEvent, ParkingState> {
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  ParkingBloc() : super(DrivingState()) {
    // Listen to Bloc events
    on<GyroscopeChanged>(_onGyroscopeChanged);
    on<UserConfirmedParking>((event, emit) => emit(ParkedState()));
    on<ResetParking>((event, emit) => emit(DrivingState()));

    // Start listening to gyroscope using the new gyroscopeEventStream()
    _gyroscopeSubscription = SensorsPlatform.instance.gyroscopeEventStream().listen(
      (event) {
        add(GyroscopeChanged(x: event.x, y: event.y, z: event.z));
      },
      onError: (error) {
        // Optional: handle sensor errors
        // print('Gyroscope error: $error');
      },
    );
  }

  void _onGyroscopeChanged(GyroscopeChanged event, Emitter<ParkingState> emit) {
    const double threshold = 1.5; // adjust via testing
    if (event.x.abs() > threshold ||
        event.y.abs() > threshold ||
        event.z.abs() > threshold) {
      if (state is DrivingState) {
        emit(ParkingDetectedState()); // emit state when movement indicates parked
      }
    }
  }

  @override
  Future<void> close() {
    _gyroscopeSubscription?.cancel();
    return super.close();
  }
}
