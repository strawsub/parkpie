import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'sensors_provider.dart';
import 'sensors_service.dart';
import 'parking_detector_state.dart';
import 'parking_detector_cubit.dart';

class ParkingDebugPanel extends ConsumerStatefulWidget {
  const ParkingDebugPanel({super.key});

  @override
  ConsumerState<ParkingDebugPanel> createState() => _ParkingDebugPanelState();
}

class _ParkingDebugPanelState extends ConsumerState<ParkingDebugPanel> {
  StreamSubscription? _cubitSub;
  StreamSubscription? _accSub;
  StreamSubscription? _posSub;

  ParkingDetectorState _pdState = const ParkingDetectorState();
  double _accAvg = 0.0;
  double _speedKmh = 0.0;
  Position? _lastPos;

  @override
  void initState() {
    super.initState();

    // subscribe Cubit status
    final cubit = ref.read(parkingDetectorProvider);
    _pdState = cubit.state;
    _cubitSub = cubit.stream.listen((s) {
      setState(() {
        _pdState = s;
        _lastPos = s.lastPosition ?? _lastPos;
        if (_lastPos != null) {
          _speedKmh = (_lastPos!.speed * 3.6).clamp(0, 9999);
        }
      });
    });

    // subscribe the means of acceleration
    final sensors = ref.read(sensorsServiceProvider);
    _posSub = sensors.position$.listen((p) { /* setState... */ });
    _accSub = sensors.userAccMag$.listen((a) {
      setState(() {
        _accAvg = a;
      });
    });

    // subscribe the updates of velocity by location
    sensors.position$.listen((p) {
      setState(() {
        _lastPos = p;
        _speedKmh = (p.speed * 3.6).clamp(0, 9999);
      });
    });
  }

  @override
  void dispose() {
    _cubitSub?.cancel();
    _accSub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  Color _stateColor(ParkingState s) {
    switch (s) {
      case ParkingState.driving:
        return Colors.green;
      case ParkingState.parking:
        return Colors.orange;
      case ParkingState.parked:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _pdState.state;
    final lat = _lastPos?.latitude.toStringAsFixed(6) ?? '--';
    final lng = _lastPos?.longitude.toStringAsFixed(6) ?? '--';
    final sp = _speedKmh.toStringAsFixed(1);
    final acc = _accAvg.toStringAsFixed(3);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _stateColor(s),
                    shape: BoxShape.circle,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status  $s   Vel  $sp kmh   Acc  $acc'),
                    const SizedBox(height: 4),
                    Text('Pos  $lat , $lng'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
