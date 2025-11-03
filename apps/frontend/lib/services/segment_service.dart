import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class SegmentData {
  final String segId;
  final List<LatLng> points;
  late final double area;

  SegmentData({required this.segId, required this.points}) {
    area = _calculateArea(points);
  }

  // Calculate area using the Shoelace formula
  double _calculateArea(List<LatLng> pts) {
    if (pts.length < 3) return 0.0;
    double sum = 0;
    for (int i = 0; i < pts.length; i++) {
      final j = (i + 1) % pts.length;
      sum += pts[i].longitude * pts[j].latitude -
          pts[j].longitude * pts[i].latitude;
    }
    return sum.abs() / 2.0;
  }
}

class SegmentService {
  List<SegmentData> segments = [];
  Map<String, int> segmentCounts = {};

  Future<void> loadSegments(String assetPath) async {
    final String data = await rootBundle.loadString(assetPath);
    final geojson = json.decode(data);

    final List<SegmentData> tempSegments = [];
    for (var feature in geojson['features']) {
      if (feature['geometry']['type'] == 'MultiPolygon') {
        for (var polyCoords in feature['geometry']['coordinates']) {
          List outer = polyCoords[0];
          List<LatLng> line = outer.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();

          String segId = feature['properties']['segid'].toString();
          tempSegments.add(SegmentData(segId: segId, points: line));
        }
      }
    }

    segments = tempSegments;
  }

  Future<void> loadCountsFromApi() async {
    final url = Uri.parse(
      'https://parkpie-90018.azurewebsites.net/api/segment/getlocationforsegment',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final Map<String, int> counts = {};
        for (var item in data) {
          final segId = item['segid']?.toString();
          final count = item['count'] ?? 0;
          if (segId != null) counts[segId] = count;
        }
        segmentCounts = counts;
      }
    } catch (e) {
      debugPrint('Error loading from API: $e');
    }
  }

  Set<Polygon> buildPolygons({
    double minOpacity = 0.4,
    double maxOpacity = 0.9,
  }) {
    if (segments.isEmpty || segmentCounts.isEmpty) return {};

    // Calculate densities
    Map<String, double> densities = {};
    for (var seg in segments) {
      final count = (segmentCounts[seg.segId] ?? 0).toDouble();
      if (count > 0 && seg.area > 0) {
        densities[seg.segId] = count / seg.area;
      }
    }

    if (densities.isEmpty) return {};

    final maxDensity = densities.values.reduce(max);

    return segments
        .where((seg) => densities.containsKey(seg.segId))
        .map((seg) {
          final density = densities[seg.segId]!;
          final t = (density / maxDensity).clamp(0.0, 1.0);
          final fillColor = Color.lerp(
            Colors.yellow.withValues(alpha: minOpacity),
            Colors.red.withValues(alpha: maxOpacity),
            t,
          )!;

          return Polygon(
            polygonId: PolygonId(seg.segId),
            points: seg.points,
            fillColor: fillColor,
            strokeColor: Colors.transparent,
            strokeWidth: 0,
          );
        })
        .toSet();
  }
}
