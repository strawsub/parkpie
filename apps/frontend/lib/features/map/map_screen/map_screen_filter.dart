part of 'package:frontend/features/map/map_screen.dart';

mixin _MapScreenFilterMixin on _MapScreenAreaMixin {
  Set<Marker> _mergeWithSearch(Set<Marker> base) {
    final all = Set<Marker>.from(base);
    if (_searchMarker != null) all.add(_searchMarker!);
    if (_pickerMarker != null) all.add(_pickerMarker!);

    if (_isPickingLocation) {
      return _pickerMarker != null ? {_pickerMarker!} : {};
    }
    return all;
  }

  Future<void> _openFilterSheet({FilterConfig? seed}) async {
    _isFilterOpen = true;
    try {
      final result = await showFilterSheet(
        context,
        initial: seed ?? _getDefaultFilterConfig(),
      );

      if (!mounted) return;

      if (result == kFilterRequestPickOnMap) {
        final picked = await _startPickOnMap();
        if (!mounted || picked == null) return;

        final base = seed ?? _getDefaultFilterConfig();

        await _openFilterSheet(
          seed: base.copyWith(
            mode: LocationMode.selected,
            selectedPoint: picked,
          ),
        );
        return;
      }

      if (result is FilterConfig) {
        await _applyFilterWithSearch(result);
      }
    } finally {
      _isFilterOpen = false;
    }
  }

  FilterConfig _getDefaultFilterConfig() {
    return FilterConfig(
      mode: LocationMode.selected,
      selectedPoint: _selectedPoint,
      radiusMeters: 1000, // 1km default
      durationMinutes: 120, // 2 hours
      startTime: TimeOfDay.now(),
    );
  }

  // New unified method that handles both search location and filter
  Future<void> _applyFilterWithSearch(FilterConfig config) async {
    final messenger = ScaffoldMessenger.of(context);
    final mapCtrl = _mapController;
    
    setState(() {
      _markers = {};
      _lastFilterConfig = config; // Store for future use
    });

    try {
      final LatLng center;
      
      if (config.mode == LocationMode.selected) {
        center = config.selectedPoint!;
        _selectedPoint = center;
      } else {
        center = await _getCurrentLocation();
      }

      final pins = await _fetchPinsWithinRange(
        center: center,
        radius: config.radiusMeters,
        durationMinutes: config.durationMinutes,
        startTime: config.startTime,
      );
      
      debugPrint('[Filter] Received ${pins.length} pins from API');
      
      if (!mounted) return;

      final filteredMarkers = _buildParkingMarkers(pins);
      debugPrint('[Filter] Created ${filteredMarkers.length} markers');

      setState(() {
        _filterActive = true;
        _filteredRawMarkers = filteredMarkers;
        _markers = _mergeWithSearch(filteredMarkers);
      });

      await mapCtrl?.animateCamera(CameraUpdate.newLatLng(center));

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${pins.length} parking spots found '
            '${config.mode == LocationMode.current ? "near you" : "at selected location"}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('[Filter] Filter error: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to filter pins: ${e.toString()}')),
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
    String two(int n) => n.toString().padLeft(2, '0');
    final restrictionTime =
        '${two(startTime.hour)}:${two(startTime.minute)}:00';

    final uri = Uri.parse(
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
        'querybyradius failed: ${resp.statusCode} - ${resp.body}',
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
            'Zone ${m['zone_number']}  ${m['distance']?.toStringAsFixed(1)}m away',
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
      _searchMarker = null;
      _lastFilterConfig = null;
    });

    context.read<PinCubit>().loadPins();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Filter cleared. Reloaded all pins.')),
    );
  }
}