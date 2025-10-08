import 'package:equatable/equatable.dart';

abstract class TimerState extends Equatable {
  final Duration elapsed;
  final DateTime? startTime;
  final int? zoneNumber;
  final String? zoneName;
  final int restrictionDurationMinutes; // make non-nullable

  const TimerState({
    this.elapsed = Duration.zero,
    this.startTime,
    this.zoneNumber,
    this.zoneName,
    this.restrictionDurationMinutes = 0,
  });

  TimerState copyWith({
    Duration? elapsed,
    DateTime? startTime,
    int? zoneNumber,
    String? zoneName,
    int? restrictionDurationMinutes,
  });

  @override
  List<Object?> get props => [
        elapsed,
        startTime,
        zoneNumber,
        zoneName,
        restrictionDurationMinutes,
      ];
}

class TimerInitial extends TimerState {
  const TimerInitial({int restrictionDurationMinutes = 0})
      : super(restrictionDurationMinutes: restrictionDurationMinutes);

  @override
  TimerInitial copyWith({
    Duration? elapsed,
    DateTime? startTime,
    int? zoneNumber,
    String? zoneName,
    int? restrictionDurationMinutes,
  }) {
    return TimerInitial(
      restrictionDurationMinutes:
          restrictionDurationMinutes ?? this.restrictionDurationMinutes,
    );
  }
}

class TimerRunning extends TimerState {
  const TimerRunning({
    required Duration elapsed,
    required DateTime startTime,
    int? zoneNumber,
    String? zoneName,
    int restrictionDurationMinutes = 0,
  }) : super(
          elapsed: elapsed,
          startTime: startTime,
          zoneNumber: zoneNumber,
          zoneName: zoneName,
          restrictionDurationMinutes: restrictionDurationMinutes,
        );

  @override
  TimerRunning copyWith({
    Duration? elapsed,
    DateTime? startTime,
    int? zoneNumber,
    String? zoneName,
    int? restrictionDurationMinutes,
  }) {
    return TimerRunning(
      elapsed: elapsed ?? this.elapsed,
      startTime: startTime ?? this.startTime!,
      zoneNumber: zoneNumber ?? this.zoneNumber,
      zoneName: zoneName ?? this.zoneName,
      restrictionDurationMinutes:
          restrictionDurationMinutes ?? this.restrictionDurationMinutes,
    );
  }
}

class TimerStopped extends TimerState {
  const TimerStopped({
    required Duration elapsed,
    DateTime? startTime, // include startTime to match TimerState
    int? zoneNumber,
    String? zoneName,
    int restrictionDurationMinutes = 0,
  }) : super(
          elapsed: elapsed,
          startTime: startTime,
          zoneNumber: zoneNumber,
          zoneName: zoneName,
          restrictionDurationMinutes: restrictionDurationMinutes,
        );

  @override
  TimerStopped copyWith({
    Duration? elapsed,
    DateTime? startTime, // include startTime
    int? zoneNumber,
    String? zoneName,
    int? restrictionDurationMinutes,
  }) {
    return TimerStopped(
      elapsed: elapsed ?? this.elapsed,
      startTime: startTime ?? this.startTime,
      zoneNumber: zoneNumber ?? this.zoneNumber,
      zoneName: zoneName ?? this.zoneName,
      restrictionDurationMinutes:
          restrictionDurationMinutes ?? this.restrictionDurationMinutes,
    );
  }
}
