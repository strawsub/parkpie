part of 'package:frontend/features/map/map_screen.dart';

LatLng _ewkbPointToLatLng(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  final buffer = ByteData.sublistView(bytes);

  if (bytes[0] != 1) {
    throw ArgumentError('Only little-endian EWKB supported');
  }

  final type = buffer.getUint32(1, Endian.little);
  final hasSrid = (type & 0x20000000) != 0;
  final baseType = (type & 0x0FFFFFFF);
  if (baseType != 1) throw ArgumentError('Expected Point geometry');

  var offset = 5;
  if (hasSrid) {
    final srid = buffer.getUint32(offset, Endian.little);
    if (srid != 4326) throw ArgumentError('Expected SRID 4326, got $srid');
    offset += 4;
  }

  final lon = buffer.getFloat64(offset, Endian.little);
  final lat = buffer.getFloat64(offset + 8, Endian.little);
  return LatLng(lat, lon);
}

extension MapScreenAreaLogic on MapScreenCubit {
  Future<void> _preloadClusterIcons() async {
    final counts = [
      ...List.generate(50, (i) => i + 1),
      60,
      70,
      80,
      90,
      100,
      150,
      200,
      300,
      500,
      999,
    ];

    for (final count in counts) {
      _clusterIconCache[count] = await _createClusterIcon(count);
    }

    if (!isClosed) {
      _emitState(state.copyWith(iconsLoaded: true));
      _rebuildMarkers();
    }
  }

  Future<void> _loadAreasFromApi() async {
    const endpoint =
        'https://parkpie-90018.azurewebsites.net/api/map/getallsegments';

    _emitState(state.copyWith(isLoadingAreas: true));

    try {
      final resp = await http.get(Uri.parse(endpoint));
      if (resp.statusCode != 200) {
        debugPrint('Failed to load segments: status ${resp.statusCode}');
        _emitState(state.copyWith(isLoadingAreas: false));
        return;
      }

      final rawData = json.decode(resp.body);
      if (rawData is! List) {
        debugPrint('Unexpected segment payload');
        _emitState(state.copyWith(isLoadingAreas: false));
        return;
      }

      final loaded = <AreaRect>[];
      for (final raw in rawData) {
        final m = raw as Map<String, dynamic>;
        final id = m['id'].toString();
        final label = m['label']?.toString() ?? 'Segment $id';

        final sw = _ewkbPointToLatLng(m['location_sw']['value'] as String);
        final ne = _ewkbPointToLatLng(m['location_ne']['value'] as String);
        final center = _ewkbPointToLatLng(
          m['location_center']['value'] as String,
        );

        loaded.add(
          AreaRect(
            id: 'area_$id',
            label: label,
            bounds: LatLngBounds(southwest: sw, northeast: ne),
            center: center,
          ),
        );
      }

      final polygons = state.showAreasDebug
          ? _buildPolygonsForAreas(loaded)
          : <Polygon>{};

      _emitState(
        state.copyWith(
          areas: loaded,
          areaPolygons: polygons,
          isLoadingAreas: false,
        ),
      );
      _rebuildMarkers();
    } catch (error, stackTrace) {
      debugPrint('Failed to load segments: ${error.runtimeType}: $error');
      debugPrintStack(stackTrace: stackTrace);
      _emitState(state.copyWith(isLoadingAreas: false));
    }
  }

  Set<Polygon> _buildPolygonsForAreas(List<AreaRect> areas) {
    if (areas.isEmpty) {
      return {};
    }

    final stroke = const Color(0xFFFF5252);
    final fill = const Color(0x33FF5252);
    final polys = <Polygon>{};

    for (final area in areas) {
      final sw = area.bounds.southwest;
      final ne = area.bounds.northeast;
      final nw = LatLng(ne.latitude, sw.longitude);
      final se = LatLng(sw.latitude, ne.longitude);

      polys.add(
        Polygon(
          polygonId: PolygonId('area_poly_${area.id}'),
          points: [sw, se, ne, nw],
          strokeColor: stroke,
          strokeWidth: 2,
          fillColor: fill,
          consumeTapEvents: true,
          onTap: () {
            _emitState(
              state
            );
          },
        ),
      );
    }

    return polys;
  }

  void toggleAreasDebug() {
    final on = !state.showAreasDebug;
    final polys = on ? _buildPolygonsForAreas(state.areas) : <Polygon>{};

    _emitState(state.copyWith(showAreasDebug: on, areaPolygons: polys));
    _rebuildMarkers();
  }

  LatLng _computeCentroid(List<Pin> pins) {
    double lat = 0, lng = 0;
    int n = 0;
    for (final pin in pins) {
      if (pin.lat != null && pin.lng != null) {
        lat += pin.lat!;
        lng += pin.lng!;
        n++;
      }
    }
    return n == 0 ? state.initialPosition : LatLng(lat / n, lng / n);
  }

  Map<AreaRect, List<Pin>> _groupPinsByArea(List<Pin> pins) {
    final map = {for (final area in state.areas) area: <Pin>[]};
    for (final pin in pins) {
      if (pin.lat == null || pin.lng == null) continue;
      final pos = LatLng(pin.lat!, pin.lng!);
      for (final area in state.areas) {
        if (_boundsContain(area.bounds, pos)) {
          map[area]!.add(pin);
          break;
        }
      }
    }
    return map;
  }

