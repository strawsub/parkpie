import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'kalman_filter.dart';

class LocationState {
  final Position? rawPosition;
  final List<double>? filteredPosition;
  final List<Position> rawHistory;
  final List<List<double>> filteredHistory;

  LocationState({
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
  KalmanFilter? _filter;
  StreamSubscription<Position>? _positionStream;

  LocationCubit() : super(LocationState());

  void startTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _positionStream ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, // 精準度
        distanceFilter: 1, // 移動 1 公尺才更新
      ),
    ).listen((pos) {
      _filter ??= KalmanFilter(pos.latitude, pos.longitude);
      final filtered = _filter!.filter(pos.latitude, pos.longitude);

      final newRawHistory = List<Position>.from(state.rawHistory)..add(pos);
      final newFilteredHistory = List<List<double>>.from(state.filteredHistory)..add(filtered);

      emit(LocationState(
        rawPosition: pos,
        filteredPosition: filtered,
        rawHistory: newRawHistory,
        filteredHistory: newFilteredHistory,
      ));
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  @override
  Future<void> close() {
    stopTracking();
    return super.close();
  }
}
