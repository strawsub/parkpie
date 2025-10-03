part of 'package:frontend/features/map/map_screen.dart';

mixin _MapScreenMapMixin on _MapScreenStateFields {
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
}
