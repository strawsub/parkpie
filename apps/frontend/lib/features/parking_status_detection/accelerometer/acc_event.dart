import 'package:equatable/equatable.dart';

abstract class AccEvent extends Equatable {
  const AccEvent();

  @override
  List<Object?> get props => [];
}

class AccDataReceived extends AccEvent {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  const AccDataReceived({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [x, y, z, timestamp];
}

class ResetAcc extends AccEvent {
  const ResetAcc();
}