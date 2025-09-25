import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum LocationMode { current, selected }

class FilterConfig {
  final LocationMode mode;
  final LatLng? selectedPoint;
  final double radiusMeters;
  final int durationMinutes;
  final TimeOfDay startTime;

  const FilterConfig({
    required this.mode,
    this.selectedPoint,
    required this.radiusMeters,
    required this.durationMinutes,
    required this.startTime,
  });

  bool get useCurrentLocation => mode == LocationMode.current;

  FilterConfig copyWith({
    LocationMode? mode,
    LatLng? selectedPoint,
    double? radiusMeters,
    int? durationMinutes,
    TimeOfDay? startTime,
  }) {
    return FilterConfig(
      mode: mode ?? this.mode,
      selectedPoint: selectedPoint ?? this.selectedPoint,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startTime: startTime ?? this.startTime,
    );
  }
}
