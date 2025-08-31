import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'parking_detector_cubit.dart';
import 'sensors_service.dart';

// 提供 SensorsService 的实例，并在应用销毁时停止它
final sensorsServiceProvider = Provider<SensorsService>((ref) {
  final service = SensorsService();
  service.start();
  ref.onDispose(() {
    service.stop();
  });
  return service;
});

// 提供 ParkingDetectorCubit 的实例
final parkingDetectorProvider = Provider<ParkingDetectorCubit>((ref) {
  final sensorsService = ref.watch(sensorsServiceProvider);
  return ParkingDetectorCubit(sensorsService);
});
