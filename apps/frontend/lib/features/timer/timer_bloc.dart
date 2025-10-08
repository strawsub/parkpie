import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'timer_event.dart';
import 'timer_state.dart';
import 'timer_storage.dart';

class TimerBloc extends Bloc<TimerEvent, TimerState> {
  final TimerStorage _storage;
  Timer? _ticker;

  TimerBloc({TimerStorage? storage})
    : _storage = storage ?? TimerStorage(),
      super(const TimerInitial()) {
    on<LoadTimer>(_onLoadTimer);
    on<StartTimer>(_onStartTimer);
    on<StopTimer>(_onStopTimer);
    on<ResetTimer>(_onResetTimer);
    on<TimerTick>(_onTimerTick);
    on<UpdateRestrictionDuration>(_onUpdateRestrictionDuration);
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

    _startTicker();
  }

  Future<void> _onStartTimer(StartTimer event, Emitter<TimerState> emit) async {
    final startTime = DateTime.now();

    await _storage.saveStartTime(startTime);
    await _storage.saveIsRunning(true);
    await _storage.saveZoneInfo(event.zoneNumber, event.zoneName);

    final restrictionMinutes = await _storage.getRestrictionDuration();

    emit(
      TimerRunning(
        elapsed: Duration.zero,
        startTime: startTime,
        zoneNumber: event.zoneNumber,
        zoneName: event.zoneName,
        restrictionDurationMinutes: restrictionMinutes,
      ),
    );

    _startTicker();
  }

  Future<void> _onStopTimer(StopTimer event, Emitter<TimerState> emit) async {
    _ticker?.cancel();
    _ticker = null;

    await _storage.saveIsRunning(false);

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

    await _storage.clear();

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
