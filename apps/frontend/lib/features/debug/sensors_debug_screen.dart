// lib/features/debug/debug_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/features/map/pin/pin_cubit.dart';
import 'package:frontend/features/map/pin/pin_state.dart';
import 'package:frontend/features/parking_status_detection/parking_status_bloc.dart';
import 'package:frontend/features/parking_status_detection/parking_status_event.dart';
import 'package:frontend/features/parking_status_detection/parking_status_state.dart';
import 'package:frontend/features/parking_status_detection/bluetooth/bluetooth_bloc.dart';
import 'package:frontend/features/parking_status_detection/bluetooth/bluetooth_state.dart';
import 'package:frontend/features/parking_status_detection/gps/gps_speed_bloc.dart';
import 'package:frontend/features/parking_status_detection/gps/gps_speed_state.dart';
import 'package:frontend/features/parking_status_detection/accelerometer/acc_bloc.dart';
import 'package:frontend/features/parking_status_detection/accelerometer/acc_state.dart';
import 'package:frontend/features/parking_status_detection/gyroscope/gyro_bloc.dart';
import 'package:frontend/features/parking_status_detection/gyroscope/gyro_state.dart';
import 'package:frontend/features/parking_status_detection/utils.dart';
import 'package:frontend/features/settings/language/language_selection_page.dart';
import 'package:frontend/features/settings/privacy_disclosure_page.dart';
import 'package:frontend/l10n/app_localizations_ext.dart';

// Helper: safely read a Provider/Bloc; returns null if not found (no exception)
T? maybeReadBloc<T>(BuildContext context) {
  try {
    return context.read<T>();
  } catch (_) {
    return null;
  }
}

class SensorsDebugScreen extends StatefulWidget {
  const SensorsDebugScreen({super.key});
  @override
  State<SensorsDebugScreen> createState() => _SensorsDebugScreenState();
}

class _SensorsDebugScreenState extends State<SensorsDebugScreen> {
  // API diagnostics
  final String _apiBaseShown = const String.fromEnvironment(
    'API_BASE_URL',
    // Default to your Azure endpoint for on-device testing
    defaultValue: 'https://parkpie-90018.azurewebsites.net',
  );

  String? _lastPingResult;

