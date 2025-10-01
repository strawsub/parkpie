import 'package:equatable/equatable.dart';
import '../utils.dart';

abstract class GpsSpeedState extends Equatable {
  const GpsSpeedState();

  @override
  List<Object?> get props => [];
}

class GpsSpeedInitial extends GpsSpeedState {
  const GpsSpeedInitial();
}

class GpsSpeedReading extends GpsSpeedState {
  final SensorVote vote;
  final double rawSpeed; // m/s - raw calculated speed (before filtering)
  final double filteredSpeed; // m/s - EMA filtered speed (used for voting)
  final double windowDisplacement; // meters - accuracy-weighted displacement
  final double candidateSeconds; // seconds - how long in current candidate state
  final double? accuracy; // GPS accuracy in meters
  final String accuracyScenario; // "good", "medium", or "poor"

  const GpsSpeedReading({
    required this.vote,
    required this.rawSpeed,
    required this.filteredSpeed,
    required this.windowDisplacement,
    required this.candidateSeconds,
    this.accuracy,
    required this.accuracyScenario,
  });

  @override
  List<Object?> get props => [vote, rawSpeed, filteredSpeed, windowDisplacement, candidateSeconds, accuracy, accuracyScenario];
}
