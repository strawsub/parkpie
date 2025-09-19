import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SegmentMapScreen extends StatefulWidget {
  const SegmentMapScreen({super.key});

  @override
  State<SegmentMapScreen> createState() => _SegmentMapScreenState();
}

class _SegmentMapScreenState extends State<SegmentMapScreen> {
  GoogleMapController? _mapController;
  List<List<LatLng>> _segments = [];
  List<LatLng> _parkingPoints = [];
  Set<Polygon> _polygons = {};
  static const LatLng _initialPosition = LatLng(-37.8136, 144.9631);

  @override
  void initState() {
    super.initState();
    _loadSegmentsFromGeoJson().then((_) {
      _generateRandomParkingPoints();
      _assignCountsToSegments();
    });
  }

  Future<void> _loadSegmentsFromGeoJson() async {
    final String data = await rootBundle.loadString('assets/road_segment.geojson');
    final Map<String, dynamic> geojson = json.decode(data);

    final List<List<LatLng>> segments = [];

    for (var feature in geojson['features']) {
      if (feature['geometry']['type'] == 'MultiPolygon') {
        List coordsList = feature['geometry']['coordinates'];
        for (var polyCoords in coordsList) {
          // polyCoords[0] 是外框
          List outer = polyCoords[0];
          List<LatLng> line = outer.map<LatLng>((c) {
            double lng = (c[0] as num).toDouble();
            double lat = (c[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();
          segments.add(line);
        }
      }
    }

    setState(() {
      _segments = segments;
    });
  }

  void _generateRandomParkingPoints() {
    final rand = Random();
    for (int i = 0; i < 100; i++) {
      double lat = -37.818 + rand.nextDouble() * 0.005;
      double lng = 144.961 + rand.nextDouble() * 0.007;
      _parkingPoints.add(LatLng(lat, lng));
    }
  }

  double _distanceSquared(LatLng a, LatLng b) {
    return pow(a.latitude - b.latitude, 2).toDouble() +
        pow(a.longitude - b.longitude, 2).toDouble();
  }

  List<LatLng> _findClosestSegment(LatLng point) {
    double minDist = double.infinity;
    List<LatLng> closest = _segments.first;
    for (var seg in _segments) {
      for (var p in seg) {
        double d = _distanceSquared(point, p);
        if (d < minDist) {
          minDist = d;
          closest = seg;
        }
      }
    }
    return closest;
  }

  void _assignCountsToSegments() {
    final Map<List<LatLng>, int> segmentCounts = {};
    for (var seg in _segments) {
      segmentCounts[seg] = 0;
    }

    for (var point in _parkingPoints) {
      final seg = _findClosestSegment(point);
      segmentCounts[seg] = (segmentCounts[seg] ?? 0) + 1;
    }

    int maxCount = segmentCounts.values.isEmpty ? 1 : segmentCounts.values.reduce(max);

    setState(() {
      _polygons = _segments.map((seg) {
        int count = segmentCounts[seg] ?? 0;
        double t = max(0.05, count / maxCount); // 確保 count = 0 也有淡色
        Color color = Color.lerp(Colors.blue.withOpacity(0.2), Colors.red, t)!;
        return Polygon(
          polygonId: PolygonId(seg.hashCode.toString()),
          points: seg,
          fillColor: color,
          strokeColor: Colors.transparent,
          strokeWidth: 0,
        );
      }).toSet();
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Segment Map Heat')),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(
          target: _initialPosition,
          zoom: 15,
        ),
        polygons: _polygons,
        mapType: MapType.normal,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
      ),
    );
  }
}
