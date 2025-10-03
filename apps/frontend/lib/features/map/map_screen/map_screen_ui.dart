part of 'package:frontend/features/map/map_screen.dart';

mixin _MapScreenUiMixin
    on
        _MapScreenAreaMixin,
        _MapScreenFilterMixin,
        _MapScreenMapMixin,
        _MapScreenSearchMixin {
  Widget buildMapScreen(BuildContext context) {
    return Scaffold(
      body: MultiBlocListener(
        listeners: [_filterTriggerListener(), _searchListener()],
        child: BlocBuilder<PinCubit, PinState>(
          builder: (context, state) => _buildMapContent(context, state),
        ),
      ),
      floatingActionButton: _buildFloatingButtons(context),
    );
  }

  BlocListener<FilterTriggerCubit, int> _filterTriggerListener() {
    return BlocListener<FilterTriggerCubit, int>(
      listener: (context, state) {
        _openFilterSheet();
      },
    );
  }

  BlocListener<SearchCubit, SearchState> _searchListener() {
    return BlocListener<SearchCubit, SearchState>(
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Found: ${state.query}')));
        } else if (state is SearchError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is SearchCleared) {
          _handleSearchCleared();
        }
      },
    );
  }

  Widget _buildMapContent(BuildContext context, PinState state) {
    if (state is PinLoading || state is PinInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is PinError) {
      return _buildErrorCard(state);
    }

    final pins = (state as PinLoaded).pins;
    _centerOnFirstLoad(pins);

    final baseMarkers = _prepareMarkers(pins);
    _markers = _mergeWithSearch(baseMarkers);

    return Stack(
      children: [_buildGoogleMap(context), _buildSearchBar(context)],
    );
  }

  Widget _buildErrorCard(PinError state) {
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

  void _centerOnFirstLoad(List<Pin> pins) {
    if (_hasCenteredInitially || pins.isEmpty || _mapController == null) {
      return;
    }

    final center = _computeCentroid(pins);
    _hasCenteredInitially = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: center, zoom: _liveZoom),
        ),
      );
    });
  }

  Set<Marker> _prepareMarkers(List<Pin> pins) {
    if (_filterActive) {
      return _filteredRawMarkers;
    }

    final bool showRealPins = _renderZoom >= _pinZoomThreshold;

    if (showRealPins) {
      return _buildParkingMarkers(pins);
    }

    if (!_iconsLoaded) {
      // Show loading or simplified markers while icons are being generated
      return {};
    }

    if (_areas.isNotEmpty) {
      final grouped = _groupPinsByArea(pins);
      final markers = <Marker>{};
      for (final entry in grouped.entries) {
        final area = entry.key;
        final ps = entry.value;
        if (ps.isEmpty) continue;
        final marker = _buildAreaMarker(area, ps.length);
        markers.add(marker);
      }
      if (markers.isNotEmpty) {
        return markers;
      }
    }

    return {_buildAverageMarker(pins)};
  }

  Widget _buildGoogleMap(BuildContext context) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle,
      onTap: _handleMapTap,
      initialCameraPosition: CameraPosition(
        target: _initialPosition,
        zoom: 13.5,
      ),
      markers: _markers,
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      compassEnabled: true,
      mapToolbarEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(2.0, 20.0),
      polygons: _areaPolygons,
      padding: EdgeInsets.only(
        bottom: 86 + MediaQuery.of(context).padding.bottom,
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Positioned(
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (query) =>
                    context.read<SearchCubit>().searchLocation(query),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => context.read<SearchCubit>().searchLocation(
                _searchController.text,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => context.read<SearchCubit>().clearSearch(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButtons(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 86 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'reloadFab',
            onPressed: _clearFilterAndReload,
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
        ],
      ),
    );
  }
}
