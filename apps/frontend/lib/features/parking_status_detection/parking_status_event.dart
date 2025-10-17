import 'package:equatable/equatable.dart';
import 'utils.dart';

abstract class ParkingEvent extends Equatable {
  const ParkingEvent();

  @override
  List<Object?> get props => [];
}

class UpdateSensorVote extends ParkingEvent {
  final String sensorName;
  final SensorVote vote;

  const UpdateSensorVote({
    required this.sensorName,
    required this.vote,
  });

  @override
  List<Object?> get props => [sensorName, vote];
}

class UserConfirmedParking extends ParkingEvent {
  const UserConfirmedParking();
}

class ResetParking extends ParkingEvent {
  const ResetParking();
}

class RevertToDriving extends ParkingEvent {
  const RevertToDriving();
}

class CandidateProgressTick extends ParkingEvent {
  const CandidateProgressTick();
}

// TEST EVENT: Manually trigger parking detection popup for UI testing
class TriggerTestParkingDetection extends ParkingEvent {
  const TriggerTestParkingDetection();
}
