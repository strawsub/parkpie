import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'parking_detector_cubit.dart';
import 'sensors_service.dart';

// provide SensorsService instance，and close it when the app is closed
final sensorsServiceProvider = Provider<SensorsService>((ref) {
  final service = SensorsService();
  service.start();
  ref.onDispose(() {
    service.stop();
  });
  return service;
});

// using autoDispose to close it when the app is closed
final parkingDetectorProvider = Provider.autoDispose<ParkingDetectorCubit>((ref) {
  final sensorsService = ref.read(sensorsServiceProvider);
  final cubit = ParkingDetectorCubit(sensorsService);
  ref.onDispose(() {
    cubit.close();
  });
  return cubit;
});
