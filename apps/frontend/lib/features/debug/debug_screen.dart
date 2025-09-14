// lib/features/debug/debug_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/features/map/pin/pin_cubit.dart';
import 'package:frontend/features/map/pin/pin_state.dart';
import 'package:frontend/features/parking_status_detection/parking_status_bloc.dart';
import 'package:frontend/features/parking_status_detection/parking_status_event.dart';
import 'package:frontend/features/parking_status_detection/parking_status_state.dart';
import 'package:frontend/features/parking_status_detection/bluetooth/audio_bluetooth_service.dart';

// Helper: safely read a Provider/Bloc; returns null if not found (no exception)
T? maybeReadBloc<T>(BuildContext context) {
  try {
    return context.read<T>();
  } catch (_) {
    return null;
  }
}

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  // Sensor subscription
  StreamSubscription<UserAccelerometerEvent>? _accSub;
  double _ax = 0, _ay = 0, _az = 0;

  // Bluetooth service
  final AudioBluetoothService _bluetoothService = AudioBluetoothService();

  // Simple RMS over the last N samples
  final int _winN = 50;
  final List<double> _magBuf = [];
  double get _rms {
    if (_magBuf.isEmpty) return 0;
    double sumSq = 0;
    for (final m in _magBuf) {
      sumSq += m * m;
    }
    return math.sqrt(sumSq / _magBuf.length);
  }

  // API diagnostics
  final String _apiBaseShown = const String.fromEnvironment(
    'API_BASE_URL',
    // Default to your Azure endpoint for on-device testing
    defaultValue: 'https://parkpie-90018.azurewebsites.net',
  );

  String? _lastPingResult;

  @override
  void initState() {
    super.initState();
    // Only subscribe to sensor here; do not read providers in initState
    _accSub = userAccelerometerEventStream().listen((e) {
      final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      setState(() {
        _ax = e.x;
        _ay = e.y;
        _az = e.z;
        _magBuf.add(mag);
        if (_magBuf.length > _winN) _magBuf.removeAt(0);
      });
    });
    
    // Initialize Bluetooth service
    _bluetoothService.initialize();
  }

  @override
  void dispose() {
    _accSub?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }

  Future<void> _pingAzure() async {
    final uri = Uri.parse('https://parkpie-90018.azurewebsites.net/api/map/getlocforpin');
    try {
      final t0 = DateTime.now();
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final ms = DateTime.now().difference(t0).inMilliseconds;
      final body = res.body;
      final previewLen = math.min(body.length, 200); // avoid clamp's num typing issue
      setState(() {
        _lastPingResult =
        "HTTP ${res.statusCode} in ${ms}ms, body=${body.substring(0, previewLen)}...";
      });
    } catch (e) {
      setState(() => _lastPingResult = "Ping failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safely read providers in build; return null if missing
    final PinCubit? pinCubit = maybeReadBloc<PinCubit>(context);
    final ParkingBloc? parkingBloc = maybeReadBloc<ParkingBloc>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Debug / Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('App is running. This is a developer diagnostics page.', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 16),

          // ParkingBloc state
          Card(
            child: (parkingBloc == null)
                ? const ListTile(
              title: Text('ParkingBloc State'),
              subtitle: Text('⚠️ ParkingBloc provider not found'),
            )
                : BlocBuilder<ParkingBloc, ParkingState>(
              bloc: parkingBloc, // bind the instance explicitly
              builder: (context, state) {
                String label = state.runtimeType.toString();
                Color c = Colors.blueGrey;
                if (state is ParkingUnknown) c = Colors.blueGrey;
                if (state is Driving) c = Colors.orange;
                if (state is ParkingDetected) c = Colors.purple;
                if (state is Parked) c = Colors.green;
                return ListTile(
                  title: const Text('ParkingBloc State'),
                  subtitle: Text(label),
                  trailing: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Actions (disable when provider is missing)
          Row(
            children: [
              ElevatedButton(
                onPressed: parkingBloc == null ? null : () => parkingBloc.add(ResetParking()),
                child: const Text('Reset Parking'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: parkingBloc == null ? null : () => parkingBloc.add(UserConfirmedParking()),
                child: const Text('Confirm Parking'),
              ),
            ],
          ),


          const SizedBox(height: 16),

          // Sensor readout
          Card(
            child: ListTile(
              title: const Text('Accelerometer (user)'),
              subtitle: Text(
                'ax=${_ax.toStringAsFixed(3)}, ay=${_ay.toStringAsFixed(3)}, az=${_az.toStringAsFixed(3)}\n'
                    'RMS≈${_rms.toStringAsFixed(3)} (window $_winN)',
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Bluetooth status
          Card(
            child: StreamBuilder<AudioRouteStatus>(
              stream: _bluetoothService.statusStream,
              initialData: _bluetoothService.getCurrentStatus(),
              builder: (context, snapshot) {
                final status = snapshot.data;
                if (status == null) {
                  return const ListTile(
                    title: Text('Bluetooth Status'),
                    subtitle: Text('Initializing...'),
                  );
                }

                if (status.error != null) {
                  return ListTile(
                    title: const Text('Bluetooth Status'),
                    subtitle: Text('❌ Error: ${status.error}'),
                  );
                }

                final bluetoothIcon = status.isBluetoothConnected ? '🛜' : '📱';
                final routeText = status.isBluetoothConnected ? 'Bluetooth Audio' : 'Phone Audio';
                final currentRouteInfo = 'Current: ${status.currentRouteName} (${status.currentRouteType})';
                final availableInfo = status.bluetoothDeviceNames.isNotEmpty 
                    ? 'Available Bluetooth: ${status.bluetoothDeviceNames.join(', ')}'
                    : 'No Bluetooth audio devices available';

                return ListTile(
                  title: Text('Audio Route $bluetoothIcon'),
                  subtitle: Text('$routeText\n$currentRouteInfo\n$availableInfo'),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Sensor Voting Display
          Card(
            child: (parkingBloc == null)
                ? const ListTile(
              title: Text('🗳️ Sensor Votes'),
              subtitle: Text('⚠️ ParkingBloc provider not found'),
            )
                : BlocBuilder<ParkingBloc, ParkingState>(
              bloc: parkingBloc,
              builder: (context, state) {
                final votes = state.sensorVotes;
                final drivingVotes = votes.values.where((v) => v.toString().contains('driving')).length;
                final parkedVotes = votes.values.where((v) => v.toString().contains('parked')).length;

                // Build individual sensor vote display
                List<String> sensorLines = [];
                
                // Check each possible sensor
                if (votes.containsKey('accelerometer')) {
                  final vote = votes['accelerometer'].toString().split('.').last;
                  sensorLines.add('• accelerometer → $vote ${vote == 'driving' ? '✅' : '🅿️'}');
                } else {
                  sensorLines.add('• accelerometer → (no vote) ⚪');
                }
                
                if (votes.containsKey('gyroscope')) {
                  final vote = votes['gyroscope'].toString().split('.').last;
                  sensorLines.add('• gyroscope → $vote ${vote == 'driving' ? '✅' : '🅿️'}');
                } else {
                  sensorLines.add('• gyroscope → (no vote) ⚪');
                }
                
                if (votes.containsKey('bluetooth')) {
                  final vote = votes['bluetooth'].toString().split('.').last;
                  sensorLines.add('• bluetooth → $vote ${vote == 'driving' ? '✅' : '🅿️'}');
                } else {
                  sensorLines.add('• bluetooth → (no vote) ⚪');
                }

                final voteCountText = 'Driving: $drivingVotes | Parked: $parkedVotes';
                final sensorText = sensorLines.join('\n');

                return ListTile(
                  title: const Text('🗳️ Sensor Votes'),
                  subtitle: Text('$voteCountText\n$sensorText'),
                );
              },
            ),
          ),


          const SizedBox(height: 16),

          // API diagnostics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('API Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Base (override via --dart-define): $_apiBaseShown'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(onPressed: _pingAzure, child: const Text('Ping Azure')),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: pinCubit == null ? null : () => pinCubit.loadPins(),
                        child: const Text('Load Pins via Cubit'),
                      ),
                    ],
                  ),
                  if (_lastPingResult != null) ...[
                    const SizedBox(height: 8),
                    Text(_lastPingResult!, maxLines: 6, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Pins display
          Card(
            child: (pinCubit == null)
                ? const ListTile(
              title: Text('Pins'),
              subtitle: Text('⚠️ PinCubit provider not found'),
            )
                : BlocBuilder<PinCubit, PinState>(
              bloc: pinCubit, // bind the instance explicitly
              builder: (context, state) {
                if (state is PinLoading || state is PinInitial) {
                  return const ListTile(title: Text('Pins'), subtitle: Text('Loading...'));
                }
                if (state is PinError) {
                  return ListTile(
                    title: const Text('Pins (Error)'),
                    subtitle: Text(state.message),
                  );
                }
                final pins = (state as PinLoaded).pins;
                return ListTile(
                  title: const Text('Pins (Loaded)'),
                  subtitle: Text('count = ${pins.length}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
