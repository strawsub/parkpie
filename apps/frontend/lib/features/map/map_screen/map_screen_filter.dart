part of 'package:frontend/features/map/map_screen.dart';

extension MapScreenFilterLogic on MapScreenCubit {
  Set<Marker> _mergeWithSearch(Set<Marker> base) {
    final merged = <Marker>{...base};
    if (state.searchMarker != null) {
      merged.add(state.searchMarker!);
    }
    if (state.pickerMarker != null) {
      merged.add(state.pickerMarker!);
    }

    if (state.isPickingLocation) {
      return state.pickerMarker != null ? {state.pickerMarker!} : {};
    }
    return merged;
  }

  FilterConfig defaultFilterConfig() {
    return FilterConfig(
      mode: LocationMode.selected,
      selectedPoint: state.selectedPoint,
      radiusMeters: 1000,
      durationMinutes: 120,
      startTime: TimeOfDay.now(),
      date: DateTime.now(),
    );
  }

  Future<void> applyFilterWithSearch(FilterConfig config) async {
    _emitState(state.copyWith(isApplyingFilter: true));

    try {
      final LatLng center;
      if (config.mode == LocationMode.selected) {
        if (config.selectedPoint == null) {
          throw StateError('Selected location is required for this filter');
        }
        center = config.selectedPoint!;
      } else {
        center = await _getCurrentLocation();
      }

      final filterDate = config.date ?? DateTime.now();
      final normalizedConfig = config.date == null
          ? config.copyWith(date: filterDate)
          : config;

      final pins = await _fetchPinsWithinRange(
        center: center,
        radius: normalizedConfig.radiusMeters,
        durationMinutes: normalizedConfig.durationMinutes,
        startTime: normalizedConfig.startTime,
        date: filterDate,
      );

      final filteredMarkers = _buildParkingMarkers(pins);
      final mergedMarkers = _mergeWithSearch(filteredMarkers);

      final nextState = state.copyWith(
        filterActive: true,
        filteredRawMarkers: filteredMarkers,
        markers: mergedMarkers,
        lastFilterConfig: normalizedConfig,
        selectedPoint: center,
        isApplyingFilter: false,
      );

      _emitState(
        nextState,
        commands: [
          MapScreenAnimateCameraCommand(
            target: center,
            zoom: nextState.liveZoom,
          ),
        ],
      );
    } catch (error) {
      debugPrint('[Filter] Filter error: $error');
      _emitState(
        state.copyWith(isApplyingFilter: false),
        commands: [
          MapScreenSnackBarCommand(
            'Failed to filter pins: ${error.toString()}',
          ),
        ],
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

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<List<Pin>> _fetchPinsWithinRange({
    required LatLng center,
    required double radius,
    required int durationMinutes,
    required TimeOfDay startTime,
    required DateTime date,
  }) async {
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
            'restrictionDate': _formatDate(date),
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

      pins.add(
        Pin(
          id: idStr,
          lat: pos.latitude,
          lng: pos.longitude,
          occupancyPercent: (m['occupancy_percent'] as num?)?.toDouble(),
          maximumStayMinutes: m['maximum_stay_minutes'] as int?,
          startTime: m['start_time'] as String?,
          endTime: m['end_time'] as String?,
          description:
              'Zone ${m['zone_number']}  ${m['distance']?.toStringAsFixed(1)}m away',
        ),
      );
    }

    return pins;
  }

  Future<LatLng?> startPickOnMap() {
    if (state.isPickingLocation && _pickCompleter != null) {
      return _pickCompleter!.future;
    }

    _pickCompleter = Completer<LatLng?>();
    _emitState(
      state.copyWith(isPickingLocation: true),
    );

    return _pickCompleter!.future;
  }

  void handleMapTap(LatLng position) {
    if (state.isPickingLocation) {
      _pickCompleter?.complete(position);
      _pickCompleter = null;

      final pickerMarker = Marker(
        markerId: const MarkerId('picker'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Selected point'),
      );

      final nextState = state.copyWith(
        isPickingLocation: false,
        pickerMarker: pickerMarker,
        selectedPoint: position,
      );

      _emitState(nextState);
      _rebuildMarkers();
      return;
    }

    _handleDismissFilterSheetRequest();
  }

  void clearFilter() {
    final cleared = state.copyWith(
      filterActive: false,
      filteredRawMarkers: {},
      clearPickerMarker: true,
      clearSearchMarker: true,
      clearSelectedPoint: true,
      clearLastFilterConfig: true,
      isPickingLocation: false,
    );

    _emitState(cleared);
    _rebuildMarkers();

    _emitState(
      state,
    );
  }
}
