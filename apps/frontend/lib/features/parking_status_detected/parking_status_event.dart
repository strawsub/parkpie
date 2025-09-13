abstract class ParkingEvent {}

class GyroscopeChanged extends ParkingEvent {
  final double x, y, z;
  GyroscopeChanged({required this.x, required this.y, required this.z});
}

class AccelerometerChanged extends ParkingEvent {
  final double x, y, z;
  final DateTime t;
  AccelerometerChanged({
    required this.x,
    required this.y,
    required this.z,
    required this.t,
  });
}

class BluetoothAudioChanged extends ParkingEvent {
  final bool isConnected;
  final String? deviceName;
  BluetoothAudioChanged({
    required this.isConnected,
    this.deviceName,
  });
}

class UserConfirmedParking extends ParkingEvent {}
class ResetParking extends ParkingEvent {}