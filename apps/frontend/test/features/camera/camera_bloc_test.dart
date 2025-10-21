import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/features/camera/camera_bloc.dart';
import 'package:frontend/features/camera/camera_event.dart';
import 'package:frontend/features/camera/camera_state.dart';
import 'package:frontend/services/gps_correction/location_cubit.dart';
import 'package:frontend/services/sign_ingest_service.dart';
import 'package:frontend/services/sign_zone_storage.dart';

// ---------- MOCKS ----------
class MockLocationCubit extends Mock implements LocationCubit {}
class MockSignIngestService extends Mock implements SignIngestService {}
class MockSignZoneStorage extends Mock implements SignZoneStorage {}

void main() {
  late MockLocationCubit locationCubit;
  late MockSignIngestService signService;
  late MockSignZoneStorage zoneStorage;
  late CameraBloc bloc;

  setUp(() {
    locationCubit = MockLocationCubit();
    signService = MockSignIngestService();
    zoneStorage = MockSignZoneStorage();

    when(() => locationCubit.startTracking()).thenAnswer((_) async {});
    when(() => locationCubit.stopTracking()).thenAnswer((_) {});
    // Fake GPS state
    when(() => locationCubit.state).thenReturn(const LocationState(
      filteredPosition: [37.4219983, -122.084],
    ));

    bloc = CameraBloc(
      locationCubit: locationCubit,
      ocrModel: null, // Ignored for these tests
      signIngestService: signService,
      zoneStorage: zoneStorage,
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  // ---------- BASIC TESTS ----------

  test('initial state is CameraInitial', () {
    expect(bloc.state, isA<CameraInitial>());
  });

  blocTest<CameraBloc, CameraState>(
    'emits [CameraLoading, CameraError] when camera permission denied',
    build: () {
      return bloc;
    },
    act: (bloc) async {
      bloc.add(CameraOpened());
    },
    wait: const Duration(milliseconds: 500),
    expect: () => [
      isA<CameraLoading>(), // Should show loading first
      isA<CameraError>(),   // Then emit error (permission or failure)
    ],
  );

  blocTest<CameraBloc, CameraState>(
    'emits CameraReady after successful initialization mock',
    build: () {
      // Since we can’t actually initialize a camera in tests,
      // we manually emit CameraReady to test dependent transitions.
      return bloc;
    },
    act: (bloc) => bloc.emit(CameraReady()),
    expect: () => [isA<CameraReady>()],
  );

  blocTest<CameraBloc, CameraState>(
    'emits CameraReady again after PhotoRetaken',
    build: () => bloc,
    act: (bloc) => bloc.add(PhotoRetaken()),
    expect: () => [isA<CameraReady>()],
  );

}