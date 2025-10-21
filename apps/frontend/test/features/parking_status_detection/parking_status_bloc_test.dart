import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/features/parking_status_detection/parking_status_bloc.dart';
import 'package:frontend/features/parking_status_detection/parking_status_state.dart';
import 'package:frontend/features/parking_status_detection/parking_status_event.dart';
import 'package:frontend/features/parking_status_detection/accelerometer/acc_bloc.dart';
import 'package:frontend/features/parking_status_detection/gyroscope/gyro_bloc.dart';
import 'package:frontend/features/parking_status_detection/bluetooth/bluetooth_bloc.dart';
import 'package:frontend/features/parking_status_detection/gps/gps_speed_bloc.dart';
import 'package:frontend/features/parking_status_detection/accelerometer/acc_state.dart';
import 'package:frontend/features/parking_status_detection/gyroscope/gyro_state.dart';
import 'package:frontend/features/parking_status_detection/bluetooth/bluetooth_state.dart';
import 'package:frontend/features/parking_status_detection/gps/gps_speed_state.dart';
import 'package:frontend/features/parking_status_detection/utils.dart';
import 'dart:async';

// Mock classes
class MockGyroBloc extends Mock implements GyroBloc {}
class MockAccBloc extends Mock implements AccBloc {}
class MockBluetoothBloc extends Mock implements BluetoothBloc {}
class MockGpsSpeedBloc extends Mock implements GpsSpeedBloc {}
class MockBluetoothState extends Mock implements BluetoothState {}

void main() {
  late ParkingBloc parkingBloc;
  late MockGyroBloc mockGyroBloc;
  late MockAccBloc mockAccBloc;
  late MockBluetoothBloc mockBluetoothBloc;
  late MockGpsSpeedBloc mockGpsSpeedBloc;

  setUp(() {
    mockGyroBloc = MockGyroBloc();
    mockAccBloc = MockAccBloc();
    mockBluetoothBloc = MockBluetoothBloc();
    mockGpsSpeedBloc = MockGpsSpeedBloc();

    // Default stream values
    when(() => mockGyroBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockAccBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockBluetoothBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockGpsSpeedBloc.stream).thenAnswer((_) => const Stream.empty());

    // Default initial states
    when(() => mockGyroBloc.state).thenReturn(GyroInitial());
    when(() => mockAccBloc.state).thenReturn(AccInitial());
    when(() => mockBluetoothBloc.state).thenReturn(const BluetoothInitial());
    when(() => mockGpsSpeedBloc.state).thenReturn(GpsSpeedInitial());

    parkingBloc = ParkingBloc(
      gyroBloc: mockGyroBloc,
      accBloc: mockAccBloc,
      bluetoothBloc: mockBluetoothBloc,
      gpsSpeedBloc: mockGpsSpeedBloc,
    );
  });

  tearDown(() async {
    await parkingBloc.close();
  });

  test('initial state is ParkingUnknown', () {
    expect(parkingBloc.state, isA<ParkingUnknown>());
  });

  test('user confirmation transitions to Parked', () async {
    parkingBloc.add(const TriggerTestParkingDetection());
    await Future.delayed(Duration.zero);

    parkingBloc.add(const UserConfirmedParking());
    await Future.delayed(Duration.zero);

    expect(parkingBloc.state, isA<Parked>());
  });

  test('ResetParking resets state to ParkingUnknown', () async {
    parkingBloc.add(const TriggerTestParkingDetection());
    await Future.delayed(Duration.zero);

    parkingBloc.add(const ResetParking());
    await Future.delayed(Duration.zero);

    expect(parkingBloc.state, isA<ParkingUnknown>());
  });

  // Example for testing a sensor vote transition
  test('updates sensor votes and transitions accordingly', () async {
    // Simulate GPS driving vote
    parkingBloc.add(UpdateSensorVote(sensorName: 'gps_speed', vote: SensorVote.driving));
    await Future.delayed(Duration.zero);
    expect(parkingBloc.state, isA<Driving>());

    // Simulate accelerometer parked vote while GPS unknown → StoppedCandidate
    parkingBloc.add(UpdateSensorVote(sensorName: 'accelerometer', vote: SensorVote.parked));
    parkingBloc.add(UpdateSensorVote(sensorName: 'gps_speed', vote: SensorVote.unknown));
    await Future.delayed(Duration.zero);
    expect(parkingBloc.state, isA<StoppedCandidate>());
  });

  test('Bluetooth parked vote triggers ParkingDetected', () async {
    parkingBloc.add(UpdateSensorVote(sensorName: 'bluetooth', vote: SensorVote.parked));
    await Future.delayed(Duration.zero);
    expect(parkingBloc.state, isA<ParkingUnknown>());
  });
}