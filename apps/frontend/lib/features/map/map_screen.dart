import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:frontend/features/map/parking_info/parking_info_screen.dart';
import 'package:frontend/features/map/pin/pin_cubit.dart';
import 'package:frontend/features/map/pin/pin_state.dart';
import 'package:frontend/features/map/pin/pin_model.dart';
import 'package:frontend/features/map/search/search_cubit.dart';
import 'package:frontend/features/map/search/search_state.dart';
import 'package:frontend/features/parking_status_detection/parking_status_bloc.dart';
import 'package:frontend/features/debug/debug_screen.dart';

import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// -------- Area clustering config --------

class AreaRect {
  final String id;
  final String label;
  final LatLngBounds bounds;
  final LatLng center; // convenient caching for zoom-to

  const AreaRect({
    required this.id,
    required this.label,
    required this.bounds,
    required this.center,
  });
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();
  Marker? _searchMarker;

  bool _hasCenteredInitially = false;

  // TUNNING PURPOSE ______________________________________________________________________
  final bool _showAreasDebug = false; // toggle to show/hide coverage
  Set<Polygon> _areaPolygons = {};

  List<AreaRect> _areas = [];

  void _rebuildAreaPolygons() {
    if (!_showAreasDebug) {
      _areaPolygons = {};
      return;
    }

    final stroke = const Color(0xFFFF5252).withOpacity(0.9); // light red stroke
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
  // _________________________________________________________________________________________

  // ---------- Zoom behavior ----------
  double _liveZoom = 13.5; // follows camera during movement
  double _renderZoom = 13.5; // the zoom we use to decide what to render
  static const double _pinZoomThreshold = 15; // >= threshold => show all pins
  static const double _hysteresis = 0.5; // buffer to prevent flicker
  bool _isAnimating = false;

  // Custom icon for the single/area markers
  BitmapDescriptor? _avgCarIcon;

  // Melbourne coordinates
  static const LatLng _initialPosition = LatLng(-37.8035820, 144.9593280);

  // GETTING SEGMENTS FROM DB ___________________________________________________________________
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

  Future<void> _loadAreasFromApi() async {
    final uri = Uri.parse('http://192.168.18.12:8081/api/map/getallsegments');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('getallsegments failed: ${resp.statusCode}');
    }

    final List data = json.decode(resp.body) as List;

    final loaded = <AreaRect>[];
    for (final raw in data) {
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

    // debugPrint(
    //   '______________________________________________________________',
    // );
    // for (final a in loaded) {
    //   debugPrint(
    //     'Loaded area: ${a.id} - ${a.label} '
    //     '[SW=${a.bounds.southwest}, NE=${a.bounds.northeast}, Center=${a.center}]',
    //   );
    // }
    // debugPrint('Total areas loaded: ${loaded.length}');
    // debugPrint(
    //   '______________________________________________________________',
    // );

    setState(() {
      _areas = loaded;
    });
  }
  // _________________________________________________________________________________________

  @override
  void initState() {
    super.initState();
    _generateIcons();
    _loadAreasFromApi();
    if (_showAreasDebug) {
      _rebuildAreaPolygons();
    }
  }

  Future<void> _generateIcons() async {
    _avgCarIcon = await _iconFromAsset(
      Icons.directions_car_filled,
      color: Color.fromARGB(255, 18, 9, 146),
      size: 35,
    );
    if (mounted) setState(() {});
  }

  // ---------- Map lifecycle ----------

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    final z = await _mapController?.getZoomLevel();
    if (z != null && mounted) {
      _liveZoom = z;
      _renderZoom = z;
      setState(() {}); // initial draw
    }
  }

  // Track live zoom without rebuilding every frame
  void _onCameraMove(CameraPosition pos) {
    _liveZoom = pos.zoom;
  }

  // Rebuild only when crossing hysteresis bands
  void _onCameraIdle() {
    if (_isAnimating) return;

    final wasShowingPins = _renderZoom >= _pinZoomThreshold;
    final crossedToPins =
        !wasShowingPins && _liveZoom >= (_pinZoomThreshold + _hysteresis / 2);
    final crossedToAvg =
        wasShowingPins && _liveZoom <= (_pinZoomThreshold - _hysteresis / 2);

    if (crossedToPins || crossedToAvg) {
      _renderZoom = _liveZoom;
      setState(() {}); // swap avg/areas <-> all pins
    }
  }

  // ---------- UI helpers ----------

