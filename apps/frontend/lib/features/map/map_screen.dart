import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:frontend/features/parking_info/parking_info_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  static const String _apiUrl = 'http://localhost:8081/api/map/getlocforpin';

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
  }

  @override
  Widget build(BuildContext context) {
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
              builder: (context) => ParkingInfoSheet(location: ll),
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

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
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
              MarkerLayer(markers: markers),
            ],
          ),

          if (_loading)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_error != null && !_loading)
            Positioned(
              left: 12,
              right: 12,
              bottom: 24,
              child: Card(
                color: Colors.red.shade700,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Failed to load pins:\n$_error',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadPins,
        icon: const Icon(Icons.refresh),
        label: const Text('Reload'),
      ),
    );
  }
}

class Pin {
  final dynamic kerbsideId;
  final double? lat;
  final double? lng;

  const Pin({required this.kerbsideId, required this.lat, required this.lng});

  factory Pin.fromJson(Map<String, dynamic> json) {
    double? toD(dynamic v) => v == null
        ? null
        : (v is num ? v.toDouble() : double.tryParse(v.toString()));

    return Pin(
      kerbsideId: json['kerbsideid'],
      lat: toD(json['lat']),
      lng: toD(json['lng']),
    );
  }
}
