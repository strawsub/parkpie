part of 'package:frontend/features/map/map_screen.dart';

abstract class MapScreenCommand {
  const MapScreenCommand();
}

class MapScreenSnackBarCommand extends MapScreenCommand {
  final String message;
  final Duration? duration;

  const MapScreenSnackBarCommand(this.message, {this.duration});
}

class MapScreenAnimateCameraCommand extends MapScreenCommand {
  final LatLng target;
  final double? zoom;
  final bool animate;

  const MapScreenAnimateCameraCommand({
    required this.target,
    this.zoom,
    this.animate = true,
  });
}

class MapScreenShowParkingInfoCommand extends MapScreenCommand {
  final Pin pin;
  final LatLng location;

  const MapScreenShowParkingInfoCommand({
    required this.pin,
    required this.location,
  });
}

class MapScreenDismissFilterSheetCommand extends MapScreenCommand {
  const MapScreenDismissFilterSheetCommand();
}

class MapScreenState {
  final Set<Marker> markers;
  final Set<Polygon> segmentPolygons;
  final Set<Marker> filteredRawMarkers;
  final Set<Polygon> areaPolygons;
  final List<AreaRect> areas;
  final Marker? searchMarker;
  final Marker? pickerMarker;
  final LatLng? selectedPoint;
  final FilterConfig? lastFilterConfig;
  final bool hasCenteredInitially;
  final bool isPickingLocation;
  final bool filterActive;
  final bool isFilterOpen;
  final bool iconsLoaded;
  final bool isApplyingFilter;
  final bool isLoadingAreas;
  final bool isAnimating;
  final double renderZoom;
  final double liveZoom;
  final double pinZoomThreshold;
  final double hysteresis;
  final LatLng initialPosition;
  final bool showAreasDebug;
  final List<MapScreenCommand> commands;

  const MapScreenState({
    required this.markers,
    required this.segmentPolygons,
    required this.filteredRawMarkers,
    required this.areaPolygons,
    required this.areas,
    required this.searchMarker,
    required this.pickerMarker,
    required this.selectedPoint,
    required this.lastFilterConfig,
    required this.hasCenteredInitially,
    required this.isPickingLocation,
    required this.filterActive,
    required this.isFilterOpen,
    required this.iconsLoaded,
    required this.isApplyingFilter,
    required this.isLoadingAreas,
    required this.isAnimating,
    required this.renderZoom,
    required this.liveZoom,
    required this.pinZoomThreshold,
    required this.hysteresis,
    required this.initialPosition,
    required this.showAreasDebug,
    required this.commands,
  });

  factory MapScreenState.initial() => MapScreenState(
    markers: {},
    segmentPolygons: {},
    filteredRawMarkers: {},
    areaPolygons: {},
    areas: const [],
    searchMarker: null,
    pickerMarker: null,
    selectedPoint: null,
    lastFilterConfig: null,
    hasCenteredInitially: false,
    isPickingLocation: false,
    filterActive: false,
    isFilterOpen: false,
    iconsLoaded: false,
    isApplyingFilter: false,
    isLoadingAreas: false,
    isAnimating: false,
    renderZoom: 13.5,
    liveZoom: 13.5,
    pinZoomThreshold: 15,
    hysteresis: 0.5,
    initialPosition: const LatLng(-37.8035820, 144.9593280),
    showAreasDebug: false, // DEBUGGER!!!
    commands: const [],
  );

  MapScreenState copyWith({
    Set<Marker>? markers,
    Set<Marker>? filteredRawMarkers,
    Set<Polygon>? segmentPolygons,
    Set<Polygon>? areaPolygons,
    List<AreaRect>? areas,
    Marker? searchMarker,
    bool clearSearchMarker = false,
    Marker? pickerMarker,
    bool clearPickerMarker = false,
    LatLng? selectedPoint,
    bool clearSelectedPoint = false,
    FilterConfig? lastFilterConfig,
    bool clearLastFilterConfig = false,
    bool? hasCenteredInitially,
    bool? isPickingLocation,
    bool? filterActive,
    bool? isFilterOpen,
    bool? iconsLoaded,
    bool? isApplyingFilter,
    bool? isLoadingAreas,
    bool? isAnimating,
    double? renderZoom,
    double? liveZoom,
    List<MapScreenCommand>? commands,

    double? pinZoomThreshold,
    double? hysteresis,
    LatLng? initialPosition,
    bool? showAreasDebug,
  }) {
    return MapScreenState(
      markers: markers ?? this.markers,
      segmentPolygons: segmentPolygons ?? this.segmentPolygons,
      filteredRawMarkers: filteredRawMarkers ?? this.filteredRawMarkers,
      areaPolygons: areaPolygons ?? this.areaPolygons,
      areas: areas ?? this.areas,
      searchMarker: clearSearchMarker
          ? null
          : (searchMarker ?? this.searchMarker),
      pickerMarker: clearPickerMarker
          ? null
          : (pickerMarker ?? this.pickerMarker),
      selectedPoint: clearSelectedPoint
          ? null
          : (selectedPoint ?? this.selectedPoint),
      lastFilterConfig: clearLastFilterConfig
          ? null
          : (lastFilterConfig ?? this.lastFilterConfig),
      hasCenteredInitially: hasCenteredInitially ?? this.hasCenteredInitially,
      isPickingLocation: isPickingLocation ?? this.isPickingLocation,
      filterActive: filterActive ?? this.filterActive,
      isFilterOpen: isFilterOpen ?? this.isFilterOpen,
      iconsLoaded: iconsLoaded ?? this.iconsLoaded,
      isApplyingFilter: isApplyingFilter ?? this.isApplyingFilter,
      isLoadingAreas: isLoadingAreas ?? this.isLoadingAreas,
      isAnimating: isAnimating ?? this.isAnimating,
      renderZoom: renderZoom ?? this.renderZoom,
      liveZoom: liveZoom ?? this.liveZoom,

      pinZoomThreshold: pinZoomThreshold ?? this.pinZoomThreshold,
      hysteresis: hysteresis ?? this.hysteresis,
      initialPosition: initialPosition ?? this.initialPosition,
      showAreasDebug: showAreasDebug ?? this.showAreasDebug,

      commands: commands ?? this.commands,
    );
  }
}
