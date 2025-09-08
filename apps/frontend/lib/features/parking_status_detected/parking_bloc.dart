// parking_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'parking_event.dart';
import 'parking_state.dart';

class ParkingBloc extends Bloc<ParkingEvent, ParkingState> {
  StreamSubscription? _gyroscopeSubscription;

  ParkingBloc() : super(DrivingState()) {
    // Listen to events
    on<GyroscopeChanged>(_onGyroscopeChanged);
    on<UserConfirmedParking>((event, emit) => emit(ParkedState()));
    on<ResetParking>((event, emit) => emit(DrivingState()));

    // Start listening to gyroscope
    _gyroscopeSubscription = gyroscopeEventStream.listen((event) {
      add(GyroscopeChanged(x: event.x, y: event.y, z: event.z));
    });
  }

  void _onGyroscopeChanged(
      GyroscopeChanged event, Emitter<ParkingState> emit) {
    // Threshold for detecting a “pickup / rotation”
    const double threshold = 1.5; // adjust via testing
    if (event.x.abs() > threshold ||
        event.y.abs() > threshold ||
        event.z.abs() > threshold) {
      // Only emit if currently driving
      if (state is DrivingState) {
        emit(ParkingDetectedState());
      }
    }
  }

  @override
  Future<void> close() {
    _gyroscopeSubscription?.cancel();
    return super.close();
  }
}
