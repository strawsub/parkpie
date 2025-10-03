part of 'package:frontend/features/map/map_screen.dart';

mixin _MapScreenSearchMixin on _MapScreenFilterMixin {

  // Modified to automatically apply filter after search
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
      _selectedPoint = state.location;
    });

    _searchController.clear();
    FocusScope.of(context).unfocus();

    // Automatically apply filter with the search location
    final filterConfig = _lastFilterConfig?.copyWith(
      mode: LocationMode.selected,
      selectedPoint: state.location,
    ) ?? FilterConfig(
      mode: LocationMode.selected,
      selectedPoint: state.location,
      radiusMeters: 500, 
      durationMinutes: 60,
      startTime: TimeOfDay.now(),
    );

    await _applyFilterWithSearch(filterConfig);
  }

  void _handleSearchCleared() {
    setState(() {
      _searchMarker = null;
      _selectedPoint = null;
    });
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }
}