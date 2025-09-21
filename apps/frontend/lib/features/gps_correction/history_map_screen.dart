import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'location_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HistoryMapScreen extends StatelessWidget {
  const HistoryMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 開始追蹤位置
    context.read<LocationCubit>().startTracking();

    return Scaffold(
      appBar: AppBar(title: const Text("History Map")),
      body: BlocBuilder<LocationCubit, LocationState>(
        builder: (context, state) {
          if ((state.filteredPosition == null || state.filteredPosition!.isEmpty) &&
              state.rawHistory.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final markers = <Marker>{};

          // 過去所有原始位置 (小紅點)
          for (int i = 0; i < state.rawHistory.length; i++) {
            final pos = state.rawHistory[i];
            markers.add(Marker(
              markerId: MarkerId('raw_$i'),
              position: LatLng(pos.latitude, pos.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: 'Past Raw Position'),
            ));
          }

          // 過去所有校正位置 (小綠點)
          for (int i = 0; i < state.filteredHistory.length; i++) {
            final fPos = state.filteredHistory[i];
            markers.add(Marker(
              markerId: MarkerId('filtered_$i'),
              position: LatLng(fPos[0], fPos[1]),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'Past Filtered Position'),
            ));
          }

          // 最新紅色 marker (原始位置)
          if (state.rawPosition != null) {
            markers.add(Marker(
              markerId: const MarkerId('raw_latest'),
              position: LatLng(state.rawPosition!.latitude, state.rawPosition!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: 'Latest Raw Position'),
            ));
          }

          // 最新綠色 marker (校正位置)
          if (state.filteredPosition != null) {
            markers.add(Marker(
              markerId: const MarkerId('filtered_latest'),
              position: LatLng(state.filteredPosition![0], state.filteredPosition![1]),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'Latest Filtered Position'),
            ));
          }

          // 初始鏡頭位置
          final initialLatLng = state.filteredPosition != null
              ? LatLng(state.filteredPosition![0], state.filteredPosition![1])
              : (state.rawHistory.isNotEmpty
                  ? LatLng(state.rawHistory.last.latitude, state.rawHistory.last.longitude)
                  : const LatLng(0, 0));

          return GoogleMap(
            initialCameraPosition: CameraPosition(target: initialLatLng, zoom: 16),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          );
        },
      ),
    );
  }
}