  void _showParkingInfo(BuildContext context, Pin pin) {
    final pos = LatLng(pin.lat!, pin.lng!);

    showModalBottomSheet(
      context: context,
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

  Set<Marker> _buildParkingMarkers(List<Pin> pins) {
    return pins.map((pin) {
      final pos = LatLng(pin.lat!, pin.lng!);
      return Marker(
        markerId: MarkerId('pin_${pin.lat}_${pin.lng}'),
        position: pos,
        onTap: () => _showParkingInfo(context, pin),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
    }).toSet();
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

  // -------- Area cluster helpers --------

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
      // If a pin doesn’t fall into any area, you could choose to:
      // - ignore it in zoomed-out mode, OR
      // - collect into a “Misc” area. Keeping it simple: ignore.
    }
    return map;
  }

  Marker _buildAreaMarker(AreaRect area, int count) {
    final icon =
        _avgCarIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

    return Marker(
      markerId: MarkerId('area_${area.id}'),
      position: area.center,
      icon: icon,
      infoWindow: InfoWindow(
        title: '${area.label} — $count',
        snippet: 'Tap to zoom in',
        onTap: () async {
          if (_isAnimating) return;
          _isAnimating = true;
          try {
            // Zoom toward the area center (a little tighter than threshold)
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

  // Fallback single “average” marker if you haven’t defined areas yet
  Marker _buildAverageMarker(List<Pin> pins) {
    final center = _computeCentroid(pins);
    final count = pins.length;

    return Marker(
      markerId: const MarkerId('avg_pin'),
      position: center,
      icon:
          _avgCarIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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

  Set<Marker> _mergeWithSearch(Set<Marker> base) {
    final all = Set<Marker>.from(base);
    if (_searchMarker != null) all.add(_searchMarker!);
    return all;
  }

  Future<void> _handleSearchSuccess(SearchSuccess state) async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: state.location, zoom: 15),
      ),
    );
    if (!mounted) return;

    setState(() {
      _searchMarker = Marker(
        markerId: MarkerId(state.markerId),
        position: state.location,
        infoWindow: InfoWindow(title: 'Search Result', snippet: state.query),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    });

    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<BitmapDescriptor> _iconFromAsset(
    IconData iconData, {
    Color color = Colors.red,
    double size = 96,
  }) async {
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final textSpan = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: color,
      ),
    );

    textPainter.text = textSpan;
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  void _handleSearchCleared() {
    setState(() => _searchMarker = null);
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  // ---------- Widget ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<SearchCubit, SearchState>(
            listener: (context, state) {
              if (state is SearchLoading) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Searching...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              } else if (state is SearchSuccess) {
                _handleSearchSuccess(state);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Found: ${state.query}')),
                );
              } else if (state is SearchError) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message)));
              } else if (state is SearchCleared) {
                _handleSearchCleared();
              }
            },
          ),
        ],
        child: BlocBuilder<PinCubit, PinState>(
          builder: (context, state) {
            if (state is PinLoading || state is PinInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is PinError) {
              return Center(
                child: Card(
                  color: Colors.red.shade700,
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Failed to load pins:\n${state.message}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            }

            final pins = (state as PinLoaded).pins;

            // Center once on first load (to avg of all pins)
            if (!_hasCenteredInitially &&
                pins.isNotEmpty &&
                _mapController != null) {
              final center = _computeCentroid(pins);
              _hasCenteredInitially = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mapController?.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: center, zoom: _liveZoom),
                  ),
                );
              });
            }

            // Decide what to render based on _renderZoom (debounced)
            final bool showRealPins = _renderZoom >= _pinZoomThreshold;

            Set<Marker> baseMarkers;
            if (showRealPins) {
              baseMarkers = _buildParkingMarkers(pins);
            } else {
              // Area clusters when zoomed out
              if (_areas.isNotEmpty) {
                final grouped = _groupPinsByArea(pins);
                final markers = <Marker>{};
                grouped.forEach((area, ps) {
                  if (ps.isEmpty) return; // only show areas with pins
                  markers.add(_buildAreaMarker(area, ps.length));
                });
                // If none matched any area (or areas empty), fall back to single avg
                baseMarkers = markers.isNotEmpty
                    ? markers
                    : {_buildAverageMarker(pins)};
              } else {
                baseMarkers = {_buildAverageMarker(pins)};
              }
            }

            _markers = _mergeWithSearch(baseMarkers);

            return Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  initialCameraPosition: const CameraPosition(
                    target: _initialPosition,
                    zoom: 13.5,
                  ),
                  markers: _markers,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  minMaxZoomPreference: const MinMaxZoomPreference(2.0, 20.0),
                  polygons: _areaPolygons, // TUNNING PURPOSE
                ),

                // 🔍 Floating Search Bar
                Positioned(
                  top: 40,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(
                              hintText: 'Search location...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            onSubmitted: (query) => context
                                .read<SearchCubit>()
                                .searchLocation(query),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => context
                              .read<SearchCubit>()
                              .searchLocation(_searchController.text),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              context.read<SearchCubit>().clearSearch(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'reloadFab',
            onPressed: () => context.read<PinCubit>().loadPins(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reload'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'debugFab',
            mini: true,
            onPressed: () {
              final pinCubit = context.read<PinCubit>();
              final parkingBloc = context.read<ParkingBloc>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider.value(value: pinCubit),
                      BlocProvider.value(value: parkingBloc),
                    ],
                    child: const DebugScreen(),
                  ),
                ),
              );
            },
            tooltip: 'Debug',
            child: const Icon(Icons.bug_report),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
