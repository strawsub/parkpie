import 'package:flutter/foundation.dart';
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
    on<SetKnownZone>(_onSetKnownZone);

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
      final zoneInfo = await _storage.getZoneInfo();
      emit(
        TimerInitial(
          restrictionDurationMinutes: restrictionMinutes ?? 0,
          zoneNumber: zoneInfo['zoneNumber'] as int?,
          zoneName: zoneInfo['zoneName'] as String?,
        ),
      );
      return;
    }

    final startTime = await _storage.getStartTime();
    if (startTime == null) {
      final restrictionMinutes = await _storage.getRestrictionDuration();
      final zoneInfo = await _storage.getZoneInfo();
      emit(
        TimerInitial(
          restrictionDurationMinutes: restrictionMinutes ?? 0,
          zoneNumber: zoneInfo['zoneNumber'] as int?,
          zoneName: zoneInfo['zoneName'] as String?,
        ),
      );
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
        restrictionDurationMinutes: restrictionMinutes ?? 0,
      ),
    );

    // Schedule notification for remaining time
    _scheduleNotification(
      startTime,
      restrictionMinutes ?? 0,
      zoneInfo['zoneName'] as String?,
      zoneInfo['zoneNumber'] as int?,
    );

    _startTicker();
  }

  Future<void> _onStartTimer(StartTimer event, Emitter<TimerState> emit) async {
    final startTime = DateTime.now();
    _notificationSent = false;

    await _storage.saveStartTime(startTime);
    await _storage.saveIsRunning(true);

    final storedZoneInfo = await _storage.getZoneInfo();
    final zoneNumber = event.zoneNumber ?? storedZoneInfo['zoneNumber'] as int?;
    final zoneName = event.zoneName ?? storedZoneInfo['zoneName'] as String?;
    await _storage.saveZoneInfo(zoneNumber, zoneName);

    late double latitude;
    late double longitude;
    int? restrictionMinutes;
    bool usedFallback = false;
    bool fetchFailed = false;
    int? createdSessionId;

    try {
      final filteredPosition = _locationCubit.state.filteredPosition;
      if (filteredPosition != null && filteredPosition.length >= 2) {
        latitude = filteredPosition[0];
        longitude = filteredPosition[1];
      } else {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }

      final session = await _timerService.createSession(
        lat: latitude,
        lng: longitude,
        startTime: startTime,
      );
      createdSessionId = session?.sessionId;
    } catch (e) {
      final stored = await _storage.getRestrictionDuration();
      if (stored != null && stored == -1) {
        // User selected a zone with no time limit
        restrictionMinutes = 0;
      } else if (stored != null && stored > 0) {
        restrictionMinutes = stored;
        usedFallback = true;
      } else {
        await _handleRestrictionLookupFailure(createdSessionId);
        emit(
          TimerFailure(
            message:
                'We could not determine your location. Please retry once you have a stronger GPS signal.',
            zoneNumber: zoneNumber,
            zoneName: zoneName,
          ),
        );
        return;
      }
    }

    if (restrictionMinutes == null) {
      // First check if user manually set a duration (override)
      final storedDuration = await _storage.getRestrictionDuration();

      if (storedDuration != null && storedDuration == -1) {
        // -1 means user selected a zone with NO time limit - use count-up mode
        restrictionMinutes = 0;
      } else if (storedDuration != null && storedDuration > 0) {
        // User manually set a specific duration
        restrictionMinutes = storedDuration;
      } else {
        // Only fetch from API if no manual override exists
        try {
          restrictionMinutes = await _timerService.fetchRestrictionDuration(
            lat: latitude,
            lng: longitude,
            startTime: startTime,
            zoneNumber: zoneNumber,
          );
        } catch (e) {
          fetchFailed = true;
        }
      }
    }

    // Handle API fetch failures
    if (restrictionMinutes == null || restrictionMinutes < 0) {
      if (fetchFailed) {
        final stored = await _storage.getRestrictionDuration();
        if (stored != null && stored == -1) {
          // Stored -1 means no time limit
          restrictionMinutes = 0;
        } else if (stored != null && stored > 0) {
          // Stored positive value means a valid restriction
          restrictionMinutes = stored;
          usedFallback = true;
        }
      }
    }

    // Only fail if we still don't have a valid restriction value
    // Note: 0 is valid (count-up mode), -1 should have been converted to 0 by now
    if (restrictionMinutes == null || restrictionMinutes < 0) {
      await _handleRestrictionLookupFailure(createdSessionId);
      emit(
        TimerFailure(
          message:
              'No nearby parking sign could be found. Please select a sign on the map or rescan the sign.',
          zoneNumber: zoneNumber,
          zoneName: zoneName,
        ),
      );
      return;
    }

    if (createdSessionId != null) {
      await _storage.saveSessionId(createdSessionId);
    }

    await _storage.saveRestrictionDuration(restrictionMinutes);

    emit(
      TimerRunning(
        elapsed: Duration.zero,
        startTime: startTime,
        zoneNumber: zoneNumber,
        zoneName: zoneName,
        restrictionDurationMinutes: restrictionMinutes,
        usingFallback: usedFallback,
      ),
    );

    _scheduleNotification(startTime, restrictionMinutes, zoneName, zoneNumber);

    _startTicker();
  }

  Future<void> _onStopTimer(StopTimer event, Emitter<TimerState> emit) async {
    // StopTimer is deprecated - use ResetTimer instead
    // This ensures we go straight to reset without intermediate stopped state
    add(const ResetTimer());
  }

  Future<void> _onResetTimer(ResetTimer event, Emitter<TimerState> emit) async {
    _ticker?.cancel();
    _ticker = null;

    // Delete session from database before clearing storage
    final sessionId = await _storage.getSessionId();
    if (sessionId != null) {
      final deleted = await _timerService.deleteSession(sessionId: sessionId);
      if (deleted) {
        debugPrint('Session deleted: ID $sessionId');
      } else {
        debugPrint('Failed to delete session: ID $sessionId');
      }
    }

    await _storage.clearActiveSession();

    // Cancel all notifications
    await _notificationService.cancelTimerNotification();
    _notificationSent = false;

    final zoneInfo = await _storage.getZoneInfo();
    emit(
      TimerInitial(
        zoneNumber: zoneInfo['zoneNumber'] as int?,
        zoneName: zoneInfo['zoneName'] as String?,
      ),
    );
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
          usingFallback: false,
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

  void _scheduleNotification(
    DateTime startTime,
    int restrictionMinutes,
    String? zoneName,
    int? zoneNumber,
  ) {
    if (restrictionMinutes <= 0) {
      return;
    }
    final expiryTime = startTime.add(Duration(minutes: restrictionMinutes));

    _notificationService.scheduleTimerExpiredNotification(
      expiryTime: expiryTime,
      zoneName: zoneName,
      zoneNumber: zoneNumber,
    );
  }

  void _checkAndSendExpiredNotification(
    Duration elapsed,
    int restrictionMinutes,
    String? zoneName,
    int? zoneNumber,
  ) {
    final remainingSeconds = (restrictionMinutes * 60) - elapsed.inSeconds;

    // If time has expired and notification hasn't been sent yet
    if (remainingSeconds <= 0 && !_notificationSent) {
      _notificationSent = true;
      _notificationService.showImmediateNotification(
        zoneName: zoneName,
        zoneNumber: zoneNumber,
      );

      // Also delete the session from database when timer expires
      _deleteExpiredSession();
    }
  }

  Future<void> _onSetKnownZone(
    SetKnownZone event,
    Emitter<TimerState> emit,
  ) async {
    await _storage.saveZoneInfo(event.zoneNumber, event.zoneName);

    if (state is TimerRunning) {
      emit(
        (state as TimerRunning).copyWith(
          zoneNumber: event.zoneNumber,
          zoneName: event.zoneName,
        ),
      );
    } else if (state is TimerInitial) {
      emit(
        (state as TimerInitial).copyWith(
          zoneNumber: event.zoneNumber,
          zoneName: event.zoneName,
        ),
      );
    } else if (state is TimerFailure) {
      emit(
        (state as TimerFailure).copyWith(
          zoneNumber: event.zoneNumber,
          zoneName: event.zoneName,
        ),
      );
    }
  }

  Future<void> _handleRestrictionLookupFailure(int? sessionId) async {
    _ticker?.cancel();
    _ticker = null;
    _notificationSent = false;

    if (sessionId != null) {
      await _timerService.deleteSession(sessionId: sessionId);
    }

    await _storage.clearActiveSession();
    await _notificationService.cancelTimerNotification();
  }

  Future<void> _deleteExpiredSession() async {
    final sessionId = await _storage.getSessionId();
    if (sessionId != null) {
      final deleted = await _timerService.deleteSession(sessionId: sessionId);
      if (deleted) {
        debugPrint('Expired session deleted: ID $sessionId');
      } else {
        debugPrint('Failed to delete expired session: ID $sessionId');
      }
    }
  }
}
