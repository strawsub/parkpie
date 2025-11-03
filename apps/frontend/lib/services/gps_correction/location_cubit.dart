import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import 'kalman_filter.dart';

class LocationState {
  final Position? rawPosition;
  final List<double>? filteredPosition;
  final List<Position> rawHistory;
  final List<List<double>> filteredHistory;

  const LocationState({
    this.rawPosition,
    this.filteredPosition,
    this.rawHistory = const [],
    this.filteredHistory = const [],
  });

  LocationState copyWith({
    Position? rawPosition,
    List<double>? filteredPosition,
    List<Position>? rawHistory,
    List<List<double>>? filteredHistory,
  }) {
    return LocationState(
      rawPosition: rawPosition ?? this.rawPosition,
      filteredPosition: filteredPosition ?? this.filteredPosition,
      rawHistory: rawHistory ?? this.rawHistory,
      filteredHistory: filteredHistory ?? this.filteredHistory,
    );
  }
}

class LocationCubit extends Cubit<LocationState> {
  AdaptiveKalmanFilter? _filter;
  StreamSubscription<Position>? _positionStream;

  LocationCubit() : super(const LocationState());

  Future<void> startTracking() async {
    if (_positionStream != null) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,  // Changed from 1 → Updates every GPS sample for faster response
      ),
    ).listen((pos) {
      _filter ??= AdaptiveKalmanFilter(pos.latitude, pos.longitude);
      final filtered = _filter!.filter(pos.latitude, pos.longitude);
      final newRawHistory = List<Position>.from(state.rawHistory)..add(pos);
      final newFilteredHistory =
          List<List<double>>.from(state.filteredHistory)..add(filtered);
      emit(
        LocationState(
          rawPosition: pos,
          filteredPosition: filtered,
          rawHistory: newRawHistory,
          filteredHistory: newFilteredHistory,
        ),
      );
    },
    onError: (e) {
      
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _filter = null;
    emit(const LocationState());
  }

  @override
  Future<void> close() {
    stopTracking();
    return super.close();
  }
}
