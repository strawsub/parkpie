import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/features/debug/debug_screen.dart';
import 'package:frontend/features/map/filter/filter_config.dart';
import 'package:frontend/features/map/filter/filter_panel.dart';
import 'package:frontend/features/map/parking_info/parking_info_screen.dart';
import 'package:frontend/features/map/pin/pin_cubit.dart';
import 'package:frontend/features/map/pin/pin_model.dart';
import 'package:frontend/features/map/pin/pin_state.dart';
import 'package:frontend/features/map/search/search_cubit.dart';
import 'package:frontend/features/map/search/search_state.dart';
import 'package:frontend/features/navigation/filter_trigger_cubit.dart';
import 'package:frontend/features/navigation/navigation_cubit.dart';
import 'package:frontend/features/parking_status_detection/parking_status_bloc.dart';
import 'package:frontend/features/parking_status_detection/parking_status_event.dart';
import 'package:frontend/features/timer/timer_bloc.dart';
import 'package:frontend/features/timer/timer_state.dart' as timer;
import 'package:frontend/services/segment_service.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:lottie/lottie.dart' as lottie;

part 'map_screen/map_screen_state_fields.dart';
part 'map_screen/map_screen_area.dart';
part 'map_screen/map_screen_filter.dart';
part 'map_screen/map_screen_cubit.dart';
part 'map_screen/map_screen_search.dart';
part 'map_screen/map_screen_ui.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MapScreenCubit()..initialize(),
      child: const _MapScreenView(),
    );
  }
}

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
