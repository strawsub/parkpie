import 'package:equatable/equatable.dart';

abstract class GyroEvent extends Equatable {
  const GyroEvent();

  @override
  List<Object?> get props => [];
}

class GyroDataReceived extends GyroEvent {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  const GyroDataReceived({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [x, y, z, timestamp];
}

class ResetGyro extends GyroEvent {
  const ResetGyro();
}