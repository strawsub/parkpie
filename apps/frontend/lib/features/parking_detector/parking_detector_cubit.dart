import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'parking_detector_state.dart';
import 'sensors_service.dart';

class ParkingDetectorCubit extends Cubit<ParkingDetectorState> {
  final SensorsService _sensorsService;
  final Duration _parkingTimeout = const Duration(seconds: 15);
  final double _parkingSpeedThreshold = 1.5; // in m/s (3.6 km/h)
  final double _accThreshold = 0.5; // in m/s^2
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<double>? _accSubscription;
  Timer? _parkingTimer;

  ParkingDetectorCubit(this._sensorsService) : super(const ParkingDetectorState()) {
    _startListeningToSensors();
  }

  void _startListeningToSensors() {
    _positionSubscription = _sensorsService.position$.listen((position) {
      // make the decision based on velocity and location
      _checkParkingStatus(position);
    });

    _accSubscription = _sensorsService.userAccMag$.listen((mag) {
      // make the decision based on accelerator
      // i.e., when the status is parking, if the acc is increased a lot,
      // it means the user may leave
    });
  }

  void _checkParkingStatus(Position position) {
    final speed = position.speed;
    var next = state.copyWith(lastPosition: position);

    if (speed < _parkingSpeedThreshold) {
      // If parked, keep this status, no changes
      if (state.state == ParkingState.parked) {
        emit(next);
        return;
      }

      // If the status is driving, and the vel is below a threshold,
      // the system starts detecting
      if (state.state == ParkingState.driving) {
        next = next.copyWith(
            state: ParkingState.parking, startParkingPosition: position);
        _startParkingConfirmationTimer();
      }

      emit(next);
    } else {
      // if the vel is back to a normal level, the status will be set to driving
      _parkingTimer?.cancel();
      emit(const ParkingDetectorState());
    }
  }

  void _startParkingConfirmationTimer() {
    _parkingTimer?.cancel();
    _parkingTimer = Timer(_parkingTimeout, () {
      // when the timer is ended, and the status is still parking, we confirm parked
      if (state.state == ParkingState.parking) {
        emit(state.copyWith(state: ParkingState.parked));
        _parkingTimer?.cancel();
        // TBD: to call the backend later to save the parked information
        _notifyBackend();
      }
    });
  }

  void _notifyBackend() {
    // TBD: to call the backend later to save the parked information
    print('Parking detected! Notifying backend...');
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    _accSubscription?.cancel();
    _parkingTimer?.cancel();
    return super.close();
  }
}
