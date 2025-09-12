import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  }

  @override
  Widget build(BuildContext context) {
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
    );
  }
}
