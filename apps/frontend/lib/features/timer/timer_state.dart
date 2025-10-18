import 'package:equatable/equatable.dart';

abstract class TimerState extends Equatable {
  final Duration elapsed;
  final DateTime? startTime;
  final int? zoneNumber;
  final String? zoneName;
  final int restrictionDurationMinutes; // make non-nullable
  final bool usingFallback;

  const TimerState({
    this.elapsed = Duration.zero,
    this.startTime,
    this.zoneNumber,
    this.zoneName,
    this.restrictionDurationMinutes = 0,
    this.usingFallback = false,
  });

  TimerState copyWith({
    Duration? elapsed,
    DateTime? startTime,
    int? zoneNumber,
    String? zoneName,
    int? restrictionDurationMinutes,
    bool? usingFallback,
  });

  @override
  List<Object?> get props => [
    elapsed,
    startTime,
    zoneNumber,
    zoneName,
    restrictionDurationMinutes,
    usingFallback,
  ];
}

class TimerInitial extends TimerState {
  const TimerInitial({
    super.restrictionDurationMinutes,
    super.zoneNumber,
    super.zoneName,
  });

  @override
  TimerInitial copyWith({
    Duration? elapsed,
    DateTime? startTime,
    int? zoneNumber,
    String? zoneName,
    int? restrictionDurationMinutes,
    bool? usingFallback,
  }) {
    return TimerInitial(
      restrictionDurationMinutes:
          restrictionDurationMinutes ?? this.restrictionDurationMinutes,
      zoneNumber: zoneNumber ?? this.zoneNumber,
      zoneName: zoneName ?? this.zoneName,
    );
  }
}

class TimerRunning extends TimerState {
  const TimerRunning({
    required super.elapsed,
    required DateTime super.startTime,
    super.zoneNumber,
    super.zoneName,
    super.restrictionDurationMinutes,
    super.usingFallback,
  });

  @override
  TimerRunning copyWith({
    Duration? elapsed,
    DateTime? startTime,
    int? zoneNumber,
    String? zoneName,
    int? restrictionDurationMinutes,
    bool? usingFallback,
  }) {
    return TimerRunning(
      elapsed: elapsed ?? this.elapsed,
      startTime: startTime ?? this.startTime!,
      zoneNumber: zoneNumber ?? this.zoneNumber,
      zoneName: zoneName ?? this.zoneName,
      restrictionDurationMinutes:
          restrictionDurationMinutes ?? this.restrictionDurationMinutes,
      usingFallback: usingFallback ?? this.usingFallback,
    );
  }
}

class TimerStopped extends TimerState {
  const TimerStopped({
    required super.elapsed,
    super.startTime, // include startTime to match TimerState
    super.zoneNumber,
    super.zoneName,
    super.restrictionDurationMinutes,
    super.usingFallback,
  });

  @override
  TimerStopped copyWith({
    Duration? elapsed,
    DateTime? startTime, // include startTime
    int? zoneNumber,
    String? zoneName,
    int? restrictionDurationMinutes,
    bool? usingFallback,
  }) {
    return TimerStopped(
      elapsed: elapsed ?? this.elapsed,
      startTime: startTime ?? this.startTime,
      zoneNumber: zoneNumber ?? this.zoneNumber,
      zoneName: zoneName ?? this.zoneName,
      restrictionDurationMinutes:
          restrictionDurationMinutes ?? this.restrictionDurationMinutes,
      usingFallback: usingFallback ?? this.usingFallback,
    );
  }
}

class TimerFailure extends TimerState {
  final String message;
  const TimerFailure({required this.message, super.zoneNumber, super.zoneName});

  @override
  TimerFailure copyWith({
    Duration? elapsed,
    DateTime? startTime,
    int? zoneNumber,
    String? zoneName,
    int? restrictionDurationMinutes,
    bool? usingFallback,
  }) {
    return TimerFailure(
      message: message,
      zoneNumber: zoneNumber ?? this.zoneNumber,
      zoneName: zoneName ?? this.zoneName,
    );
  }

  @override
  List<Object?> get props => super.props..add(message);
}