  Future<void> _pingAzure() async {
    final uri = Uri.parse(
      'https://parkpie-90018.azurewebsites.net/api/map/getlocforpin',
    );
    try {
      final t0 = DateTime.now();
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final ms = DateTime.now().difference(t0).inMilliseconds;
      final body = res.body;
      final previewLen = math.min(
        body.length,
        200,
      ); // avoid clamp's num typing issue
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
    final BluetoothBloc? bluetoothBloc = maybeReadBloc<BluetoothBloc>(context);
    final GpsSpeedBloc? gpsSpeedBloc = maybeReadBloc<GpsSpeedBloc>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Debug / Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'App is running. This is a developer diagnostics page.',
            style: TextStyle(fontSize: 16),
          ),
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
                      String details = '';
                      Color c = Colors.blueGrey;

                      if (state is ParkingUnknown) c = Colors.blueGrey;
                      if (state is Driving) c = Colors.orange;
                      if (state is StoppedCandidate) {
                        c = Colors.yellow;
                        final duration = DateTime.now()
                            .difference(state.candidateStartTime)
                            .inSeconds;

                        details =
                            '\nDuration: ${duration}s\nWaiting for: BT disconnect, Gyro spike (instant), or 60s timeout';
                      }
                      if (state is ParkingDetected) c = Colors.purple;
                      if (state is Parked) c = Colors.green;

                      return ListTile(
                        title: const Text('ParkingBloc State'),
                        subtitle: Text('$label$details'),
                        trailing: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                          ),
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
                onPressed: parkingBloc == null
                    ? null
                    : () => parkingBloc.add(ResetParking()),
                child: const Text('Reset Parking'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: parkingBloc == null
                    ? null
                    : () => parkingBloc.add(UserConfirmedParking()),
                child: const Text('Confirm Parking'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Accelerometer Stillness Details (from AccBloc)
          Card(
            child: BlocBuilder<AccBloc, AccState>(
              builder: (context, accState) {
                if (accState is AccReading) {
                  final rms = accState.currentRMS ?? 0.0;
                  final quietRatio = accState.quietRatio ?? 0.0;
                  final isStill = accState.vote == SensorVote.parked;
                  final stillIcon = isStill ? '🟢' : '🔴';

                  return ListTile(
                    title: Text('Accelerometer Stillness $stillIcon'),
                    subtitle: Text(
                      'RMS: ${rms.toStringAsFixed(3)} [Enter ≤0.40, Exit ≥0.45]\n'
                      'Quiet Ratio: ${(quietRatio * 100).toStringAsFixed(0)}% [Need ≥70%]\n'
                      'Status: ${isStill ? "STILL (parked)" : "MOVING (driving)"}',
                    ),
                  );
                }
                return const ListTile(
                  title: Text('Accelerometer Stillness'),
                  subtitle: Text('Initializing...'),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Gyroscope Details (from GyroBloc)
          Card(
            child: BlocBuilder<GyroBloc, GyroState>(
              builder: (context, gyroState) {
                if (gyroState is GyroReading) {
                  final maxRotation = gyroState.maxRotation ?? 0.0;
                  final isSpike = gyroState.vote == SensorVote.parked;
                  final spikeIcon = isSpike ? '🟢' : '🔴';

                  return ListTile(
                    title: Text('Gyroscope Rotation $spikeIcon'),
                    subtitle: Text(
                      'Max Rotation: ${maxRotation.toStringAsFixed(3)} rad/s\n'
                      'Threshold: >0.8 rad/s triggers spike (parked vote)\n'
                      'Status: ${isSpike ? "SPIKE DETECTED (parked)" : "No spike (driving)"}\n'
                      'Note: Only active in StoppedCandidate state\n'
                      'Behavior: Instant promotion to ParkingDetected (no freeze)',
                    ),
                  );
                }
                return const ListTile(
                  title: Text('Gyroscope Rotation'),
                  subtitle: Text('Initializing...'),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Bluetooth sensor (from BluetoothBloc)
          Card(
            child: (bluetoothBloc == null)
                ? const ListTile(
                    title: Text('Bluetooth Sensor'),
                    subtitle: Text('⚠️ BluetoothBloc provider not found'),
                  )
                : BlocBuilder<BluetoothBloc, BluetoothState>(
                    bloc: bluetoothBloc,
                    builder: (context, state) {
                      if (state is BluetoothInitial) {
                        return const ListTile(
                          title: Text('Bluetooth Sensor'),
                          subtitle: Text('Waiting for first status update...'),
                        );
                      }

                      final voteLabel = state.vote.toString().split('.').last;
                      final statusLabel = state.isConnected
                          ? 'Connected'
                          : 'Disconnected';
                      final deviceLabel = state.deviceName ?? 'Unknown device';
                      final hasHistory =
                          state is BluetoothConnectionStatus &&
                          state.wasConnected;
                      final historyLine = hasHistory
                          ? 'Device has connected earlier in this session.'
                          : 'No previous connections detected.';

                      return ListTile(
                        title: Text('Bluetooth Sensor ($statusLabel)'),
                        subtitle: Text(
                          'Vote: $voteLabel\nDevice: $deviceLabel\n$historyLine',
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 8),

          // Bluetooth status - Using BluetoothBloc for consistency
          Card(
            child: (bluetoothBloc == null)
                ? const ListTile(
                    title: Text('Audio Route Status'),
                    subtitle: Text('⚠️ BluetoothBloc provider not found'),
                  )
                : BlocBuilder<BluetoothBloc, BluetoothState>(
                    bloc: bluetoothBloc,
                    builder: (context, state) {
                      if (state is BluetoothInitial) {
                        return const ListTile(
                          title: Text('Audio Route Status'),
                          subtitle: Text('Initializing...'),
                        );
                      }

                      final bluetoothIcon = state.isConnected ? '🛜' : '📱';
                      final routeText = state.isConnected
                          ? 'Bluetooth Audio'
                          : 'Phone Audio';
                      final deviceInfo = state.deviceName != null
                          ? 'Device: ${state.deviceName}'
                          : 'No device connected';
                      final connectionStatus = state.isConnected
                          ? 'Connected to Bluetooth'
                          : 'Using phone speaker/wired';

                      return ListTile(
                        title: Text('Audio Route $bluetoothIcon'),
                        subtitle: Text(
                          '$routeText\n$connectionStatus\n$deviceInfo',
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 8),

          // GPS Speed Sensor Display
          Card(
            child: (gpsSpeedBloc == null)
                ? const ListTile(
                    title: Text('🛰️ GPS Speed Sensor'),
                    subtitle: Text('⚠️ GpsSpeedBloc provider not found'),
                  )
                : BlocBuilder<GpsSpeedBloc, GpsSpeedState>(
                    bloc: gpsSpeedBloc,
                    builder: (context, state) {
                      if (state is GpsSpeedInitial) {
                        return const ListTile(
                          title: Text('🛰️ GPS Speed Sensor'),
                          subtitle: Text('Initializing...'),
                        );
                      }

                      if (state is GpsSpeedReading) {
                        final vote = state.vote.toString().split('.').last;
                        final voteIcon = vote == 'driving'
                            ? '🚗'
                            : vote == 'parked'
                            ? '🅿️'
                            : '❓';

                        final rawSpeedKmh = state.rawSpeed * 3.6;
                        final filteredSpeedKmh = state.filteredSpeed * 3.6;
                        final displacement = state.windowDisplacement;
                        final candidateSec = state.candidateSeconds;
                        final accuracy = state.accuracy ?? -1;
                        final scenario = state.accuracyScenario;

                  // Scenario-based thresholds (updated to match current unified threshold)
                  final String vThreshold, dWindow, tCandidate, tConfirm;
                  final String scenarioIcon;

                  switch (scenario) {
                    case "good":
                      vThreshold = "2.78";  // Unified threshold (10 km/h)
                      dWindow = "12.0";
                      tCandidate = "3.0"; tConfirm = "4.0";
                      scenarioIcon = "🟢";
                      break;
                    case "medium":
                      vThreshold = "2.78";  // Unified threshold (10 km/h)
                      dWindow = "16.0";
                      tCandidate = "3.0"; tConfirm = "5.0";
                      scenarioIcon = "🟡";
                      break;
                    case "poor":
                    default:
                      vThreshold = "2.78";  // Unified threshold (10 km/h)
                      dWindow = "20.0";
                      tCandidate = "3.0"; tConfirm = "6.0";
                      scenarioIcon = "🔴";
                      break;
                  }

                  return ListTile(
                    title: Text('🛰️ GPS Speed Sensor $voteIcon'),
                    subtitle: Text(
                        'Vote: $vote | Scenario: $scenario $scenarioIcon\n'
                            'Speed: ${filteredSpeedKmh.toStringAsFixed(1)} km/h filtered | ${rawSpeedKmh.toStringAsFixed(1)} km/h raw\n'
                            'Speed Threshold: ${vThreshold}m/s (10.0 km/h) - UNIFIED for all speeds\n'
                            'Displacement: ${displacement.toStringAsFixed(1)} m [dWindow=${dWindow}m]\n'
                            'Linear Distance Required: 10.0 m for driving confirmation\n'
                            'Candidate: ${candidateSec.toStringAsFixed(1)} s [tCand=${tCandidate}s, tConf=${tConfirm}s]\n'
                            'Accuracy: ${accuracy.toStringAsFixed(1)} m\n'
                            'Logic: Speed > 10km/h = driving, ≤10km/h = parked (no "unknown")'
                    ),
                  );
                }

                      return const ListTile(
                        title: Text('🛰️ GPS Speed Sensor'),
                        subtitle: Text('Unknown state'),
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
                      final drivingVotes = votes.values
                          .where((v) => v.toString().contains('driving'))
                          .length;
                      final parkedVotes = votes.values
                          .where((v) => v.toString().contains('parked'))
                          .length;

                      // Build individual sensor vote display (only active sensors)
                      List<String> sensorLines = [];

                      // Accelerometer
                      if (votes.containsKey('accelerometer')) {
                        final vote = votes['accelerometer']
                            .toString()
                            .split('.')
                            .last;
                        sensorLines.add(
                          '• accelerometer → $vote ${vote == 'driving' ? '✅' : '🅿️'}',
                        );
                      } else {
                        sensorLines.add('• accelerometer → (no vote) ⚪');
                      }

                      // Gyroscope (only active in StoppedCandidate)
                      if (votes.containsKey('gyroscope')) {
                        final vote = votes['gyroscope']
                            .toString()
                            .split('.')
                            .last;
                        final isStoppedCandidate = state is StoppedCandidate;
                        final activeIndicator = isStoppedCandidate
                            ? ''
                            : ' (DISABLED)';
                        sensorLines.add(
                          '• gyroscope → $vote ${vote == 'parked' ? '🅿️' : '⚪'}$activeIndicator',
                        );
                      } else {
                        sensorLines.add('• gyroscope → (no vote) ⚪');
                      }

                      // Bluetooth
                      if (votes.containsKey('bluetooth')) {
                        final vote = votes['bluetooth']
                            .toString()
                            .split('.')
                            .last;
                        sensorLines.add(
                          '• bluetooth → $vote ${vote == 'driving' ? '✅' : '🅿️'}',
                        );
                      } else {
                        sensorLines.add('• bluetooth → (no vote) ⚪');
                      }

                      // GPS Speed
                      if (votes.containsKey('gps_speed')) {
                        final vote = votes['gps_speed']
                            .toString()
                            .split('.')
                            .last;
                        sensorLines.add(
                          '• gps_speed → $vote ${vote == 'driving'
                              ? '✅'
                              : vote == 'parked'
                              ? '🅿️'
                              : '❓'}',
                        );
                      } else {
                        sensorLines.add('• gps_speed → (no vote) ⚪');
                      }

                      // Note: Pedometer/Walking not implemented (removed by linter)

                      final voteCountText =
                          'Driving: $drivingVotes | Parked: $parkedVotes';
                      final sensorText = sensorLines.join('\n');

                      return ListTile(
                        title: const Text('🗳️ Sensor Votes (4 active)'),
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
                  const Text(
                    'API Diagnostics',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Base (override via --dart-define): $_apiBaseShown'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _pingAzure,
                        child: const Text('Ping Azure'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: pinCubit == null
                            ? null
                            : () => pinCubit.loadPins(),
                        child: const Text('Load Pins via Cubit'),
                      ),
                    ],
                  ),
                  if (_lastPingResult != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _lastPingResult!,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                        return const ListTile(
                          title: Text('Pins'),
                          subtitle: Text('Loading...'),
                        );
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

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.getString('language.settingsTitle'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.getString('language.settingsSubtitle')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.language),
                      label: Text(
                        context.l10n.getString('language.settingsAction'),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LanguageSelectionPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.getString('privacy.settingsTitle'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.getString('privacy.settingsSubtitle')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.privacy_tip_outlined),
                      label: Text(
                        context.l10n.getString('privacy.settingsAction'),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyDisclosurePage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
