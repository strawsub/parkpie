part of 'package:frontend/features/map/map_screen.dart';

mixin _MapScreenStateFields on State<MapScreen> {
  GoogleMapController? _mapController;

  final Map<int, BitmapDescriptor> _clusterIconCache = {};
  final TextEditingController _searchController = TextEditingController();

  Set<Marker> _markers = {};
  Set<Marker> _filteredRawMarkers = {};
  Set<Polygon> _areaPolygons = {};
  List<AreaRect> _areas = [];

  Completer<LatLng?>? _pickCompleter;

  Marker? _searchMarker;
  Marker? _pickerMarker;

  LatLng? _selectedPoint;
  FilterConfig? _lastFilterConfig;

  bool _hasCenteredInitially = false;
  bool _isFilterOpen = false;
  bool _isPickingLocation = false;
  bool _filterActive = false;
  bool _isAnimating = false;
  bool _iconsLoaded = false;

  double _liveZoom = 13.5;
  double _renderZoom = 13.5;

  double get _pinZoomThreshold => 15;
  double get _hysteresis => 0.5;
  LatLng get _initialPosition => const LatLng(-37.8035820, 144.9593280);

  bool get _showAreasDebug => false;
}
