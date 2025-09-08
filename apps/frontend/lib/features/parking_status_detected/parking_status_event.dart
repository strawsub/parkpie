abstract class ParkingEvent {}

class GyroscopeChanged extends ParkingEvent {
  final double x;
  final double y;
  final double z;

  GyroscopeChanged({required this.x, required this.y, required this.z});
}

class AccelerometerChanged extends ParkingEvent {
  final double x;
  final double y;
  final double z;

  AccelerometerChanged({required this.x, required this.y, required this.z});

}

class UserConfirmedParking extends ParkingEvent {}

class ResetParking extends ParkingEvent {}