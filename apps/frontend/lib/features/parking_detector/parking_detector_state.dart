import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

enum ParkingState { driving, parking, parked }

class ParkingDetectorState extends Equatable {
  final ParkingState state;
  final Position? lastPosition;
  final Position? startParkingPosition;

  const ParkingDetectorState({
    this.state = ParkingState.driving,
    this.lastPosition,
    this.startParkingPosition,
  });

  ParkingDetectorState copyWith({
    ParkingState? state,
    Position? lastPosition,
    Position? startParkingPosition,
  }) {
    return ParkingDetectorState(
      state: state ?? this.state,
      lastPosition: lastPosition ?? this.lastPosition,
      startParkingPosition: startParkingPosition ?? this.startParkingPosition,
    );
  }

  @override
  List<Object?> get props => [state, lastPosition, startParkingPosition];
}
