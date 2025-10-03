part of 'package:frontend/features/map/map_screen.dart';

extension MapScreenSearchLogic on MapScreenCubit {
  Future<void> handleSearchSuccess(SearchSuccess result) async {
    _animateCamera(result.location, zoom: 15);

    final searchMarker = Marker(
      markerId: MarkerId(result.markerId),
      position: result.location,
      infoWindow: InfoWindow(title: 'Search Result', snippet: result.query),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    final updatedState = state.copyWith(
      searchMarker: searchMarker,
      selectedPoint: result.location,
    );
    _emitState(updatedState);
    _rebuildMarkers();

    final filterConfig =
        state.lastFilterConfig?.copyWith(
          mode: LocationMode.selected,
          selectedPoint: result.location,
        ) ??
        FilterConfig(
          mode: LocationMode.selected,
          selectedPoint: result.location,
          radiusMeters: 500,
          durationMinutes: 60,
          startTime: TimeOfDay.now(),
          date: DateTime.now(),
        );

    await applyFilterWithSearch(filterConfig);
  }

  void handleSearchCleared() {
    final cleared = state.copyWith(
      clearSearchMarker: true,
      clearSelectedPoint: true,
    );
    _emitState(cleared);
    _rebuildMarkers();
  }
}
