/*  
 *   ############################################################################################
 *   ######################################### INDICES ##########################################
 *   ____________________________________________________________________________________________
 *  |      |                            |                                                        |
 *  | #NO  |   Name                     |   Description                                          |
 *  |------|----------------------------|--------------------------------------------------------|
 *  | #1   |   SEGMENT DEBUGGER         |   Just In case for show segments                       |
 *  | #2   |   SEGMENT GENERATION       |   Generate segments from API and create average pins   |
 *  | #3   |   FILTER HANDLER           |   Open filter panel, apply filter, pick on map         |
 *  | #4   |   MAP OPERATIONS           |   Map creation, camera movement, zoom handling         |
 *  | #5   |   PINNING                  |   Create markers from pin data, custom icons           |
 *  | #6   |   INFO PANEL HANDLER       |   Show parking info bottom sheet                       |
 *  | #7   |   SEARCHING OPERATION      |   Search location, handle search states                |
 *  | #8   |   APP INITIATOR & DISPOSER |   Init and dispose resources                           |
 *  | #9   |   CUSTOMIZED WIDGET ITEMS  |   Customized widgets in build()                        |
 *  |______|____________________________|________________________________________________________|
 * 
 */

import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
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
import 'package:frontend/features/map/filter/filter_config.dart';
import 'package:frontend/features/map/filter/filter_panel.dart';
import 'package:frontend/features/navigation/filter_trigger_cubit.dart';

part 'map_screen/map_screen_state_fields.dart';
part 'map_screen/map_screen_area.dart';
part 'map_screen/map_screen_filter.dart';
part 'map_screen/map_screen_map.dart';
part 'map_screen/map_screen_search.dart';
part 'map_screen/map_screen_ui.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// -------- Area clustering config --------

class AreaRect {
  final String id;
  final String label;
  final LatLngBounds bounds;
  final LatLng center;

  const AreaRect({
    required this.id,
    required this.label,
    required this.bounds,
    required this.center,
  });
}
// -----------------------------------------

class _MapScreenState extends State<MapScreen>
    with
        _MapScreenStateFields,
        _MapScreenAreaMixin,
        _MapScreenFilterMixin,
        _MapScreenMapMixin,
        _MapScreenSearchMixin,
        _MapScreenUiMixin {
  @override
  void initState() {
    super.initState();
    _preloadClusterIcons();
    _loadAreasFromApi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildMapScreen(context);
  }
}
