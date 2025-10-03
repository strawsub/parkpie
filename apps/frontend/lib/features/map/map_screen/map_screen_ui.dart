// ignore_for_file: use_build_context_synchronously
part of 'package:frontend/features/map/map_screen.dart';

class _MapScreenView extends StatefulWidget {
  const _MapScreenView();

  @override
  State<_MapScreenView> createState() => _MapScreenViewState();
}

class _MapScreenViewState extends State<_MapScreenView> {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _googleMapController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pinState = context.read<PinCubit>().state;
      if (pinState is PinLoaded) {
        context.read<MapScreenCubit>().onPinsUpdated(pinState.pins);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<FilterTriggerCubit, int>(
            listener: (context, _) => _openFilterSheet(context),
          ),
          BlocListener<SearchCubit, SearchState>(listener: _handleSearchState),
          BlocListener<PinCubit, PinState>(listener: _handlePinState),
          BlocListener<MapScreenCubit, MapScreenState>(
            listenWhen: (previous, current) => current.commands.isNotEmpty,
            listener: _handleMapCommands,
          ),
        ],
        child: BlocBuilder<PinCubit, PinState>(
          builder: (context, pinState) {
            if (pinState is PinLoading || pinState is PinInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (pinState is PinError) {
              return _buildErrorCard(pinState);
            }

            return BlocBuilder<MapScreenCubit, MapScreenState>(
              buildWhen: (previous, current) =>
                  previous.markers != current.markers ||
                  previous.areaPolygons != current.areaPolygons ||
                  previous.filterActive != current.filterActive ||
                  previous.searchMarker != current.searchMarker ||
                  previous.pickerMarker != current.pickerMarker,
              builder: (context, mapState) {
                return Stack(
                  children: [
                    _buildGoogleMap(context, mapState),
                    _buildSearchBar(context, mapState),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: _buildFloatingButtons(context),
    );
  }

  void _handlePinState(BuildContext context, PinState state) {
    if (state is PinLoaded) {
      context.read<MapScreenCubit>().onPinsUpdated(state.pins);
    }
  }

  Future<void> _handleSearchState(
    BuildContext context,
    SearchState state,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final mapCubit = context.read<MapScreenCubit>();

    if (state is SearchLoading) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Searching...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (state is SearchSuccess) {
      _searchController.clear();
      FocusScope.of(context).unfocus();

      await mapCubit.handleSearchSuccess(state);

      messenger.showSnackBar(SnackBar(content: Text('Found: ${state.query}')));
      return;
    }

    if (state is SearchError) {
      messenger.showSnackBar(SnackBar(content: Text(state.message)));
      return;
    }

    if (state is SearchCleared) {
      _searchController.clear();
      FocusScope.of(context).unfocus();
      mapCubit.handleSearchCleared();
    }
  }

  Future<void> _handleMapCommands(
    BuildContext context,
    MapScreenState state,
  ) async {
    final mapCubit = context.read<MapScreenCubit>();

    for (final command in state.commands) {
      if (command is MapScreenSnackBarCommand) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(command.message),
            duration: command.duration ?? const Duration(seconds: 4),
          ),
        );
      } else if (command is MapScreenAnimateCameraCommand) {
        final controller = _googleMapController;
        if (controller == null) {
          continue;
        }

        final zoom = command.zoom ?? state.liveZoom;
        final update = CameraUpdate.newCameraPosition(
          CameraPosition(target: command.target, zoom: zoom),
        );
        if (command.animate) {
          await controller.animateCamera(update);
          mapCubit.onCameraAnimationComplete();
        } else {
          await controller.moveCamera(update);
        }
      } else if (command is MapScreenShowParkingInfoCommand) {
        await _showParkingInfo(context, command.pin, command.location);
      } else if (command is MapScreenDismissFilterSheetCommand) {
        if (mapCubit.state.isFilterOpen && Navigator.of(context).canPop()) {
          Navigator.of(context).maybePop();
        }
      }
    }

    mapCubit.clearCommands();
  }

  Widget _buildGoogleMap(BuildContext context, MapScreenState mapState) {
    final cubit = context.read<MapScreenCubit>();

    return GoogleMap(
      onMapCreated: (controller) {
        _googleMapController = controller;
        cubit.onMapCreated(controller);
      },
      onCameraMove: cubit.onCameraMove,
      onCameraIdle: cubit.onCameraIdle,
      onTap: cubit.handleMapTap,
      initialCameraPosition: CameraPosition(
        target: mapState.initialPosition,
        zoom: 13.5,
      ),
      markers: mapState.markers,
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      compassEnabled: true,
      mapToolbarEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(2.0, 20.0),
      polygons: mapState.areaPolygons,
      padding: EdgeInsets.only(
        bottom: 86 + MediaQuery.of(context).padding.bottom,
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, MapScreenState mapState) {
    final mapCubit = context.read<MapScreenCubit>();

    return Positioned(
      top: 60,
      left: 16,
      right: 16,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Image.asset('assets/icon.png', width: 28, height: 28),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search location...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (query) {
                    if (query.isNotEmpty) {
                      context.read<SearchCubit>().searchLocation(query);
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: mapState.filterActive ? Colors.blue : null,
                ),
                tooltip: 'Filter parking spots',
                onPressed: () => _openFilterSheet(context),
              ),
              if (mapState.filterActive || mapState.searchMarker != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear filter and search',
                  onPressed: () {
                    context.read<SearchCubit>().clearSearch();
                    mapCubit.clearFilter();
                    context.read<PinCubit>().loadPins();
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    context.read<SearchCubit>().clearSearch();
                  },
                ),
            ],
          ),
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
            onPressed: () {
              final mapCubit = context.read<MapScreenCubit>();
              mapCubit.clearFilter();
              context.read<SearchCubit>().clearSearch();
              context.read<PinCubit>().loadPins();
            },
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

  Future<void> _openFilterSheet(
    BuildContext context, {
    FilterConfig? seed,
  }) async {
    final mapCubit = context.read<MapScreenCubit>();
    if (mapCubit.state.isFilterOpen) {
      return;
    }

    mapCubit.notifyFilterSheetOpened();
    try {
      final initial =
          seed ??
          mapCubit.state.lastFilterConfig ??
          mapCubit.defaultFilterConfig();
      final result = await showFilterSheet(context, initial: initial);
      if (!mounted) return;

      if (result == null) {
        return;
      }

      if (result == kFilterRequestPickOnMap) {
        final picked = await mapCubit.startPickOnMap();
        if (!mounted) {
          return;
        }
        if (picked == null) {
          return;
        }
        final base =
            mapCubit.state.lastFilterConfig ?? mapCubit.defaultFilterConfig();
        await _openFilterSheet(
          context,
          seed: base.copyWith(
            mode: LocationMode.selected,
            selectedPoint: picked,
          ),
        );
        return;
      }

      if (result is FilterConfig) {
        await mapCubit.applyFilterWithSearch(result);
      }
    } finally {
      if (mounted) {
        mapCubit.notifyFilterSheetClosed();
      }
    }
  }

  Future<void> _showParkingInfo(
    BuildContext context,
    Pin pin,
    LatLng location,
  ) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ParkingInfoSheet(
        location: location,
        id: pin.id,
        occupancyPercent: pin.occupancyPercent,
        startTime: pin.startTime,
        endTime: pin.endTime,
        maximumStayMinutes: pin.maximumStayMinutes,
        description: pin.description,
      ),
    );
  }
}
