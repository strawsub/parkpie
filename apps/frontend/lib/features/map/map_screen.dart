import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/parking_info/parking_info_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';

import '../parking_detector/sensors_provider.dart';
import '../parking_detector/parking_detector_state.dart';
// 可选：开发期叠加一个底部调试面板
import '../parking_detector/parking_debug_panel.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  // 位置与地图事件订阅
  StreamSubscription<Position>? _posListen;
  StreamSubscription<MapEvent>? _mapEvtSub;

  // 自己维护当前缩放，避免直接访问 controller.zoom
  double _zoom = 10.0; // 初始缩放

  @override
  void initState() {
    super.initState();

    // 1) 跟踪地图事件，实时更新 _zoom
    _mapEvtSub = _mapController.mapEventStream.listen((evt) {
      // flutter_map v4+ / v6: 事件里有 camera
      setState(() {
        _zoom = evt.camera.zoom;
      });
    });

    // 2) 订阅位置流，移动地图中心，缩放用 _zoom
    final sensorsService = ref.read(sensorsServiceProvider);
    _posListen = sensorsService.position$.listen((pos) {
      _mapController.move(
        LatLng(pos.latitude, pos.longitude),
        _zoom,
      );
    });
  }

  @override
  void dispose() {
    _posListen?.cancel();
    _mapEvtSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 读取 cubit 与其 state
    final detector = ref.watch(parkingDetectorProvider);
    final st = detector.state; // ParkingDetectorState
    final statusText = _getStatusText(st);

    // “我的位置”标记
    final currentPosition = st.lastPosition;
    final currentMarker = currentPosition != null
        ? Marker(
      point: LatLng(currentPosition.latitude, currentPosition.longitude),
      width: 40,
      height: 40,
      child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
    )
        : null;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            // 用本地 _zoom，所以不能用 const
            options: MapOptions(
              initialCenter: const LatLng(-37.8035820, 144.9593280),
              initialZoom: _zoom,
              minZoom: 3,
              maxZoom: 20,
            ),
            children: [
              _mapTileLayer,
              _mapMarkerLayer(context, currentMarker),
            ],
          ),

          // 顶部状态卡片
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  statusText,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // （可选）开发期调试面板
          const ParkingDebugPanel(),
        ],
      ),
    );
  }

  TileLayer get _mapTileLayer => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.parkpie.frontend',
  );

  MarkerLayer _mapMarkerLayer(BuildContext context, Marker? currentMarker) {
    final markers = [
      if (currentMarker != null) currentMarker,
      Marker(
        point: const LatLng(-37.8035820, 144.9593280),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const ParkingInfoSheet(
                location: LatLng(-37.8035820, 144.9593280),
              ),
            );
          },
          child: SvgPicture.asset(
            'assets/park_sign.svg',
            width: 40,
            height: 40,
          ),
        ),
      ),
    ];
    return MarkerLayer(markers: markers);
  }

  // 让它接收完整 state，避免函数里再取 Provider
  String _getStatusText(ParkingDetectorState st) {
    switch (st.state) {
      case ParkingState.driving:
        return '您正在行驶中...';
      case ParkingState.parking:
        return '正在检测泊车中...';
      case ParkingState.parked:
        final lastPos = st.lastPosition;
        if (lastPos != null) {
          return '已泊车！位置：${lastPos.latitude.toStringAsFixed(4)}, ${lastPos.longitude.toStringAsFixed(4)}';
        }
        return '已泊车！';
    }
  }
}
