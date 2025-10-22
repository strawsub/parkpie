import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/map/map_screen.dart';
import 'package:frontend/features/map/pin/pin_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  late MapScreenCubit cubit;

  setUp(() {
    cubit = MapScreenCubit();
  });

  tearDown(() {
    cubit.close();
  });

  group('MapScreenCubit', () {

    test('clearCommands clears commands when not empty', () {
      final stateWithCommands = cubit.state.copyWith(commands: [
        MapScreenAnimateCameraCommand(
          target: const LatLng(0, 0),
          zoom: 15,
          animate: false,
        ),
      ]);
      cubit.emit(stateWithCommands);

      cubit.clearCommands();

      expect(cubit.state.commands, isEmpty);
    });

    test('clearCommands does nothing when commands are already empty', () {
      final initialState = cubit.state;
      cubit.clearCommands();
      expect(cubit.state, equals(initialState));
    });

    test('onCameraMove updates liveZoom when zoom changes enough', () {
      final oldZoom = cubit.state.liveZoom;
      final newPosition = CameraPosition(target: const LatLng(0, 0), zoom: oldZoom + 0.5);
      cubit.onCameraMove(newPosition);
      expect(cubit.state.liveZoom, equals(newPosition.zoom));
    });

    test('onCameraMove does nothing when zoom change < threshold', () {
      final oldZoom = cubit.state.liveZoom;
      final newPosition = CameraPosition(target: const LatLng(0, 0), zoom: oldZoom + 0.0001);
      cubit.onCameraMove(newPosition);
      expect(cubit.state.liveZoom, equals(oldZoom));
    });

    test('notifyFilterSheetOpened sets isFilterOpen to true', () {
      cubit.notifyFilterSheetOpened();
      expect(cubit.state.isFilterOpen, isTrue);
    });

    test('notifyFilterSheetClosed sets isFilterOpen to false', () {
      cubit.notifyFilterSheetOpened();
      cubit.notifyFilterSheetClosed();
      expect(cubit.state.isFilterOpen, isFalse);
    });

    test('onCameraAnimationComplete sets isAnimating to false', () {
      final animState = cubit.state.copyWith(isAnimating: true);
      cubit.emit(animState);
      cubit.onCameraAnimationComplete();
      expect(cubit.state.isAnimating, isFalse);
    });

    test('onCameraIdle rebuilds markers when zoom crosses threshold', () {
      final state = cubit.state.copyWith(
        renderZoom: 12,
        liveZoom: 18,
        pinZoomThreshold: 15,
        hysteresis: 1,
      );
      cubit.emit(state);

      expectLater(
        cubit.stream,
        emits(predicate<MapScreenState>(
          (s) => s.renderZoom == 18,
        )),
      );

      cubit.onCameraIdle();
    });

    test('onPinsUpdated recenters map only on first update with pins', () async {
      final pins = [
        Pin(lat: 10.0, lng: 20.0, id: '1'),
        Pin(lat: 10.5, lng: 20.5, id: '2'),
      ];

      await cubit.onPinsUpdated(pins);

      expect(cubit.state.hasCenteredInitially, isTrue);
      expect(cubit.state.commands, isNotEmpty);
      expect(cubit.state.commands.first, isA<MapScreenAnimateCameraCommand>());
    });

    test('onPinsUpdated does not recenter when pins empty', () async {
      await cubit.onPinsUpdated([]);
      expect(cubit.state.hasCenteredInitially, isFalse);
    });
  });
}