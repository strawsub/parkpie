import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/features/timer/timer_bloc.dart';
import 'package:frontend/features/timer/timer_event.dart';
import 'package:frontend/features/timer/timer_state.dart';
import 'package:frontend/services/timer_service.dart';
import 'package:frontend/features/timer/timer_storage.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/services/gps_correction/location_cubit.dart';
import 'package:geolocator/geolocator.dart';

// Mock classes
class MockTimerStorage extends Mock implements TimerStorage {}

class MockTimerService extends Mock implements TimerService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockLocationCubit extends Mock implements LocationCubit {}

class MockPosition extends Mock implements Position {}

class MockLocationState extends Mock implements LocationState {}

void main() {
  late TimerBloc bloc;
  late MockTimerStorage mockStorage;
  late MockTimerService mockService;
  late MockNotificationService mockNotification;
  late MockLocationCubit mockLocation;

  setUp(() {
    mockStorage = MockTimerStorage();
    mockService = MockTimerService();
    mockNotification = MockNotificationService();
    mockLocation = MockLocationCubit();

    when(() => mockNotification.initialize()).thenAnswer((_) async {});
    when(
      () => mockLocation.state,
    ).thenReturn(LocationState(filteredPosition: null));
    bloc = TimerBloc(
      storage: mockStorage,
      timerService: mockService,
      locationCubit: mockLocation,
      notificationService: mockNotification,
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  group('TimerBloc', () {
    test('initial state is TimerInitial', () {
      expect(bloc.state, isA<TimerInitial>());
    });

    test('LoadTimer emits TimerInitial if timer not running', () async {
      when(() => mockStorage.getIsRunning()).thenAnswer((_) async => false);
      when(
        () => mockStorage.getRestrictionDuration(),
      ).thenAnswer((_) async => 10);
      when(
        () => mockStorage.getZoneInfo(),
      ).thenAnswer((_) async => {'zoneNumber': 1, 'zoneName': 'Test Zone'});

      bloc.add(LoadTimer());
      await Future.delayed(Duration.zero); // allow async code to run

      expect(
        bloc.state,
        isA<TimerInitial>().having(
          (s) => s.restrictionDurationMinutes,
          'restrictionDurationMinutes',
          10,
        ),
      );
    });

    test('StartTimer emits TimerRunning', () async {
      // Mock all async storage methods called in _onStartTimer
      when(
        () => mockNotification.scheduleTimerExpiredNotification(
          expiryTime: any(named: 'expiryTime'),
          zoneName: any(named: 'zoneName'),
          zoneNumber: any(named: 'zoneNumber'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockStorage.saveStartTime(any())).thenAnswer((_) async {});
      when(() => mockStorage.saveIsRunning(any())).thenAnswer((_) async {});
      when(
        () => mockStorage.saveZoneInfo(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mockStorage.getZoneInfo(),
      ).thenAnswer((_) async => {'zoneNumber': 1, 'zoneName': 'Test Zone'});
      when(() => mockStorage.getRestrictionDuration()).thenAnswer(
        (_) async => 30, // <-- this is the key fix
      );
      when(
        () => mockService.createSession(
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          startTime: any(named: 'startTime'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.saveRestrictionDuration(any()),
      ).thenAnswer((_) async {});

      bloc.add(const StartTimer());
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // allow async processing

      expect(bloc.state, isA<TimerRunning>());
    });

    test('ResetTimer emits TimerInitial', () async {
      when(() => mockStorage.getSessionId()).thenAnswer((_) async => null);
      when(() => mockStorage.clearActiveSession()).thenAnswer((_) async {});
      when(
        () => mockNotification.cancelTimerNotification(),
      ).thenAnswer((_) async {});
      when(
        () => mockStorage.getZoneInfo(),
      ).thenAnswer((_) async => {'zoneNumber': 1, 'zoneName': 'Test Zone'});

      bloc.add(const ResetTimer());
      await Future.delayed(Duration.zero);

      expect(bloc.state, isA<TimerInitial>());
    });
  });
}
