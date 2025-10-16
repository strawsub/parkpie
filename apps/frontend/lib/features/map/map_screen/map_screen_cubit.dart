part of 'package:frontend/features/map/map_screen.dart';

class MapScreenCubit extends Cubit<MapScreenState> {
  MapScreenCubit() : super(MapScreenState.initial());

  final SegmentService _segmentService = SegmentService();

  bool showSegments = true;
  final Map<int, BitmapDescriptor> _clusterIconCache = {};
  Completer<LatLng?>? _pickCompleter;
  List<Pin> _latestPins = const [];

  Future<void> initialize() async {
    _preloadClusterIcons();
    _loadAreasFromApi();
    await _segmentService.loadSegments('assets/road_segment.geojson');
    await _segmentService.loadCountsFromApi();
    _rebuildMarkers();
  }

  void toggleSegments() {
    showSegments = !showSegments;
    _rebuildMarkers();
  }

  void _rebuildMarkers() {
    final base = _prepareMarkers(_latestPins);
    final merged = _mergeWithSearch(base);

    emit(state.copyWith(
      markers: merged,
      segmentPolygons: (showSegments && state.renderZoom >= state.pinZoomThreshold)
          ? _segmentService.buildPolygons()
          : {},
    ));
  }



  void clearCommands() {
    if (state.commands.isEmpty) return;
    emit(state.copyWith(commands: const []));
  }

  Future<void> onMapCreated(GoogleMapController controller) async {
    final zoom = await controller.getZoomLevel();
    if (!isClosed) {
      _emitState(state.copyWith(liveZoom: zoom, renderZoom: zoom));
    }
  }

  void onCameraMove(CameraPosition position) {
    if ((position.zoom - state.liveZoom).abs() < 0.001) {
      return;
    }
    _emitState(state.copyWith(liveZoom: position.zoom));
  }

  void onCameraIdle() {
    if (state.isAnimating) {
      return;
    }

    final wasShowingPins = state.renderZoom >= state.pinZoomThreshold;
    final crossedToPins =
        !wasShowingPins &&
        state.liveZoom >= (state.pinZoomThreshold + state.hysteresis / 2);
    final crossedToAverage =
        wasShowingPins &&
        state.liveZoom <= (state.pinZoomThreshold - state.hysteresis / 2);

    if (crossedToPins || crossedToAverage) {
      _emitState(state.copyWith(renderZoom: state.liveZoom));
      _rebuildMarkers();
    }
  }

  Future<void> onPinsUpdated(List<Pin> pins) async {
    _latestPins = pins;
    _rebuildMarkers();

    if (pins.isEmpty || state.hasCenteredInitially) {
      return;
    }

    final center = _computeCentroid(pins);
    final nextState = state.copyWith(hasCenteredInitially: true);
    _emitState(
      nextState,
      commands: [
        MapScreenAnimateCameraCommand(
          target: center,
          zoom: nextState.liveZoom,
          animate: false,
        ),
      ],
    );
  }

  void onCameraAnimationComplete() {
    if (!state.isAnimating) return;
    _emitState(state.copyWith(isAnimating: false));
  }

  void notifyFilterSheetOpened() {
    if (state.isFilterOpen) return;
    _emitState(state.copyWith(isFilterOpen: true));
  }

  void notifyFilterSheetClosed() {
    if (!state.isFilterOpen) return;
    _emitState(state.copyWith(isFilterOpen: false));
  }


  void _animateCamera(LatLng target, {double? zoom, bool animate = true}) {
    final nextState = state.copyWith(
      isAnimating: animate ? true : state.isAnimating,
    );
    _emitState(
      nextState,
      commands: [
        MapScreenAnimateCameraCommand(
          target: target,
          zoom: zoom,
          animate: animate,
        ),
      ],
    );
  }

  void _handleParkingMarkerTap(Pin pin, LatLng location) {
    _emitState(
      state,
      commands: [MapScreenShowParkingInfoCommand(pin: pin, location: location)],
    );
  }

  void _handleDismissFilterSheetRequest() {
    if (!state.isFilterOpen) return;
    _emitState(state, commands: const [MapScreenDismissFilterSheetCommand()]);
  }

  void _emitState(
    MapScreenState newState, {
    List<MapScreenCommand> commands = const [],
  }) {
    emit(newState.copyWith(commands: commands));
  }

  void storeFilter(FilterConfig config) {
    emit(state.copyWith(
      lastFilterConfig: config,
      filterActive: true,
    ));
  }
}
