/*  
 *   ############################################################################################
 *   ######################################### INDICES ##########################################
 *   ____________________________________________________________________________________________
 *  |      |                            |                                                        |
 *  | #NO  |   Name                     |   Description                                          |
 *  |------|----------------------------|--------------------------------------------------------|
 *  | #1   |   SEGMENT DEBUGGER         |   Just In case for show segments                       |
 *  | #2   |   SEGMENT GENERATION       |   Generate segments from API and create average pins   |
 *  | #3   |   FILTER HANDLER           |   Open filter panel, apply filter, pick on map         |
 *  | #4   |   MAP OPERATIONS           |   Map creation, camera movement, zoom handling         |
 *  | #5   |   PINNING                  |   Create markers from pin data, custom icons           |
 *  | #6   |   INFO PANEL HANDLER       |   Show parking info bottom sheet                       |
 *  | #7   |   SEARCHING OPERATION      |   Search location, handle search states                |
 *  | #8   |   APP INITIATOR & DISPOSER |   Init and dispose resources                           |
 *  | #9   |   CUSTOMIZED WIDGET ITEMS  |   Customized widgets in build()                        |
 *  |______|____________________________|________________________________________________________|
 * 
 */

import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
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
import 'package:frontend/features/map/filter/filter_config.dart';
import 'package:frontend/features/map/filter/filter_panel.dart';

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
  final LatLng center;

  const AreaRect({
    required this.id,
    required this.label,
    required this.bounds,
    required this.center,
  });
}
// -----------------------------------------

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  Set<Marker> _markers = {};
  Set<Marker> _filteredRawMarkers = {};
  Set<Polygon> _areaPolygons = {};
  List<AreaRect> _areas = [];
  Completer<LatLng?>? _pickCompleter;

  final TextEditingController _searchController = TextEditingController();

  Marker? _searchMarker;
  Marker? _pickerMarker;

  LatLng? _selectedPoint;

  bool _hasCenteredInitially = false;
  bool _isFilterOpen = false;
  bool _isPickingLocation = false;
  bool _filterActive = false;
  bool _isAnimating = false;

  double _liveZoom = 13.5;
  double _renderZoom = 13.5;

  static const double _pinZoomThreshold = 15;
  static const double _hysteresis = 0.5;
  static const LatLng _initialPosition = LatLng(-37.8035820, 144.9593280);

  BitmapDescriptor? _avgCarIcon;

  // ###########################################################################
  // #1 SEGMENT DEBUGGER _______________________________________________________
  final bool _showAreasDebug = false; // toggle to show/hide coverage

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

  // ___________________________________________________________________________
  // ###########################################################################
  // #2 SEGMENT OPERATION _____________________________________________________
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
    final uri = Uri.parse(
      'https://parkpie-90018.azurewebsites.net/api/map/getallsegments',
    );
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

    setState(() {
      _areas = loaded;
      if (_showAreasDebug) {
        _rebuildAreaPolygons();
      }
    });
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

  // ___________________________________________________________________________
  // ###########################################################################
  // #3 FILTER HANDLER__________________________________________________________
  Future<void> _openFilterSheet({FilterConfig? seed}) async {
    _isFilterOpen = true;
    try {
      final result = await showFilterSheet(
        context,
        initial:
            seed ??
            FilterConfig(
              mode: _selectedPoint == null
                  ? LocationMode.current
                  : LocationMode.selected,
              selectedPoint: _selectedPoint,
              radiusMeters: 100,
              durationMinutes: 60,
              startTime: TimeOfDay.now(),
            ),
      );

      if (!mounted) return;

      if (result == kFilterRequestPickOnMap) {
        final picked = await _startPickOnMap();
        if (!mounted || picked == null) return;

        final base =
            seed ??
            FilterConfig(
              mode: LocationMode.selected,
              selectedPoint: picked,
              radiusMeters: 100,
              durationMinutes: 60,
              startTime: TimeOfDay.now(),
            );

        await _openFilterSheet(
          seed: base.copyWith(
            mode: LocationMode.selected,
            selectedPoint: picked,
          ),
        );
        return;
      }

      if (result is FilterConfig) {
        if (result.mode == LocationMode.selected) {
          _selectedPoint = result.selectedPoint;
        }

        _applyFilter(result);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.mode == LocationMode.current
                  ? 'Using current location'
                  : 'Using point: '
                        '${result.selectedPoint?.latitude.toStringAsFixed(5)}, '
                        '${result.selectedPoint?.longitude.toStringAsFixed(5)}',
            ),
          ),
        );
      }
    } finally {
      _isFilterOpen = false;
    }
  }

  Future<void> _applyFilter(FilterConfig config) async {
    final messenger = ScaffoldMessenger.of(context);
    final mapCtrl = _mapController;
    setState(() {
      _markers = {};
    });

    try {
      final LatLng center = config.mode == LocationMode.selected
          ? config.selectedPoint!
          : await _getCurrentLocation();

      final pins = await _fetchPinsWithinRange(
        center: center,
        radius: config.radiusMeters,
        durationMinutes: config.durationMinutes,
        startTime: config.startTime,
      );
      if (!mounted) return;

      final filteredMarkers = _buildParkingMarkers(pins);

      setState(() {
        _filterActive = true;
        _filteredRawMarkers = filteredMarkers;
      });

      await mapCtrl?.animateCamera(CameraUpdate.newLatLng(center));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to filter pins')),
      );
    }
  }

  Future<LatLng> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    // Get current position
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return LatLng(pos.latitude, pos.longitude);
  }

  Future<List<Pin>> _fetchPinsWithinRange({
    required LatLng center,
    required double radius,
    required int durationMinutes,
    required TimeOfDay startTime,
  }) async {
    // Format time as HH:mm:ss
    String two(int n) => n.toString().padLeft(2, '0');
    final restrictionTime =
        '${two(startTime.hour)}:${two(startTime.minute)}:00';

    final uri =
        Uri.parse(
          'https://parkpie-90018.azurewebsites.net/api/map/querybyradius',
        ).replace(
          queryParameters: {
            'lat': center.latitude.toString(),
            'lng': center.longitude.toString(),
            'radius': radius.round().toString(),
            'duration': durationMinutes.toString(),
            'restrictionTime': restrictionTime,
          },
        );

    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception(
        'querybyradius failed: ${resp.statusCode} — ${resp.body}',
      );
    }

    final List data = json.decode(resp.body) as List;

    final pins = <Pin>[];
    for (final raw in data) {
      final m = raw as Map<String, dynamic>;
      final idStr = (m['id'] as num?)?.toInt().toString();
      final ewkb = (m['location'] as Map<String, dynamic>)['value'] as String;
      final pos = _ewkbPointToLatLng(ewkb);

      final pin = Pin(
        id: idStr,
        lat: pos.latitude,
        lng: pos.longitude,
        occupancyPercent: (m['occupancy_percent'] as num?)?.toDouble(),
        maximumStayMinutes: m['maximum_stay_minutes'] as int?,
        startTime: m['start_time'] as String?,
        endTime: m['end_time'] as String?,
        description:
            'Zone ${m['zone_number']} • ${m['distance']?.toStringAsFixed(1)}m away',
      );

      pins.add(pin);
    }

    return pins;
  }

  Future<LatLng?> _startPickOnMap() async {
    _isPickingLocation = true;
    _pickCompleter = Completer<LatLng?>();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tap on the map to choose a point')),
    );

    return _pickCompleter!.future;
  }

  void _handleMapTap(LatLng pos) {
    if (_isPickingLocation) {
      _isPickingLocation = false;
      _selectedPoint = pos;
      _pickerMarker = Marker(
        markerId: const MarkerId('picker'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Selected point'),
      );
      _pickCompleter?.complete(pos);
      _pickCompleter = null;
      setState(() {});
      return;
    }

    _dismissFilterIfOpen();
  }

  void _dismissFilterIfOpen() {
    if (_isFilterOpen) {
      Navigator.of(context).maybePop();
    }
  }

  void _clearFilterAndReload() {
    setState(() {
      _filterActive = false;
      _filteredRawMarkers = {};

      _pickerMarker = null;
      _selectedPoint = null;
    });

    context.read<PinCubit>().loadPins();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Filter cleared. Reloaded pins.')),
    );
  }

  // ___________________________________________________________________________
  // ###########################################################################
  // #4 MAP OPERATIONS _________________________________________________________
  Future<void> _generateIcons() async {
    _avgCarIcon = await _iconFromAsset(
      Icons.directions_car_filled,
      color: Color.fromARGB(255, 18, 9, 146),
      size: 35,
    );
    if (mounted) setState(() {});
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    final z = await _mapController?.getZoomLevel();
    if (z != null && mounted) {
      _liveZoom = z;
      _renderZoom = z;
      setState(() {}); // initial draw
    }
  }

  void _onCameraMove(CameraPosition pos) {
    _liveZoom = pos.zoom;
  }

  void _onCameraIdle() {
    if (_isAnimating) return;

    final wasShowingPins = _renderZoom >= _pinZoomThreshold;
    final crossedToPins =
        !wasShowingPins && _liveZoom >= (_pinZoomThreshold + _hysteresis / 2);
    final crossedToAvg =
        wasShowingPins && _liveZoom <= (_pinZoomThreshold - _hysteresis / 2);

    if (crossedToPins || crossedToAvg) {
      _renderZoom = _liveZoom;
      setState(() {});
    }
  }

  // ___________________________________________________________________________
  // ###########################################################################
  // #5 PINNING ________________________________________________________________
  Set<Marker> _buildParkingMarkers(List<Pin> pins) {
    return pins.where((p) => p.lat != null && p.lng != null).map((pin) {
      final pos = LatLng(pin.lat!, pin.lng!);
      final markerId = 'pin_${(pin.id ?? '${pin.lat}_${pin.lng}').toString()}';
      return Marker(
        markerId: MarkerId(markerId),
        position: pos,
        onTap: () => _showParkingInfo(context, pin),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
    }).toSet();
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

  // ___________________________________________________________________________
  // ###########################################################################
  // #6 INFO PANEL HANDLER _____________________________________________________
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

  // ___________________________________________________________________________
  // ###########################################################################
  // #7 SEARCHING OPERATION ____________________________________________________
  Set<Marker> _mergeWithSearch(Set<Marker> base) {
    final all = Set<Marker>.from(base);
    if (_searchMarker != null) all.add(_searchMarker!);
    if (_pickerMarker != null) all.add(_pickerMarker!);

    if (_isPickingLocation) {
      return _pickerMarker != null ? {_pickerMarker!} : {};
    }
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

  void _handleSearchCleared() {
    setState(() => _searchMarker = null);
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  // ___________________________________________________________________________
  // ###########################################################################
  // #8 APP INITIATOR & DISPOSER _______________________________________________
  @override
  void initState() {
    super.initState();
    _generateIcons();
    _loadAreasFromApi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ___________________________________________________________________________
  // ###########################################################################
  // #9 CUSTOMIZED WIDGET ITEMS ________________________________________________
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

            Set<Marker> baseMarkers;

            if (_filterActive) {
              baseMarkers = _filteredRawMarkers;
            } else {
              final bool showRealPins = _renderZoom >= _pinZoomThreshold;

              if (showRealPins) {
                baseMarkers = _buildParkingMarkers(pins);
              } else {
                if (_areas.isNotEmpty) {
                  final grouped = _groupPinsByArea(pins);
                  final markers = <Marker>{};
                  grouped.forEach((area, ps) {
                    if (ps.isEmpty) return;
                    markers.add(_buildAreaMarker(area, ps.length));
                  });
                  baseMarkers = markers.isNotEmpty
                      ? markers
                      : {_buildAverageMarker(pins)};
                } else {
                  baseMarkers = {_buildAverageMarker(pins)};
                }
              }
            }

            _markers = _mergeWithSearch(baseMarkers);

            return Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  onTap: _handleMapTap,
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
            // onPressed: () => context.read<PinCubit>().loadPins(),
            onPressed: _clearFilterAndReload,
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
          FloatingActionButton.extended(
            heroTag: 'filterFab',
            onPressed: () => _openFilterSheet(),
            icon: const Icon(Icons.filter_list),
            label: const Text('Filter'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ___________________________________________________________________________
  // ###########################################################################
}
