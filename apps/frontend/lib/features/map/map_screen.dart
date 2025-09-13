import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
=======
import 'package:flutter_bloc/flutter_bloc.dart';
>>>>>>> main
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/features/map/parking_info/parking_info_screen.dart';
import 'package:frontend/features/map/pin/pin_cubit.dart';
import 'package:frontend/features/map/pin/pin_state.dart';
import 'package:frontend/features/map/pin/pin_model.dart';
import 'package:frontend/features/parking_status_detected/parking_status_bloc.dart'; // for ParkingBloc
import 'package:frontend/features/debug/debug_screen.dart';

class MapScreen extends StatelessWidget {
  MapScreen({super.key});

  final MapController _mapController = MapController();

<<<<<<< HEAD
  // Resolve API base per platform; override via --dart-define=API_BASE_URL
  String _apiBase() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://localhost:8081';
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:8081';
    return 'http://localhost:8081';
  }

  late final String _apiUrl = '${_apiBase()}/api/map/getsignforpin';

  bool _loading = true;
  String? _error;
  List<Pin> _pins = const [];

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  Future<void> _loadPins() async {
    try {
      final res = await http.get(Uri.parse(_apiUrl));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) throw Exception('Unexpected JSON shape');

      final pins = decoded
          .map((e) => Pin.fromJson(e as Map<String, dynamic>))
          .where((p) => p.lat != null && p.lng != null)
          .toList();

      setState(() {
        _pins = pins;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
=======
  void _showParkingInfo(BuildContext context, LatLng location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParkingInfoSheet(location: location),
    );
  }

  List<Marker> _buildMarkers(BuildContext context, List<Pin> pins) {
    return pins.map((pin) {
      final pos = LatLng(pin.lat!, pin.lng!);
      return Marker(
        point: pos,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showParkingInfo(context, pos),
          child: SvgPicture.asset('assets/park_sign.svg', width: 40, height: 40),
        ),
      );
    }).toList();
>>>>>>> main
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final markers = _pins.map((p) {
      final ll = LatLng(p.lat!, p.lng!);
      return Marker(
        point: ll,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => ParkingInfoSheet(
                location: ll,
                occupancyPercent: p.occupancyPercent,
                startTime: p.startTime,
                endTime: p.endTime,
                maximumStayMinutes: p.maximumStayMinutes,
              ),
            );
          },
          child: SvgPicture.asset(
            'assets/park_sign.svg',
            width: 40,
            height: 40,
          ),
        ),
      );
    }).toList();

=======
>>>>>>> main
    return Scaffold(
      body: BlocBuilder<PinCubit, PinState>(
        builder: (context, state) {
          if (state is PinLoading || state is PinInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PinError) {
            return Center(
              child: Card(
                color: Colors.red.shade700,
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Failed to load pins:\n${state.message}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          }

          final pins = (state as PinLoaded).pins;

          return FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(-37.8035820, 144.9593280),
              initialZoom: 12,
              minZoom: 2,
              maxZoom: 20,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.parkpie.frontend',
              ),
              MarkerLayer(markers: _buildMarkers(context, pins)),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'reloadFab',
            onPressed: () => context.read<PinCubit>().loadPins(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reload'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'debugFab',
            mini: true,
            onPressed: () {
              final pinCubit = context.read<PinCubit>();
              final parkingBloc = context.read<ParkingBloc>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider.value(value: pinCubit),
                      BlocProvider.value(value: parkingBloc),
                    ],
                    child: const DebugScreen(),
                  ),
                ),
              );
            },
            tooltip: 'Debug',
            child: const Icon(Icons.bug_report),
          ),
        ],
      ),
<<<<<<< HEAD
    );
  }
}

class Pin {
  final double? lat;
  final double? lng;
  final double? occupancyPercent;
  final String? startTime;
  final String? endTime;
  final int? maximumStayMinutes;

  const Pin({
    required this.lat,
    required this.lng,
    this.occupancyPercent,
    this.startTime,
    this.endTime,
    this.maximumStayMinutes,
  });

  factory Pin.fromJson(Map<String, dynamic> json) {
    double? toD(dynamic v) => v == null
        ? null
        : (v is num ? v.toDouble() : double.tryParse(v.toString()));

    int? toI(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

    return Pin(
      lat: toD(json['lat']),
      lng: toD(json['lng']),
      occupancyPercent: toD(json['occupancy_percent']),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      maximumStayMinutes: toI(json['maximum_stay_minutes']),
=======
>>>>>>> main
    );
  }
}
