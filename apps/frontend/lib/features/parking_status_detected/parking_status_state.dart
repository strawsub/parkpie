// lib/features/parking_status_detected/parking_status_state.dart
abstract class ParkingState {}

class UnknownParkingState extends ParkingState {}
class DrivingState extends ParkingState {}
class ParkingDetectedState extends ParkingState {}
class ParkedState extends ParkingState {}
