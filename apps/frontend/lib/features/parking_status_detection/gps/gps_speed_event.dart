import 'package:equatable/equatable.dart';

abstract class GpsSpeedEvent extends Equatable {
  const GpsSpeedEvent();

  @override
  List<Object?> get props => [];
}

class GpsSpeedLocationSampleArrived extends GpsSpeedEvent {
  final double lat;
  final double lon;
  final double? horizAcc;
  final DateTime timestamp;

  const GpsSpeedLocationSampleArrived({
    required this.lat,
    required this.lon,
    this.horizAcc,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [lat, lon, horizAcc, timestamp];
}

class GpsSpeedReset extends GpsSpeedEvent {
  const GpsSpeedReset();
}
