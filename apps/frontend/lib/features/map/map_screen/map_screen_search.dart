part of 'package:frontend/features/map/map_screen.dart';

mixin _MapScreenSearchMixin on _MapScreenStateFields {
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
}
