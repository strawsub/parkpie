import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'location_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HistoryMapScreen extends StatelessWidget {
  const HistoryMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History Map")),
      body: BlocBuilder<LocationCubit, LocationState>(
        builder: (context, state) {
          if (state.filteredPosition == null || state.filteredPosition!.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final lat = state.filteredPosition![0];
          final lng = state.filteredPosition![1];

          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(lat, lng),
              zoom: 16,
            ),
            markers: {
              if (state.rawPosition != null)
                Marker(
                  markerId: const MarkerId('raw'),
                  position: LatLng(
                      state.rawPosition!.latitude, state.rawPosition!.longitude),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed),
                ),
              Marker(
                markerId: const MarkerId('filtered'),
                position: LatLng(lat, lng),
                icon:
                    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
            },
          );
        },
      ),
    );
  }
}
