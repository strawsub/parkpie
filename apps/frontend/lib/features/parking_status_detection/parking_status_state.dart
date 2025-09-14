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
    Map<String, SensorVote> sensorVotes = const {},
    int drivingVotes = 0,
    int parkedVotes = 0,
  }) : super(
          sensorVotes: sensorVotes,
          drivingVotes: drivingVotes,
          parkedVotes: parkedVotes,
        );
}

class Driving extends ParkingState {
  const Driving({
    required super.sensorVotes,
    required super.drivingVotes,
    required super.parkedVotes,
  });
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