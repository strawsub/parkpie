import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(-37.8035820, 144.9593280),
          initialZoom: 10,
          minZoom: 0,
          maxZoom: 100,
        ),
        children: [
          mapTileLayer,
          mapMarkerLayer,
        ],
      ),

    );
  }
}

TileLayer get mapTileLayer => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.parkpie.frontend',
);

MarkerLayer get mapMarkerLayer => MarkerLayer(
  markers: [
    Marker(
      point: LatLng(-37.8035820, 144.9593280),
      width: 40,
      height: 40,
      child: SvgPicture.asset(
        'assets/park_sign.svg',
        width: 40,
        height: 40,
      ),
    ),
  ],
);