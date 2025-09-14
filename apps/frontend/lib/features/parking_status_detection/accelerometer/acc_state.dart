import '../utils.dart';
import 'package:equatable/equatable.dart';

abstract class AccState extends Equatable {
  final SensorVote vote;
  final double? currentRMS;
  final double? quietRatio;
  final bool isStopCandidate;

  const AccState({
    required this.vote,
    this.currentRMS,
    this.quietRatio,
    this.isStopCandidate = false,
  });

  @override
  List<Object?> get props => [vote, currentRMS, quietRatio, isStopCandidate];
}

class AccInitial extends AccState {
  const AccInitial() : super(vote: SensorVote.unknown);
}

class AccReading extends AccState {
  const AccReading({
    required super.vote,
    super.currentRMS,
    super.quietRatio,
    super.isStopCandidate,
  });
}