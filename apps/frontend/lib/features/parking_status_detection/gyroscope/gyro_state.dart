import 'package:equatable/equatable.dart';
import '../utils.dart';

abstract class GyroState extends Equatable {
  final SensorVote vote;
  final double? maxRotation;

  const GyroState({
    required this.vote,
    this.maxRotation,
  });

  @override
  List<Object?> get props => [vote, maxRotation];
}

class GyroInitial extends GyroState {
  const GyroInitial() : super(vote: SensorVote.unknown);
}

class GyroReading extends GyroState {
  const GyroReading({
    required super.vote,
    super.maxRotation,
  });
}