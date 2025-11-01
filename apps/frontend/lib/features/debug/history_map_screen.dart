import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:frontend/services/gps_correction/kalman_filter.dart';
import 'package:geolocator/geolocator.dart';

class HistoryMapScreen extends StatefulWidget {
  const HistoryMapScreen({super.key});

  @override
  State<HistoryMapScreen> createState() => _HistoryMapScreenState();
}

class _HistoryMapScreenState extends State<HistoryMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final List<LatLng> _rawPoints = [];
  final List<LatLng> _filteredPoints = [];
  KalmanFilter? _kalmanFilter;
  StreamSubscription<Position>? _positionSub;
  final Set<Polyline> _polylines = {};
  
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.6812, 139.7671), // Tokyo default - will update to current location
    zoom: 18,
  );

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    // Request permissions
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      return;
    }

    // Start listening to position updates
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // minimum distance (meters) before updates
      ),
    ).listen((Position position) {
      if (!mounted) return;
      
      final lat = position.latitude;
      final lng = position.longitude;

      // Initialize Kalman filter with first point
      _kalmanFilter ??= KalmanFilter(lat, lng);

      // Add raw point
      final rawPoint = LatLng(lat, lng);
      _rawPoints.add(rawPoint);

      // Add filtered point
      final filtered = _kalmanFilter!.filter(lat, lng);
      final filteredPoint = LatLng(filtered[0], filtered[1]);
      _filteredPoints.add(filteredPoint);

      setState(() {
        // Update polylines
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('raw'),
            points: _rawPoints,
            color: Colors.red,
            width: 3,
          ),
        );
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('filtered'),
            points: _filteredPoints,
            color: Colors.blue,
            width: 3,
          ),
        );
      });

      // Move camera to follow current position
      _updateCamera(filteredPoint);
    });
  }

  Future<void> _updateCamera(LatLng target) async {
    final controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newLatLng(target),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS History Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _rawPoints.clear();
                _filteredPoints.clear();
                _polylines.clear();
                _kalmanFilter = null;
              });
            },
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _initialPosition,
              polylines: _polylines,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 3,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    const Text('Raw GPS Data'),
                    const SizedBox(width: 24),
                    Container(
                      width: 20,
                      height: 3,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    const Text('Kalman Filtered'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Points: ${_rawPoints.length} raw, ${_filteredPoints.length} filtered',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}