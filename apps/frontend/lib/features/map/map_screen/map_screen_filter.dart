part of 'package:frontend/features/map/map_screen.dart';

mixin _MapScreenFilterMixin on _MapScreenAreaMixin {
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
            'Zone ${m['zone_number']}  ${m['distance']?.toStringAsFixed(1)}m away',
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
}
