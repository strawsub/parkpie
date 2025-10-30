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

  // Debug settings visibility toggle - set to false in production !!!
  static const bool _showDebugSettings = true;

  // Triple-click detection for debug menu
  int _iconClickCount = 0;
  DateTime? _lastIconClickTime;

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

  void _handleIconClick() {
    final now = DateTime.now();
    
    // Reset counter if more than 1 second has passed since last click
    if (_lastIconClickTime == null || 
        now.difference(_lastIconClickTime!) > const Duration(seconds: 1)) {
      _iconClickCount = 1;
    } else {
      _iconClickCount++;
    }
    
    _lastIconClickTime = now;
    
    // Show debug menu on triple click
    if (_iconClickCount == 3 && _showDebugSettings) {
      _showDebugMenu(context);
      _iconClickCount = 0; // Reset counter
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                  previous.segmentPolygons != current.segmentPolygons ||
                  previous.areaPolygons != current.areaPolygons ||
                  previous.filterActive != current.filterActive ||
                  previous.searchMarker != current.searchMarker ||
                  previous.pickerMarker != current.pickerMarker,
              builder: (context, mapState) {
                return Stack(
                  children: [
                    _buildGoogleMap(context, mapState),
                    _buildSearchBar(context, mapState),
                    _buildTimerBadge(context),
                    _buildSettingsButton(context),
                  ],
                );
              },
            );
          },
        ),
      ),
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

    if (state is SearchSuccess) {
      _searchController.text = state.query;
      FocusScope.of(context).unfocus();

      await mapCubit.handleSearchSuccess(state);

      return;
    }

    if (state is SearchError) {
      final userMessage = state.message.isNotEmpty
          ? state.message
          : 'Could not find the location. Please try again.'; // fallback
      messenger.showSnackBar(
        SnackBar(
          content: Text(userMessage),
        ),
      );
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
      if (command is MapScreenAnimateCameraCommand) {
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
      polygons: {
        ...mapState.areaPolygons,
        if (cubit.showSegments) ...mapState.segmentPolygons,
      },
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(
          context,
        ).padding.bottom, // Position GPS button above tab bar
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  onTap: _handleIconClick,
                  child: Image.asset('assets/icon.png', width: 28, height: 28),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search location...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                    filled: false, // No background fill
                    fillColor: Colors.transparent, // Transparent background
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
                  color: mapState.filterActive ? AppColors.primary : null,
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

  Future<void> _showDebugMenu(BuildContext context) async {
    // Capture BLoC references before showing bottom sheet
    final mapCubit = context.read<MapScreenCubit>();
    final searchCubit = context.read<SearchCubit>();
    final pinCubit = context.read<PinCubit>();
    final parkingBloc = context.read<ParkingBloc>();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Debug Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),

            // Debug options
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.refresh, color: AppColors.primary),
              ),
              title: const Text('Reload Pins'),
              subtitle: const Text('Refresh all parking data'),
              onTap: () {
                Navigator.pop(sheetContext);
                mapCubit.clearFilter();
                searchCubit.clearSearch();
                pinCubit.loadPins(forceRefresh: true);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_parking, color: Colors.orange.shade700),
              ),
              title: const Text('Test Parking Detection'),
              subtitle: const Text('Trigger parking detection popup'),
              onTap: () {
                Navigator.pop(sheetContext);
                parkingBloc.add(const TriggerTestParkingDetection());
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bug_report, color: Colors.purple.shade700),
              ),
              title: const Text('Debug Screen'),
              subtitle: const Text('Open debug information screen'),
              onTap: () {
                Navigator.pop(sheetContext);
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
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.remove_red_eye, color: Colors.blue.shade700),
              ),
              title: const Text('Toggle Areas Debug'),
              subtitle: const Text('Show/hide area polygons on map'),
              onTap: () {
                Navigator.pop(sheetContext);
                mapCubit.toggleAreasDebug();
              },
            ),
            SizedBox(height: MediaQuery.of(sheetContext).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showSettingsMenu(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                sheetContext.l10n.getString('settings.title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),

            // Production Settings only
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.language, color: AppColors.primary),
              ),
              title: Text(sheetContext.l10n.getString('language.settingsTitle')),
              subtitle: Text(sheetContext.l10n.getString('language.settingsSubtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LanguageSelectionPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
              ),
              title: Text(sheetContext.l10n.getString('privacy.settingsTitle')),
              subtitle: Text(sheetContext.l10n.getString('privacy.settingsSubtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyDisclosurePage(),
                  ),
                );
              },
            ),
            SizedBox(height: MediaQuery.of(sheetContext).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    return Positioned(
      top: 120, // Below search bar and timer badge
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showSettingsMenu(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.settings,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ),
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
        mapCubit.storeFilter(result);
        mapCubit.applyFilterWithSearch(result);
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
      builder: (context) => ParkingInfoSheet(pin: pin),
    );
  }

  Widget _buildTimerBadge(BuildContext context) {
    return BlocBuilder<TimerBloc, timer.TimerState>(
      builder: (context, timerState) {
        if (timerState is! timer.TimerRunning) {
          return const SizedBox.shrink();
        }

        // Get restriction duration and calculate remaining
        final restrictionDuration = Duration(
          minutes: timerState.restrictionDurationMinutes,
        );
        final elapsed = timerState.elapsed;
        final remaining = restrictionDuration - elapsed;

        final isOvertime = remaining.isNegative;
        final displayRemaining = isOvertime ? -remaining : remaining;

        final hours = displayRemaining.inHours;
        final minutes = displayRemaining.inMinutes.remainder(60);
        final seconds = displayRemaining.inSeconds.remainder(60);

        final remainingString = hours > 0
            ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
            : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        return Positioned(
          top: 120,
          left: 20,
          child: GestureDetector(
            onTap: () {
              context.read<NavigationCubit>().setIndex(2);
            },
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: lottie.Lottie.asset(
                        'assets/car-animate.json',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      remainingString,
                      style: TextStyle(
                        fontSize: 20, // bigger font
                        fontWeight: FontWeight.bold,
                        color: isOvertime
                            ? Colors.red
                            : AppColors.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}