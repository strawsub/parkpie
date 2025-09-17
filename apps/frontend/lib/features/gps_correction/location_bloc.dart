import 'dart:async'; // <- 這行
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'kalman_filter.dart';

class LocationState {
  final Position? rawPosition;
  final List<double>? filteredPosition;

  LocationState({this.rawPosition, this.filteredPosition});
}

class LocationCubit extends Cubit<LocationState> {
  KalmanFilter? _filter;
  Stream<Position>? _positionStream;
  StreamSubscription<Position>? _subscription;

  LocationCubit() : super(LocationState()) {
    _startTracking();
  }

  void _startTracking() async {
    // 訂閱 GPS 流
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // 每移動 1 公尺更新
      ),
    );

    _subscription = _positionStream!.listen((pos) {
      _filter ??= KalmanFilter(pos.latitude, pos.longitude);
      final filtered = _filter!.filter(pos.latitude, pos.longitude);

      emit(LocationState(rawPosition: pos, filteredPosition: filtered));
    });
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