  bool _boundsContain(LatLngBounds bounds, LatLng point) {
    final sw = bounds.southwest;
    final ne = bounds.northeast;
    return point.latitude >= sw.latitude &&
        point.latitude <= ne.latitude &&
        point.longitude >= sw.longitude &&
        point.longitude <= ne.longitude;
  }

  Set<Marker> _prepareMarkers(List<Pin> pins) {
    if (state.filterActive) {
      return state.filteredRawMarkers;
    }

    // Show individual markers when zoomed in
    if (state.renderZoom >= state.pinZoomThreshold) {
      return _buildParkingMarkers(pins);
    }

    // Wait for cluster icons to load
    if (!state.iconsLoaded) {
      return {};
    }

    // Show cluster markers when zoomed out
    if (state.areas.isNotEmpty) {
      final grouped = _groupPinsByArea(pins);
      final markers = <Marker>{};
      for (final entry in grouped.entries) {
        final area = entry.key;
        final relatedPins = entry.value;
        if (relatedPins.isEmpty) continue;
        markers.add(_buildAreaMarker(area, relatedPins.length));
      }
      if (markers.isNotEmpty) {
        return markers;
      }
    }

    // Fallback: show average marker
    if (pins.isEmpty) {
      return {};
    }

    return {_buildAverageMarker(pins)};
  }

  // Build individual parking markers
  Set<Marker> _buildParkingMarkers(List<Pin> pins) {
    return pins.where((p) => p.lat != null && p.lng != null).map((pin) {
      final pos = LatLng(pin.lat!, pin.lng!);
      final markerId = 'pin_${(pin.id ?? '${pin.lat}_${pin.lng}').toString()}';
      return Marker(
        markerId: MarkerId(markerId),
        position: pos,
        onTap: () => _handleParkingMarkerTap(pin, pos),
        icon: BitmapDescriptor.defaultMarkerWithHue(214.0),
      );
    }).toSet();
  }

  Marker _buildAreaMarker(AreaRect area, int count) {
    final icon = _getClusterIcon(count);

    return Marker(
      markerId: MarkerId('area_${area.id}'),
      position: area.center,
      icon: icon,
      infoWindow: InfoWindow(
        title: '${area.label} - $count',
        snippet: 'Tap to zoom in',
        onTap: () {
          if (state.isAnimating) return;
          _animateCamera(area.center, zoom: state.pinZoomThreshold + 1);
        },
      ),
    );
  }

  Marker _buildAverageMarker(List<Pin> pins) {
    final center = _computeCentroid(pins);
    final count = pins.length;
    final icon = _getClusterIcon(count);

    return Marker(
      markerId: const MarkerId('avg_pin'),
      position: center,
      icon: icon,
      infoWindow: InfoWindow(
        title: '$count spots',
        snippet: 'Tap to zoom in',
        onTap: () {
          if (state.isAnimating) return;
          final targetZoom = (state.liveZoom + 2).clamp(2.0, 20.0);
          _animateCamera(center, zoom: targetZoom);
        },
      ),
    );
  }

  BitmapDescriptor _getClusterIcon(int count) {
    if (_clusterIconCache.containsKey(count)) {
      return _clusterIconCache[count]!;
    }

    int closestCount = 1;
    for (final cachedCount in _clusterIconCache.keys) {
      if (cachedCount <= count && cachedCount > closestCount) {
        closestCount = cachedCount;
      }
    }

    if (count > 999) {
      return _clusterIconCache[999] ?? _clusterIconCache[1]!;
    }

    return _clusterIconCache[closestCount] ?? _clusterIconCache[1]!;
  }

  // Create cluster icon with green theme
  Future<BitmapDescriptor> _createClusterIcon(int count) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    double displaySize = 40.0;
    if (count >= 100) {
      displaySize = 45.0;
    } else if (count >= 10) {
      displaySize = 35.0;
    }

    // Use 3.0 for high-resolution retina displays (iPhone, modern Android)
    const double pixelRatio = 3.0;
    final double renderSize = displaySize * pixelRatio;

    final paint = Paint()
      ..color = const Color(0xFF7FAC58)
      ..style = PaintingStyle.fill;

    final center = Offset(renderSize / 2, renderSize / 2);
    final radius = renderSize / 2;
    canvas.drawCircle(center, radius, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * pixelRatio;
    canvas.drawCircle(center, radius - (1 * pixelRatio), borderPaint);

    final textSpan = TextSpan(
      text: count.toString(),
      style: TextStyle(
        color: Colors.white,
        fontSize: (displaySize * 0.4) * pixelRatio,
        fontWeight: FontWeight.bold,
        fontFamily: 'Roboto',
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    final textOffset = Offset(
      (renderSize - textPainter.width) / 2,
      (renderSize - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    final picture = recorder.endRecording();
    final image = await picture.toImage(renderSize.toInt(), renderSize.toInt());
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: displaySize,  // Display at original size, but render at high-res
      height: displaySize,
    );
  }
}
