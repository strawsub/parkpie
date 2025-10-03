part of 'package:frontend/features/map/map_screen.dart';

LatLng _ewkbPointToLatLng(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  final b = ByteData.sublistView(bytes);

  if (bytes[0] != 1) {
    throw ArgumentError('Only little-endian EWKB supported');
  }

  final type = b.getUint32(1, Endian.little);
  final hasSrid = (type & 0x20000000) != 0;
  final baseType = (type & 0x0FFFFFFF);
  if (baseType != 1) throw ArgumentError('Expected Point geometry');

  var off = 5;
  if (hasSrid) {
    final srid = b.getUint32(off, Endian.little);
    if (srid != 4326) throw ArgumentError('Expected SRID 4326, got $srid');
    off += 4;
  }

  final lon = b.getFloat64(off, Endian.little);
  final lat = b.getFloat64(off + 8, Endian.little);
  return LatLng(lat, lon);
}

mixin _MapScreenAreaMixin on _MapScreenStateFields {
  void _rebuildAreaPolygons() {
    if (!_showAreasDebug) {
      _areaPolygons = {};
      return;
    }

    final stroke = const Color(0xFFFF5252).withValues(); // light red stroke
    final fill = const Color(0x33FF5252); // light red fill, ~20% opacity

    final polys = <Polygon>{};
    for (final a in _areas) {
      final sw = a.bounds.southwest;
      final ne = a.bounds.northeast;
      final nw = LatLng(ne.latitude, sw.longitude);
      final se = LatLng(sw.latitude, ne.longitude);

      polys.add(
        Polygon(
          polygonId: PolygonId('area_poly_${a.id}'),
          points: [sw, se, ne, nw],
          strokeColor: stroke,
          strokeWidth: 2,
          fillColor: fill,
          consumeTapEvents: true,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(a.label),
                duration: const Duration(milliseconds: 800),
              ),
            );
          },
        ),
      );
    }
    _areaPolygons = polys;
  }

  Future<void> _loadAreasFromApi() async {
    try {
      final uri = Uri.parse(
        'https://parkpie-90018.azurewebsites.net/api/map/getallsegments',
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        debugPrint('Failed to load segments: status ${resp.statusCode}');
        return;
      }

      final rawData = json.decode(resp.body);
      if (rawData is! List) {
        debugPrint('Unexpected segment payload');
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

      if (!mounted) return;
      setState(() {
        _areas = loaded;
        if (_showAreasDebug) {
          _rebuildAreaPolygons();
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load segments: ${error.runtimeType}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  LatLng _computeCentroid(List<Pin> pins) {
    double lat = 0, lng = 0;
    int n = 0;
    for (final p in pins) {
      if (p.lat != null && p.lng != null) {
        lat += p.lat!;
        lng += p.lng!;
        n++;
      }
    }
    return n == 0 ? _initialPosition : LatLng(lat / n, lng / n);
  }

  bool _boundsContain(LatLngBounds b, LatLng p) {
    final sw = b.southwest;
    final ne = b.northeast;
    return p.latitude >= sw.latitude &&
        p.latitude <= ne.latitude &&
        p.longitude >= sw.longitude &&
        p.longitude <= ne.longitude;
  }

  Map<AreaRect, List<Pin>> _groupPinsByArea(List<Pin> pins) {
    final Map<AreaRect, List<Pin>> map = {for (final a in _areas) a: <Pin>[]};
    for (final p in pins) {
      if (p.lat == null || p.lng == null) continue;
      final pos = LatLng(p.lat!, p.lng!);
      for (final a in _areas) {
        if (_boundsContain(a.bounds, pos)) {
          map[a]!.add(p);
          break;
        }
      }
    }
    return map;
  }

  Future<BitmapDescriptor> _createClusterIcon(int count) async {
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    double displaySize = 40.0;
    if (count >= 100) {
      displaySize = 45.0;
    } else if (count >= 10) {
      displaySize = 35.0;
    }

    const double pixelRatio = 1;
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

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(renderSize.toInt(), renderSize.toInt());
    final bytes = await img.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
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

    if (mounted) {
      setState(() {
        _iconsLoaded = true;
      });
    }
  }

  Set<Marker> _buildParkingMarkers(List<Pin> pins) {
    return pins.where((p) => p.lat != null && p.lng != null).map((pin) {
      final pos = LatLng(pin.lat!, pin.lng!);
      final markerId = 'pin_${(pin.id ?? '${pin.lat}_${pin.lng}').toString()}';
      return Marker(
        markerId: MarkerId(markerId),
        position: pos,
        onTap: () => _showParkingInfo(context, pin),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
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
        onTap: () async {
          if (_isAnimating) return;
          _isAnimating = true;
          try {
            await _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: area.center,
                  zoom: _pinZoomThreshold + 1,
                ),
              ),
            );
          } finally {
            _isAnimating = false;
          }
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
        onTap: () async {
          if (_isAnimating) return;
          _isAnimating = true;
          try {
            await _mapController?.animateCamera(CameraUpdate.zoomBy(2.0));
          } finally {
            _isAnimating = false;
          }
        },
      ),
    );
  }

  void _showParkingInfo(BuildContext context, Pin pin) {
    final pos = LatLng(pin.lat!, pin.lng!);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ParkingInfoSheet(
        location: pos,
        id: pin.id,
        occupancyPercent: pin.occupancyPercent,
        startTime: pin.startTime,
        endTime: pin.endTime,
        maximumStayMinutes: pin.maximumStayMinutes,
        description: pin.description,
      ),
    );
  }
}
