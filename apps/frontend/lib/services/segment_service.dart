import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class SegmentData {
  final String segId;
  final List<LatLng> points;
  SegmentData({required this.segId, required this.points});
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
        'https://parkpie-90018.azurewebsites.net/api/segment/getlocationforsegment');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      final Map<String, int> counts = {};
      for (var item in data) {
        final segId = item['segid']?.toString();
        final count = item['count'] ?? 0;
        if (segId != null) counts[segId] = count;
      }
      segmentCounts = counts;
    } else {
      debugPrint('Failed to load counts from API');
    }
  }

  Set<Polygon> buildPolygons({double minOpacity = 0.5, double maxOpacity = 0.8}) {
    if (segments.isEmpty || segmentCounts.isEmpty) return {};

    int maxCount = segmentCounts.values.reduce(max);

    return segments.where((seg) {
      return (segmentCounts[seg.segId] ?? 0) > 0;
    }).map((seg) {
      int count = segmentCounts[seg.segId] ?? 0;
      double t = count / maxCount;
      Color fillColor = Color.lerp(
        Colors.yellow.withOpacity(minOpacity),
        Colors.red.withOpacity(maxOpacity),
        t,
      )!;

      return Polygon(
        polygonId: PolygonId(seg.segId),
        points: seg.points,
        fillColor: fillColor,
        strokeColor: Colors.transparent,
        strokeWidth: 0,
      );
    }).toSet();
  }
}
