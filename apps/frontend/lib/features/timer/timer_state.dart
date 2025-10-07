import 'package:equatable/equatable.dart';

abstract class TimerState extends Equatable {
  final Duration elapsed;
  final DateTime? startTime;
  final int? zoneNumber;
  final String? zoneName;

  const TimerState({
    this.elapsed = Duration.zero,
    this.startTime,
    this.zoneNumber,
    this.zoneName,
  });

  @override
  List<Object?> get props => [elapsed, startTime, zoneNumber, zoneName];
}

class TimerInitial extends TimerState {
  const TimerInitial() : super();
}

class TimerRunning extends TimerState {
  const TimerRunning({
    required Duration elapsed,
    required DateTime startTime,
    int? zoneNumber,
    String? zoneName,
  }) : super(
          elapsed: elapsed,
          startTime: startTime,
          zoneNumber: zoneNumber,
          zoneName: zoneName,
        );
}

class TimerStopped extends TimerState {
  const TimerStopped({
    required Duration elapsed,
    int? zoneNumber,
    String? zoneName,
  }) : super(
          elapsed: elapsed,
          zoneNumber: zoneNumber,
          zoneName: zoneName,
        );
}
