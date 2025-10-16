import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/services/api_config.dart';
import 'timer_event.dart';
import 'timer_state.dart';
import 'timer_storage.dart';
import 'package:frontend/services/timer_service.dart';
import 'package:frontend/features/gps_correction/location_cubit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/services/notification_service.dart';

class TimerBloc extends Bloc<TimerEvent, TimerState> {
  final TimerStorage _storage;
  final TimerService _timerService;
  final LocationCubit _locationCubit;
  final NotificationService _notificationService;
  Timer? _ticker;
  bool _notificationSent = false;

  TimerBloc({
    TimerStorage? storage,
    TimerService? timerService,
    required LocationCubit locationCubit,
    NotificationService? notificationService,
  }) : _storage = storage ?? TimerStorage(),
       _timerService =
           timerService ?? TimerService(backendBaseUrl: resolveApiBaseUrl()),
       _locationCubit = locationCubit,
       _notificationService = notificationService ?? NotificationService(),
       super(const TimerInitial()) {
    on<LoadTimer>(_onLoadTimer);
    on<StartTimer>(_onStartTimer);
    on<StopTimer>(_onStopTimer);
    on<ResetTimer>(_onResetTimer);
    on<TimerTick>(_onTimerTick);
    on<UpdateRestrictionDuration>(_onUpdateRestrictionDuration);
    
    // Initialize notification service
    _notificationService.initialize();
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }

  Future<void> _onUpdateRestrictionDuration(
    UpdateRestrictionDuration event,
    Emitter<TimerState> emit,
  ) async {
    // Persist the new restriction duration
    await _storage.saveRestrictionDuration(event.durationMinutes);

    // Emit updated state with new restriction duration
    emit(state.copyWith(restrictionDurationMinutes: event.durationMinutes));
    
    // Reschedule notification if timer is running
    if (state is TimerRunning) {
      final currentState = state as TimerRunning;
      _scheduleNotification(
        currentState.startTime!,
        event.durationMinutes,
        currentState.zoneName,
        currentState.zoneNumber,
      );
    }
  }

  Future<void> _onLoadTimer(LoadTimer event, Emitter<TimerState> emit) async {
    final isRunning = await _storage.getIsRunning();
    if (!isRunning) {
      final restrictionMinutes = await _storage.getRestrictionDuration();
      emit(TimerInitial(restrictionDurationMinutes: restrictionMinutes));
      return;
    }

    final startTime = await _storage.getStartTime();
    if (startTime == null) {
      final restrictionMinutes = await _storage.getRestrictionDuration();
      emit(TimerInitial(restrictionDurationMinutes: restrictionMinutes));
      return;
    }

    final zoneInfo = await _storage.getZoneInfo();
    final elapsed = DateTime.now().difference(startTime);
    final restrictionMinutes = await _storage.getRestrictionDuration();

    emit(
      TimerRunning(
        elapsed: elapsed,
        startTime: startTime,
        zoneNumber: zoneInfo['zoneNumber'] as int?,
        zoneName: zoneInfo['zoneName'] as String?,
        restrictionDurationMinutes: restrictionMinutes,
      ),
    );

    // Schedule notification for remaining time
    _scheduleNotification(
      startTime,
      restrictionMinutes,
      zoneInfo['zoneName'] as String?,
      zoneInfo['zoneNumber'] as int?,
    );

    _startTicker();
  }

  Future<void> _onStartTimer(StartTimer event, Emitter<TimerState> emit) async {
    final startTime = DateTime.now();
    _notificationSent = false;

    // Save local info first
    await _storage.saveStartTime(startTime);
    await _storage.saveIsRunning(true);
    await _storage.saveZoneInfo(event.zoneNumber, event.zoneName);

    double latitude;
    double longitude;
    int? restrictionMinutes;

    try {
      // Get location
      final filteredPosition = _locationCubit.state.filteredPosition;
      if (filteredPosition != null && filteredPosition.length >= 2) {
        latitude = filteredPosition[0];
        longitude = filteredPosition[1];
      } else {
        // Fallback to raw GPS hardware
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }

      // Create parking session in database
      final session = await _timerService.createSession(
        lat: latitude,
        lng: longitude,
        startTime: startTime,
      );

      if (session != null) {
        // Save session ID locally
        await _storage.saveSessionId(session.sessionId);
        print('Session created: ID ${session.sessionId}');
      } else {
        print('Failed to create session in database');
      }

      // Fetch restriction duration
      restrictionMinutes = await _timerService.fetchRestrictionDuration(
        lat: latitude,
        lng: longitude,
        startTime: startTime,
      );

      restrictionMinutes ??= await _storage.getRestrictionDuration();
    } catch (e) {
      print('Error in _onStartTimer: $e');
      restrictionMinutes = await _storage.getRestrictionDuration();
    }

    await _storage.saveRestrictionDuration(restrictionMinutes);

    emit(
      TimerRunning(
        elapsed: Duration.zero,
        startTime: startTime,
        zoneNumber: event.zoneNumber,
        zoneName: event.zoneName,
        restrictionDurationMinutes: restrictionMinutes,
      ),
    );

    // Schedule notification
    _scheduleNotification(
      startTime,
      restrictionMinutes,
      event.zoneName,
      event.zoneNumber,
    );

    _startTicker();
  }

  Future<void> _onStopTimer(StopTimer event, Emitter<TimerState> emit) async {
    _ticker?.cancel();
    _ticker = null;

    await _storage.saveIsRunning(false);
    
    // Cancel scheduled notification
    await _notificationService.cancelTimerNotification();

    // Delete session from database
    final sessionId = await _storage.getSessionId();
    if (sessionId != null) {
      final deleted = await _timerService.deleteSession(sessionId: sessionId);
      if (deleted) {
        print('Session deleted: ID $sessionId');
      } else {
        print('Failed to delete session: ID $sessionId');
      }
    }

    if (state is TimerRunning) {
      final currentState = state as TimerRunning;
      emit(
        TimerStopped(
          elapsed: currentState.elapsed,
          zoneNumber: currentState.zoneNumber,
          zoneName: currentState.zoneName,
          restrictionDurationMinutes: currentState.restrictionDurationMinutes,
        ),
      );
    }
  }

  Future<void> _onResetTimer(ResetTimer event, Emitter<TimerState> emit) async {
    _ticker?.cancel();
    _ticker = null;

    // Delete session from database before clearing storage
    final sessionId = await _storage.getSessionId();
    if (sessionId != null) {
      final deleted = await _timerService.deleteSession(sessionId: sessionId);
      if (deleted) {
        print('Session deleted: ID $sessionId');
      } else {
        print('Failed to delete session: ID $sessionId');
      }
    }

    await _storage.clear();
    
    // Cancel all notifications
    await _notificationService.cancelTimerNotification();
    _notificationSent = false;

    emit(const TimerInitial());
  }

  void _onTimerTick(TimerTick event, Emitter<TimerState> emit) {
    if (state is TimerRunning) {
      final currentState = state as TimerRunning;
      final elapsed = DateTime.now().difference(currentState.startTime!);

      emit(
        TimerRunning(
          elapsed: elapsed,
          startTime: currentState.startTime!,
          zoneNumber: currentState.zoneNumber,
          zoneName: currentState.zoneName,
          restrictionDurationMinutes: currentState.restrictionDurationMinutes,
        ),
      );

      // Check if timer has expired and send immediate notification
      _checkAndSendExpiredNotification(
        elapsed,
        currentState.restrictionDurationMinutes,
        currentState.zoneName,
        currentState.zoneNumber,
      );
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const TimerTick()),
    );
  }
}