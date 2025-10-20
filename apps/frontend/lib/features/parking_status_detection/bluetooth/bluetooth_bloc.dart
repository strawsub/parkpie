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

    debugPrint('=== BluetoothBloc._onStatusChanged ===');
    debugPrint('event.isConnected: ${event.isConnected}');
    debugPrint('_wasConnected: $_wasConnected');

    if (event.isConnected) {
      // Car connection detected (Bluetooth or CarPlay) - likely driving
      vote = SensorVote.driving;
      _wasConnected = true;
      debugPrint('CONNECTED → vote: driving, _wasConnected set to true');
    } else if (_wasConnected) {
      // Car connection disconnected after being connected - likely parked
      vote = SensorVote.parked;
      debugPrint('DISCONNECTED (was connected) → vote: PARKED');
    } else {
      // No connection history
      vote = SensorVote.unknown;
      debugPrint('DISCONNECTED (no history) → vote: unknown');
    }

    debugPrint('Emitting BluetoothConnectionStatus with vote: $vote');
    debugPrint('=======================================');

    emit(BluetoothConnectionStatus(
      vote: vote,
      isConnected: event.isConnected,
      wasConnected: _wasConnected,
      deviceName: event.deviceName,
    ));
  }

  Future<void> _onReset(ResetBluetooth event, Emitter<BluetoothState> emit) async {
    _wasConnected = false;
    emit(const BluetoothInitial());

    // Force immediate refresh of audio route - this will check hardware and emit status
    await _service.forceRefresh();
    // The emission will be caught by the stream listener (line 29-34)
    // No need to manually add BluetoothStatusChanged - stream will handle it
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _service.dispose();
    return super.close();
  }
}
