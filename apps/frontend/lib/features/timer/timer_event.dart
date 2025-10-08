import 'package:equatable/equatable.dart';

abstract class TimerEvent extends Equatable {
  const TimerEvent();

  @override
  List<Object?> get props => [];
}

class LoadTimer extends TimerEvent {
  const LoadTimer();
}

class StartTimer extends TimerEvent {
  final int? zoneNumber;
  final String? zoneName;

  const StartTimer({this.zoneNumber, this.zoneName});

  @override
  List<Object?> get props => [zoneNumber, zoneName];
}

class StopTimer extends TimerEvent {
  const StopTimer();
}

class ResetTimer extends TimerEvent {
  const ResetTimer();
}

class TimerTick extends TimerEvent {
  const TimerTick();
}

class UpdateRestrictionDuration extends TimerEvent {
  final int durationMinutes;

  const UpdateRestrictionDuration(this.durationMinutes);

  @override
  List<Object?> get props => [durationMinutes];
}
