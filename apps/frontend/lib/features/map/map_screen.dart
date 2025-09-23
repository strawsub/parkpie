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

  void _rebuildAreaPolygons() {
    if (!_showAreasDebug) {
      _areaPolygons = {};
      return;
    }

    final colors = <Color>[
      const Color(0x661E88E5),
      const Color(0x66D81B60),
      const Color(0x66FDD835),
      const Color(0x66FB8C00),
      const Color(0x668E24AA),
      const Color(0x66E53935),
    ];

    final polys = <Polygon>{};
    for (var i = 0; i < _areas.length; i++) {
      final a = _areas[i];
      final sw = a.bounds.southwest;
      final ne = a.bounds.northeast;
      final nw = LatLng(ne.latitude, sw.longitude);
      final se = LatLng(sw.latitude, ne.longitude);

      polys.add(
        Polygon(
          polygonId: PolygonId('area_poly_${a.id}'),
          points: [sw, se, ne, nw],
          strokeColor: colors[i % colors.length].withValues(alpha: 0.9),
          strokeWidth: 2,
          fillColor: colors[i % colors.length], // already semi-transparent
          consumeTapEvents: true,
          onTap: () {
            // Optional: tap to toast the area name
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

  // -------- Define up to 6 areas  --------
  final List<AreaRect> _areas = [
    AreaRect(
      id: 'area_1',
      label: 'CBD',
      bounds: LatLngBounds(
        southwest: LatLng(-37.821975, 144.952404),
        northeast: LatLng(-37.806830, 144.965086),
      ),
      center: LatLng(-37.814687, 144.957764),
    ),
    AreaRect(
      id: 'area_2',
      label: 'Exhibition',
      bounds: LatLngBounds(
        southwest: LatLng(-37.819280, 144.965107),
        northeast: LatLng(-37.806907, 144.974784),
      ),
      center: LatLng(-37.812419, 144.969385),
    ),
    AreaRect(
      id: 'area_3',
      label: 'East Melbourne',
      bounds: LatLngBounds(
        southwest: LatLng(-37.815430, 144.974707),
        northeast: LatLng(-37.808655, 144.991408),
      ),
      center: LatLng(-37.812566, 144.982362),
    ),
    AreaRect(
      id: 'area_4',
      label: 'Docklands Yarra Side',
      bounds: LatLngBounds(
        southwest: LatLng(-37.823307, 144.940629),
        northeast: LatLng(-37.815116, 144.952317),
      ),
      center: LatLng(-37.820141, 144.946072),
    ),
    AreaRect(
      id: 'area_5',
      label: 'Docklands Waterfront',
      bounds: LatLngBounds(
        southwest: LatLng(-37.815496, 144.933781),
        northeast: LatLng(-37.809201, 144.952300),
      ),
      center: LatLng(-37.813609, 144.939131),
    ),
    AreaRect(
      id: 'area_6',
      label: 'North Melbourne',
      bounds: LatLngBounds(
        southwest: LatLng(-37.807090, 144.946975),
        northeast: LatLng(-37.797487, 144.970498),
      ),
      center: LatLng(-37.800017, 144.957455),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _generateIcons();
    if (_showAreasDebug) {
      _rebuildAreaPolygons();
    }
  }

  Future<void> _generateIcons() async {
    _avgCarIcon = await _iconFromAsset(
      Icons.directions_car_filled,
      color: Colors.redAccent,
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
