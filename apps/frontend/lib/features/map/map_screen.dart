import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:frontend/features/map/parking_info/parking_info_screen.dart';
import 'package:frontend/features/map/pin/pin_cubit.dart';
import 'package:frontend/features/map/pin/pin_state.dart';
import 'package:frontend/features/map/pin/pin_model.dart';
import 'package:frontend/features/map/search/search_cubit.dart';
import 'package:frontend/features/map/search/search_state.dart';
import 'package:frontend/features/parking_status_detection/parking_status_bloc.dart';
import 'package:frontend/features/debug/debug_screen.dart';
import 'package:frontend/features/raster_map/raster_map_screen.dart'; // 新增

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();
  Marker? _searchMarker;

  static const LatLng _initialPosition = LatLng(-37.8035820, 144.9593280);

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _showParkingInfo(BuildContext context, Pin pin) {
    final pos = LatLng(pin.lat!, pin.lng!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ParkingInfoSheet(
        location: pos,
        occupancyPercent: pin.occupancyPercent,
        startTime: pin.startTime,
        endTime: pin.endTime,
        maximumStayMinutes: pin.maximumStayMinutes,
        description: pin.description,
      ),
    );
  }

  Set<Marker> _buildParkingMarkers(List<Pin> pins) {
    return pins.map((pin) {
      final pos = LatLng(pin.lat!, pin.lng!);
      return Marker(
        markerId: MarkerId('pin_${pin.lat}_${pin.lng}'),
        position: pos,
        onTap: () => _showParkingInfo(context, pin),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
    }).toSet();
  }

  Set<Marker> _getAllMarkers(Set<Marker> parkingMarkers) {
    final allMarkers = Set<Marker>.from(parkingMarkers);
    if (_searchMarker != null) {
      allMarkers.add(_searchMarker!);
    }
    return allMarkers;
  }

  void _handleSearchSuccess(SearchSuccess state) async {
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
        infoWindow: InfoWindow(
          title: 'Search Result',
          snippet: state.query,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    });

    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  void _handleSearchCleared() {
    setState(() {
      _searchMarker = null;
    });
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<SearchCubit, SearchState>(
            listener: (context, state) {
              if (state is SearchLoading) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Searching...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              } else if (state is SearchSuccess) {
                _handleSearchSuccess(state);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Found: ${state.query}')),
                );
              } else if (state is SearchError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
              } else if (state is SearchCleared) {
                _handleSearchCleared();
              }
            },
          ),
        ],
        child: BlocBuilder<PinCubit, PinState>(
          builder: (context, state) {
            if (state is PinLoading || state is PinInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is PinError) {
              return Center(
                child: Card(
                  color: Colors.red.shade700,
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Failed to load pins:\n${state.message}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            }

            final pins = (state as PinLoaded).pins;
            final parkingMarkers = _buildParkingMarkers(pins);
            _markers = _getAllMarkers(parkingMarkers);

            return Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: _initialPosition,
                    zoom: 12.0,
                  ),
                  markers: _markers,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  minMaxZoomPreference: const MinMaxZoomPreference(2.0, 20.0),
                ),
                // 🔍 Floating Search Bar
                Positioned(
                  top: 40,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(
                              hintText: 'Search location...',
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            onSubmitted: (query) =>
                                context.read<SearchCubit>().searchLocation(query),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => context
                              .read<SearchCubit>()
                              .searchLocation(_searchController.text),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => context.read<SearchCubit>().clearSearch(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // 🟢 Floating Action Button Column
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'reloadFab',
            onPressed: () => context.read<PinCubit>().loadPins(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reload'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'debugFab',
            mini: true,
            onPressed: () {
              final pinCubit = context.read<PinCubit>();
              final parkingBloc = context.read<ParkingBloc>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider.value(value: pinCubit),
                      BlocProvider.value(value: parkingBloc),
                    ],
                    child: const DebugScreen(),
                  ),
                ),
              );
            },
            tooltip: 'Debug',
            child: const Icon(Icons.bug_report),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'rasterFab',
            mini: true,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SegmentMapScreen(),
                ),
              );
            },
            tooltip: 'Raster Map',
            child: Image.asset(
              'assets/images/logo.png', // 替換成你專案 logo
              width: 28,
              height: 28,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
