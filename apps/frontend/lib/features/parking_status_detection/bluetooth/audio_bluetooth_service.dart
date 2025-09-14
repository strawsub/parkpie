import 'dart:async';
import 'package:flutter_audio_output/flutter_audio_output.dart';

class AudioBluetoothService {
  static final AudioBluetoothService _instance = AudioBluetoothService._internal();
  factory AudioBluetoothService() => _instance;
  AudioBluetoothService._internal();

  final StreamController<AudioRouteStatus> _statusController =
      StreamController<AudioRouteStatus>.broadcast();

  bool _isInitialized = false;
  AudioInput? _currentRoute;
  Timer? _routeCheckTimer;

  Stream<AudioRouteStatus> get statusStream => _statusController.stream;

  AudioRouteStatus getCurrentStatus() {
    return AudioRouteStatus(
      isBluetoothConnected: _currentRoute?.port == AudioPort.bluetooth,
      currentRouteName: _currentRoute?.name ?? 'Unknown',
      currentRouteType: _currentRoute?.port.toString() ?? 'Unknown',
      bluetoothDeviceNames: _currentRoute?.name != null && _currentRoute!.port == AudioPort.bluetooth
          ? [_currentRoute!.name!]
          : [],
      error: null,
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _checkAudioRoute();
      _startMonitoring();
      _isInitialized = true;
    } catch (e) {
      _statusController.add(AudioRouteStatus(
        isBluetoothConnected: false,
        currentRouteName: 'Unknown',
        currentRouteType: 'Unknown',
        bluetoothDeviceNames: [],
        error: e.toString(),
      ));
    }
  }

  void _startMonitoring() {
    _routeCheckTimer?.cancel();
    _routeCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkAudioRoute(),
    );
  }

  Future<void> _checkAudioRoute() async {
    try {
      final current = await FlutterAudioOutput.getCurrentOutput();
      
      if (_hasRouteChanged(_currentRoute, current)) {
        _currentRoute = current;
        _emitStatus();
      }
    } catch (e) {
      _statusController.add(AudioRouteStatus(
        isBluetoothConnected: false,
        currentRouteName: 'Unknown',
        currentRouteType: 'Unknown',
        bluetoothDeviceNames: [],
        error: e.toString(),
      ));
    }
  }

  bool _hasRouteChanged(AudioInput? previous, AudioInput? current) {
    return previous?.port != current?.port || previous?.name != current?.name;
  }

  void _emitStatus() {
    _statusController.add(AudioRouteStatus(
      isBluetoothConnected: _currentRoute?.port == AudioPort.bluetooth,
      currentRouteName: _currentRoute?.name ?? 'Unknown',
      currentRouteType: _currentRoute?.port.toString() ?? 'Unknown',
      bluetoothDeviceNames: _currentRoute?.port == AudioPort.bluetooth && _currentRoute?.name != null
          ? [_currentRoute!.name!]
          : [],
      error: null,
    ));
  }

  Future<void> dispose() async {
    _routeCheckTimer?.cancel();
    await _statusController.close();
    _isInitialized = false;
  }
}

class AudioRouteStatus {
  final bool isBluetoothConnected;
  final String currentRouteName;
  final String currentRouteType;
  final List<String> bluetoothDeviceNames;
  final String? error;

  const AudioRouteStatus({
    required this.isBluetoothConnected,
    required this.currentRouteName,
    required this.currentRouteType,
    required this.bluetoothDeviceNames,
    this.error,
  });
}