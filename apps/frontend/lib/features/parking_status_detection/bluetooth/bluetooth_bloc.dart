import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'bluetooth_event.dart';
import 'bluetooth_state.dart';
import '../utils.dart';
import 'audio_bluetooth_service.dart';

class BluetoothBloc extends Bloc<BluetoothEvent, BluetoothState> {
  final AudioBluetoothService _service = AudioBluetoothService();
  StreamSubscription<AudioRouteStatus>? _subscription;
  bool _wasConnected = false;

  BluetoothBloc() : super(const BluetoothInitial()) {
    on<InitializeBluetooth>(_onInitialize);
    on<BluetoothStatusChanged>(_onStatusChanged);
    on<ResetBluetooth>(_onReset);

    // Auto-initialize
    add(const InitializeBluetooth());
  }

  Future<void> _onInitialize(
    InitializeBluetooth event,
    Emitter<BluetoothState> emit,
  ) async {
    try {
      await _service.initialize();
      _subscription = _service.statusStream.listen((status) {
        add(BluetoothStatusChanged(
          isConnected: status.isBluetoothConnected,
          deviceName: status.currentRouteName,
        ));
      });
    } catch (e) {
      debugPrint('Failed to initialize Bluetooth monitoring: $e');
      // Continue with unknown state
    }
  }

  void _onStatusChanged(
    BluetoothStatusChanged event,
    Emitter<BluetoothState> emit,
  ) {
    SensorVote vote;

    if (event.isConnected) {
      // Bluetooth connected - likely driving
      vote = SensorVote.driving;
      _wasConnected = true;
    } else if (_wasConnected) {
      // Bluetooth disconnected after being connected - likely parked
      vote = SensorVote.parked;
    } else {
      // No connection history
      vote = SensorVote.unknown;
    }

    emit(BluetoothConnectionStatus(
      vote: vote,
      isConnected: event.isConnected,
      wasConnected: _wasConnected,
      deviceName: event.deviceName,
    ));
  }

  void _onReset(ResetBluetooth event, Emitter<BluetoothState> emit) {
    _wasConnected = false;
    emit(const BluetoothInitial());
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _service.dispose();
    return super.close();
  }
}
