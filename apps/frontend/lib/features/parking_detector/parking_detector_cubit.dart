import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'parking_detector_state.dart';
import 'sensors_service.dart'; // 导入新创建的服务

class ParkingDetectorCubit extends Cubit<ParkingDetectorState> {
  final SensorsService _sensorsService;
  final Duration _parkingTimeout = const Duration(seconds: 15);
  final double _parkingSpeedThreshold = 1.0; // in m/s (3.6 km/h)
  StreamSubscription<Position>? _positionSubscription;
  Timer? _parkingTimer;

  ParkingDetectorCubit(this._sensorsService) : super(const ParkingDetectorState()) {
    _startListeningToSensors();
  }

  void _startListeningToSensors() {
    _positionSubscription = _sensorsService.position$.listen((position) {
      _checkParkingStatus(position);
    });
    // 你也可以订阅加速度流：
    // _sensorsService.userAccMag$.listen((mag) {
    //   // 根据加速度数据进行更精细的判断
    // });
  }

  void _checkParkingStatus(Position position) {
    final speed = position.speed;

    if (speed < _parkingSpeedThreshold) {
      // 速度低于阈值，可能正在停车
      if (state.state != ParkingState.parking) {
        // 如果之前不是停车状态，就启动计时器
        emit(state.copyWith(state: ParkingState.parking, startParkingPosition: position));
        _startParkingConfirmationTimer();
      }
    } else {
      // 速度正常，正在行驶
      emit(const ParkingDetectorState());
      _parkingTimer?.cancel();
    }
    emit(state.copyWith(lastPosition: position));
  }

  void _startParkingConfirmationTimer() {
    _parkingTimer?.cancel();
    _parkingTimer = Timer(_parkingTimeout, () {
      if (state.state == ParkingState.parking) {
        // 计时器结束后，如果状态仍为 'parking'，则确认已泊车
        emit(state.copyWith(state: ParkingState.parked));
        _parkingTimer?.cancel();
        // 通知后端服务
        _notifyBackend();
      }
    });
  }

  void _notifyBackend() {
    // TBD: 在这里调用你的后端服务来保存泊车信息
    print('Parking detected! Notifying backend...');
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    _parkingTimer?.cancel();
    return super.close();
  }
}
