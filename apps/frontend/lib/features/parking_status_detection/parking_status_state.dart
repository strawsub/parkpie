import 'package:equatable/equatable.dart';
import 'utils.dart';

abstract class ParkingState extends Equatable {
  final Map<String, SensorVote> sensorVotes;
  final int drivingVotes;
  final int parkedVotes;

  const ParkingState({
    required this.sensorVotes,
    required this.drivingVotes,
    required this.parkedVotes,
  });

  @override
  List<Object?> get props => [sensorVotes, drivingVotes, parkedVotes];
}

class ParkingUnknown extends ParkingState {
  const ParkingUnknown({
    super.sensorVotes = const <String, SensorVote>{},
    super.drivingVotes = 0,
    super.parkedVotes = 0,
  });
}

class Driving extends ParkingState {
  const Driving({
    required super.sensorVotes,
    required super.drivingVotes,
    required super.parkedVotes,
  });
}

class StoppedCandidate extends ParkingState {
  final DateTime candidateStartTime;
  final DateTime? latchedGyroSpikeTime; // Simplified: just track spike time

  const StoppedCandidate({
    required super.sensorVotes,
    required super.drivingVotes,
    required super.parkedVotes,
    required this.candidateStartTime,
    this.latchedGyroSpikeTime,
  });

  @override
  List<Object?> get props => [
    sensorVotes,
    drivingVotes,
    parkedVotes,
    candidateStartTime,
    latchedGyroSpikeTime,
  ];
}

class ParkingDetected extends ParkingState {
  const ParkingDetected({
    required super.sensorVotes,
    required super.drivingVotes,
    required super.parkedVotes,
  });
}

class Parked extends ParkingState {
  const Parked({
    required super.sensorVotes,
    required super.drivingVotes,
    required super.parkedVotes,
  });
}
