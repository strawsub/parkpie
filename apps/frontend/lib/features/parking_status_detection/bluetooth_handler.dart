// bluetooth_handler.dart
import 'dart:async';
import 'package:flutter_audio_output/flutter_audio_output.dart';
import 'parking_status_event.dart';
import 'utils.dart';

class BluetoothHandlerService {
  final AudioBluetoothService _service = AudioBluetoothService();
  final Map<String, SensorVote> votes;

  BluetoothHandlerService({required this.votes});

  StreamSubscription<BluetoothStatus>? _sub;

  void initialize(void Function(BluetoothAudioChanged) onEvent) async {
    await _service.initialize();
    _sub = _service.statusStream.listen((status) {
      final event = BluetoothAudioChanged(
        isConnected: status.isBluetoothConnected,
        deviceName: status.currentRouteName,
      );
      onEvent(event);
    });
  }

  void handleEvent(BluetoothAudioChanged e, void Function() updateVotes) {
    final hadBluetoothVote = votes.containsKey('bluetooth_audio');
    final previouslyConnected = hadBluetoothVote
        ? votes['bluetooth_audio'] == SensorVote.driving
        : false;

    if (e.isConnected) {
      votes['bluetooth_audio'] = SensorVote.driving;
    } else if (previouslyConnected) {
      votes['bluetooth_audio'] = SensorVote.parked;
    } else {
      votes.remove('bluetooth_audio');
    }
    updateVotes();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _service.dispose();
  }
}

class AudioBluetoothService {
  static final AudioBluetoothService _instance = AudioBluetoothService._internal();
  factory AudioBluetoothService() => _instance;
  AudioBluetoothService._internal();

  // Stream controllers
  final StreamController<BluetoothStatus> _statusController = 
      StreamController<BluetoothStatus>.broadcast();
  
  // State tracking
  bool _isInitialized = false;
  AudioInput? _currentAudioRoute;
  List<AudioInput> _availableDevices = [];
  
  // Subscriptions
  Timer? _routeCheckTimer;

  // Public getters
  Stream<BluetoothStatus> get statusStream => _statusController.stream;
  bool get isBluetoothAudioConnected => _currentAudioRoute?.port == AudioPort.bluetooth;
  AudioInput? get currentAudioRoute => _currentAudioRoute;
  List<AudioInput> get availableDevices => List.unmodifiable(_availableDevices);

  /// Initialize the Audio Route service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get initial audio route state
      await _checkAudioRoute();
      
      // Start periodic monitoring of audio routes
      _startRouteMonitoring();
      
      _isInitialized = true;
      _updateStatus();
      
    } catch (e) {
      _statusController.add(BluetoothStatus(
        isBluetoothConnected: false,
        currentRoute: null,
        availableRoutes: [],
        error: 'Failed to initialize: $e',
      ));
    }
  }

  /// Start monitoring audio route changes
  void _startRouteMonitoring() {
    // Check audio route every 2 seconds
    _routeCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkAudioRoute();
    });
    
    // Initial check is already done in initialize()
  }

  /// Stop monitoring audio route changes
  void _stopRouteMonitoring() {
    _routeCheckTimer?.cancel();
    _routeCheckTimer = null;
  }

  /// Check current audio route and available devices
  Future<void> _checkAudioRoute() async {
    try {
      final currentOutput = await FlutterAudioOutput.getCurrentOutput();
      final availableInputs = await FlutterAudioOutput.getAvailableInputs();
      
      final previousRoute = _currentAudioRoute;
      _currentAudioRoute = currentOutput;
      _availableDevices = availableInputs;
      
      // Only update status if route actually changed
      if (previousRoute?.port != currentOutput.port || 
          previousRoute?.name != currentOutput.name) {
        _updateStatus();
      }
    } catch (e) {
      _statusController.add(BluetoothStatus(
        isBluetoothConnected: isBluetoothAudioConnected,
        currentRoute: _currentAudioRoute,
        availableRoutes: _availableDevices,
        error: 'Error checking audio route: $e',
      ));
    }
  }

  /// Update status and emit to stream
  void _updateStatus() {
    _statusController.add(BluetoothStatus(
      isBluetoothConnected: isBluetoothAudioConnected,
      currentRoute: _currentAudioRoute,
      availableRoutes: _availableDevices,
    ));
  }

  /// Get current status snapshot
  BluetoothStatus getCurrentStatus() {
    return BluetoothStatus(
      isBluetoothConnected: isBluetoothAudioConnected,
      currentRoute: _currentAudioRoute,
      availableRoutes: _availableDevices,
    );
  }

  /// Dispose resources
  Future<void> dispose() async {
    _stopRouteMonitoring();
    await _statusController.close();
    _isInitialized = false;
  }
}

/// Audio route status data class for Bluetooth audio detection
class BluetoothStatus {
  final bool isBluetoothConnected;
  final AudioInput? currentRoute;
  final List<AudioInput> availableRoutes;
  final String? error;

  const BluetoothStatus({
    required this.isBluetoothConnected,
    required this.currentRoute,
    required this.availableRoutes,
    this.error,
  });

  /// Get current audio route name for display
  String get currentRouteName {
    if (currentRoute == null) return 'Unknown';
    return currentRoute!.name.isNotEmpty ? currentRoute!.name : 'Unknown Route';
  }

  /// Get current audio route type
  String get currentRouteType {
    if (currentRoute == null) return 'unknown';
    switch (currentRoute!.port) {
      case AudioPort.bluetooth:
        return 'bluetooth';
      case AudioPort.speaker:
        return 'speaker';
      case AudioPort.headphones:
        return 'headphones';
      case AudioPort.receiver:
        return 'receiver';
      default:
        return 'unknown';
    }
  }

  /// Get available Bluetooth devices for display
  List<String> get bluetoothDeviceNames {
    return availableRoutes
        .where((device) => device.port == AudioPort.bluetooth)
        .map((device) => device.name.isNotEmpty ? device.name : 'Unknown Bluetooth Device')
        .toList();
  }

  /// Get count of available audio routes
  int get routeCount => availableRoutes.length;

  /// Check if any Bluetooth devices are available
  bool get hasBluetoothDevices => availableRoutes.any((device) => device.port == AudioPort.bluetooth);

  // Legacy properties for backwards compatibility with debug screen
  bool get isEnabled => isBluetoothConnected;
  int get deviceCount => bluetoothDeviceNames.length;
  List<String> get deviceNames => bluetoothDeviceNames;

  @override
  String toString() {
    return 'BluetoothStatus(bluetoothConnected: $isBluetoothConnected, currentRoute: $currentRouteType, routes: $routeCount, error: $error)';
  }
}
