# Complete Parking Detection System Documentation

---

## System Overview

The parking detection system uses a **5-state finite state machine** with **sensor fusion** from 4 independent sensors. Each sensor continuously votes on the current state (driving/parked), and the state machine decides when to transition based on these votes.

### State Machine Diagram

```
┌─────────────┐
│   Unknown   │ ◄─── App starts here
└─────────────┘
      │
      │ GPS: speed > 10 km/h + distance > 20m for 10s
      ▼
┌─────────────┐
│   Driving   │
└─────────────┘
      │                    ▲
      │ GPS parked         │ GPS: speed > 10 km/h
      │ + Acc still        │ + distance > 20m for 10s
      ▼                    │
┌─────────────────────────┐│
│  StoppedCandidate       ││
│  (waiting for evidence) ││
└─────────────────────────┘│
      │                    │
      │ 3 promotion paths  │
      │ (instant)          │
      ▼                    │
┌─────────────────┐        │
│ ParkingDetected │────────┘
└─────────────────┘
      │
      │ User confirms "Yes"
      ▼
┌─────────────┐
│   Parked    │ ◄─── Terminal state
└─────────────┘
```

---

## Sensor Layer: 4 Independent Sensors

Each sensor operates independently and continuously votes on the current state. The state machine aggregates these votes to make transition decisions.

### 1. GPS Speed Sensor (`gps_speed_bloc.dart`)

**Purpose:** Detect vehicle movement via GPS speed and displacement

**Data Source:**
- Uses filtered GPS coordinates from `LocationCubit` (Kalman-filtered lat/lng)
- Calculates speed from consecutive filtered coordinate pairs
- No additional speed filtering (eliminated double filtering)

**Key Parameters:**
```dart
Speed threshold: 2.78 m/s (10 km/h) - unified for all GPS accuracy scenarios
Distance threshold: 20 meters (linear distance over time) - increased for stricter detection
Time threshold: 10 seconds for driving confirmation - increased for stricter detection
Window displacement: 12-20 meters (scenario-dependent for parked detection)
Parked confirmation: 4-6 seconds (scenario-dependent)
```

**Voting Logic:**

```dart
// DRIVING VOTE: Speed above threshold
if (speed > 2.78 m/s) {
  // Track distance over time
  if (duration >= 10.0s && linearDistance > 20.0m) {
    return SensorVote.driving;  // CONFIRMED
  }
  return SensorVote.unknown;  // Not confirmed yet - wait for confirmation
}

// PARKED VOTE: Low speed AND small displacement
if (speed <= 2.78 m/s && displacement <= dWindow) {
  if (duration >= tConfirm) {
    return SensorVote.parked;  // CONFIRMED
  }
  return SensorVote.unknown;  // Not confirmed yet - wait for confirmation
}

// Edge cases vote unknown until state is confirmed
```

**Accuracy Scenarios:**
- **Good GPS** (≤10m accuracy): dWindow=12m, tConfirm=4s
- **Medium GPS** (10-20m): dWindow=16m, tConfirm=5s
- **Poor GPS** (>20m): dWindow=20m, tConfirm=6s

**GPS Filtering Architecture:**
```
Raw GPS (Geolocator)
    ↓
LocationCubit Kalman Filter (processNoise=0.0001, measurementNoise=0.01)
    ↓
Filtered Coordinates (lat, lng)
    ↓
GpsSpeedBloc calculates speed from consecutive filtered coordinates
    ↓
Speed value (no additional filtering)
```

**Zero-Speed Detection:**
- If speed < 0.5 m/s AND accuracy > 20m → force speed to 0
- Suppresses GPS drift when stationary

---

### 2. Accelerometer Sensor (`acc_bloc.dart`)

**Purpose:** Detect vehicle stillness via motion magnitude

**Data Processing:**
```
Raw accelerometer (x, y, z)
    ↓
Kalman Filter 3D (processNoise=0.001, measurementNoise=0.05)
    ↓
Magnitude calculation: √(x² + y² + z²)
    ↓
RMS calculation over 5-second sliding window
```

**Key Parameters:**
```dart
Window size: 5.0 seconds
Still threshold (enter): 0.40 m/s² RMS
Still threshold (exit): 0.45 m/s² (hysteresis)
Driving threshold: 0.5 m/s² RMS
Quiet epsilon: 0.50 m/s²
Quiet ratio threshold: 70% of samples below epsilon
Confirmation time: 5 seconds of stillness
```

**Voting Logic:**

```dart
// HIGH MOTION → DRIVING
if (rms > 0.5) {
  return SensorVote.driving;  // Immediate
}

// CHECK FOR STILLNESS
// Step 1: Become stop candidate (3 seconds of low RMS + quiet ratio)
if (rms < 0.40 && quietRatio >= 0.7 && duration >= 3.0s) {
  _isStopCandidate = true;
}

// Step 2: Confirm stopped (5 seconds total as stop candidate)
if (_isStopCandidate && duration >= 5.0s) {
  return SensorVote.parked;
}

// Step 3: While waiting for confirmation, vote driving
if (_isStopCandidate && duration < 5.0s) {
  return SensorVote.driving;  // Prevents premature state transition
}

// Exit stop candidate if motion returns
if (rms > 0.45 && quietRatio < 0.58) {
  _isStopCandidate = false;
}

return SensorVote.unknown;
```

**Hysteresis:** 0.40 m/s² (enter stillness) vs 0.45 m/s² (exit stillness) prevents oscillation

---

### 3. Gyroscope Sensor (`gyro_bloc.dart`)

**Purpose:** Detect phone rotation spikes (user picking up phone to leave vehicle)

**Data Processing:**
```
Raw gyroscope (x, y, z rotation rates)
    ↓
Kalman Filter 3D (processNoise=0.002, measurementNoise=0.08)
    ↓
Magnitude per sample: √(x² + y² + z²)
    ↓
Maximum magnitude over 3-second sliding window
```

**Key Parameters:**
```dart
Window size: 3.0 seconds
Movement threshold: 0.8 rad/s
```

**Voting Logic:**

```dart
final maxRotation = max(all magnitudes in 3s window);

if (maxRotation > 0.8 rad/s) {
  return SensorVote.parked;  // Spike detected = user picking up phone
} else {
  return SensorVote.driving;  // No spike = phone stationary
}
```

**Conditional Voting (parking_status_bloc.dart:105-115):**

Gyroscope votes are **only used in StoppedCandidate state**:

```dart
if (event.sensorName == 'gyroscope' && event.vote == SensorVote.parked) {
  if (state is StoppedCandidate) {
    updatedVotes['gyroscope'] = SensorVote.parked;  // Accept gyro spike
  } else {
    updatedVotes['gyroscope'] = SensorVote.unknown;  // Ignore in other states
  }
}
```

**Rationale:** Prevents false positives at red lights or when phone moves during driving.

---

### 4. Bluetooth Sensor (`bluetooth_bloc.dart`)

**Purpose:** Detect car audio disconnection (Bluetooth stereo, wired CarPlay, wireless CarPlay)

**Data Source:**
- `audio_bluetooth_service.dart` (singleton)
- Polls `FlutterAudioOutput.getCurrentOutput()` every 1 second (reduced from 2s for faster detection)
- Detects when audio route changes from car connection (Bluetooth OR CarPlay) to other output

**Supported Audio Routes:**
- **Bluetooth**: `AudioPort.bluetooth` (wireless car audio, Bluetooth headsets)
- **CarPlay**: Detected by checking if audio route name contains "carplay" (case-insensitive)

**Key State Tracking:**
```dart
bool _wasConnected = false;  // Tracks connection history
AudioInput? _currentRoute;   // Current audio output device
```

**Voting Logic:**

```dart
// isConnected = true when audio route is Bluetooth OR CarPlay
if (isConnected) {
  vote = SensorVote.driving;    // Connected to car (Bluetooth/CarPlay) = driving
  _wasConnected = true;         // Remember we were connected
} else if (_wasConnected) {
  vote = SensorVote.parked;     // Disconnected after connection = parked
} else {
  vote = SensorVote.unknown;    // No connection history
}
```

**How It Works:**
1. **Bluetooth Connection**: Route = `AudioPort.bluetooth` → `isConnected = true`
2. **CarPlay Connection**: Route name contains "carplay" (case-insensitive) → `isConnected = true`
3. **Disconnection**: Route changes to `builtInSpeaker` or other → `isConnected = false`
4. If `_wasConnected = true`, votes `parked` → triggers parking detection

**CarPlay Detection (Fixed 2025-01-21):**
```dart
bool _isCarConnection(AudioInput? route) {
  if (route == null) return false;

  // Check if it's a Bluetooth connection
  if (route.port == AudioPort.bluetooth) return true;

  // CarPlay typically shows up with "CarPlay" in the name
  final name = route.name?.toLowerCase() ?? '';
  if (name.contains('carplay') || name.contains('car play')) return true;

  return false;
}
```

**Rationale:** The `AudioPort.carAudio` constant doesn't exist in `flutter_audio_output` package. CarPlay connections are detected by checking the audio route name instead.

**Service Initialization (Fixed 2025-01-20):**

```dart
Future<void> initialize() async {
  // Always check current audio route, even if already initialized
  await _checkAudioRoute();

  if (_isInitialized) {
    _emitStatus();  // Emit current status for new listeners
    return;
  }

  _startMonitoring();  // Start 2-second polling timer
  _isInitialized = true;
}
```

**Bug Fix:** Now detects existing Bluetooth connections when app starts with CarPlay already connected.

**Reset Behavior (Fixed 2025-01-21):**
```dart
Future<void> _onReset(ResetBluetooth event, Emitter<BluetoothState> emit) async {
  _wasConnected = false;         // Clear connection history
  emit(BluetoothInitial());      // Reset to unknown vote

  // Force immediate refresh to avoid showing stale "disconnected" state
  await _service.forceRefresh();  // Checks hardware and emits current status
}
```

**Bug Fix:** Previously, after reset, bluetooth status would show "not connected" even when CarPlay was plugged in, because `getCurrentStatus()` returned cached `_currentRoute` which was stale. Now uses `forceRefresh()` to immediately check hardware and emit correct status.

---

## State Machine: Detailed Transitions

### State 1: Unknown → Driving

**Location:** `parking_status_bloc.dart:183-196`

**Trigger:**
```dart
if (state is ParkingUnknown) {
  // Only GPS detection: speed > 2.78 m/s (10 km/h) AND distance > 20m for 10s
  if (gpsVote == SensorVote.driving) {
    return Driving(...);
  }
  // Stay in Unknown until GPS confirms driving
}
```

**Requirements:**
- GPS speed > 2.78 m/s (10 km/h) sustained for ≥10 seconds
- AND linear distance > 20 meters accumulated during that time

**Design Rationale:**
- App starts in Unknown to avoid false driving detection
- Only GPS can trigger initial driving detection (most reliable indicator)
- Once in Driving, never revert back to Unknown
- Stricter thresholds (10s + 20m) prevent false positives from GPS drift or brief movements

---

### State 2: Driving → StoppedCandidate

**Location:** `parking_status_bloc.dart:198-222`

**Trigger:**
```dart
if (state is Driving) {
  // Transition when GPS is not actively voting "driving" AND accelerometer is still
  // This allows transition even when GPS votes "unknown" (waiting for parked confirmation)
  if (isStoppedOrSlowing) {
    _startCandidateProgressTimer();  // 1.5s wall-clock timer
    return StoppedCandidate(
      candidateStartTime: now,
      latchedGyroSpikeTime: null,  // No longer used
    );
  }
  // Stay in Driving
}
```

**Requirements:**
- GPS is NOT actively voting "driving" (can be "parked" or "unknown")
- AND Accelerometer votes `SensorVote.parked` (RMS < 0.40 m/s² for 5s)

**Helper Definitions:**
```dart
final gpsVote = sensorVotes['gps_speed'];
final accVote = sensorVotes['accelerometer'];
final isNotDriving = gpsVote != SensorVote.driving;  // unknown or parked = not actively driving
final isStill = accVote == SensorVote.parked;
final isStoppedOrSlowing = isNotDriving && isStill;  // For Driving→StoppedCandidate transition
```

**Rationale for "isStoppedOrSlowing":**
- GPS needs 4-6 seconds to confirm "parked" state (confirmation-based voting)
- During this confirmation period, GPS votes "unknown"
- Waiting for GPS "parked" vote would delay transition by 4-6 seconds
- Using "isNotDriving" allows faster transition when car stops

**Candidate Progress Timer:**
- Fires every 1.5 seconds (wall-clock)
- Re-evaluates state even if GPS samples are stale
- Ensures timeout promotion works even with irregular GPS updates

---

### State 3: StoppedCandidate → ParkingDetected or Driving

**Location:** `parking_status_bloc.dart:224-302`

StoppedCandidate is a **waiting state** where the system looks for evidence that the user has actually parked and left the vehicle. There are 3 promotion paths and 1 revert path.

#### Promotion Path 1: Gyro Spike ⚡ (Instant)

**Location:** `parking_status_bloc.dart:270-279`

```dart
// 3. GYRO SPIKE LOGIC: Instant Promotion (no freeze window)
if (hasGyroSpike) {
  _cancelCandidateProgressTimer();
  // Immediate promotion to ParkingDetected on gyro spike
  return ParkingDetected(...);
}
```

**Requirements:**
- Gyroscope rotation > 0.8 rad/s in 3-second window
- Only active in StoppedCandidate state (conditional voting)

**Timing:** Instant (no delay)

**User Action:** Picking up phone to leave vehicle

---

#### Promotion Path 2: Bluetooth Disconnect (Instant)

**Location:** `parking_status_bloc.dart:248-268`

```dart
// 2. CHECK FOR BT DISCONNECT (instant promotion in StoppedCandidate)
// Accept bluetooth disconnect even if not fully stopped yet (transitioning)

// DEBUG LOGGING
<!-- debugPrint('=== BLUETOOTH DISCONNECT CHECK ===');
debugPrint('Current state: StoppedCandidate');
debugPrint('btVote: ${sensorVotes['bluetooth']}');
debugPrint('hasBtDisconnect: $hasBtDisconnect');
debugPrint('All sensor votes: $sensorVotes');
debugPrint('==================================='); -->

if (hasBtDisconnect) {
  debugPrint('>>> BLUETOOTH DISCONNECT DETECTED - Transitioning to ParkingDetected');
  _cancelCandidateProgressTimer();
  // No auto-confirm timer - stay in ParkingDetected until user confirms
  return ParkingDetected(...);
}
```

**Requirements:**
- Bluetooth disconnected after being connected (`_wasConnected = true`)
- Only active in StoppedCandidate state (no additional speed/stillness requirements)

**Timing:** Instant

**User Action:** Exiting vehicle, disconnecting from CarPlay/Bluetooth stereo

---

#### Promotion Path 3: 60-Second Timeout

**Location:** `parking_status_bloc.dart:281-292`

```dart
// 4. CHECK CANDIDATE TIMEOUT (T_limit = 60s) → AUTO-PROMOTE if no motion
final candidateDuration = now.difference(candidateState.candidateStartTime);
if (candidateDuration >= _candidateTimeout && (isLowSpeed || isGpsStale)) {
  // After 60s with no gyro spike but still stopped, promote to ParkingDetected
  _cancelCandidateProgressTimer();
  // No auto-confirm timer - stay in ParkingDetected until user confirms
  return ParkingDetected(...);
}
```

**Requirements:**
- 60 seconds in StoppedCandidate
- AND (GPS still voting parked OR GPS stale/unavailable)

**Timing:** After 60 seconds

**Purpose:** Handle case where user parks but doesn't pick up phone (phone left in car)

---

#### Revert Path: Back to Driving

**Location:** `parking_status_bloc.dart:230-246`

```dart
// 1. CHECK FOR REVERT TO DRIVING (with hysteresis)
final shouldRevert = _checkRevertConditions(
  sensorVotes,
  currentAccRMS,
  isGpsStale,
  now,
);

if (shouldRevert) {
  _cancelCandidateProgressTimer();
  _resetRevertTracking();
  return Driving(...);
}

// Revert check (lines 336-353)
bool _checkRevertConditions(...) {
  final gpsVote = sensorVotes['gps_speed'];

  // Only revert if GPS votes "driving" (speed > 2.78 m/s / 10 km/h AND distance > 20m for 10s)
  // No GPS stale handling, no accelerometer-only revert
  if (gpsVote == SensorVote.driving) {
    return true;  // REVERT to Driving
  }

  return false;  // Don't revert
}
```

**Requirements:**
- GPS speed > 2.78 m/s (10 km/h) sustained for ≥10 seconds
- AND linear distance > 20 meters (same thresholds as Unknown → Driving)

**Scenario:** User stopped at red light, then continues driving

---

### State 4: ParkingDetected → Parked or StoppedCandidate

**Location:** `main.dart:130-248`

When ParkingDetected is reached, a modal bottom sheet appears asking the user to confirm parking.

**State Stability:**

ParkingDetected is a **stable state** - sensor votes and timer ticks are blocked while awaiting user confirmation:

```dart
// parking_status_bloc.dart:98-110
void _onUpdateSensorVote(...) {
  // IGNORE sensor votes when in Parked state (terminal state)
  if (state is Parked) {
    return;  // Don't process sensor votes in terminal state
  }

  // IGNORE sensor votes when in ParkingDetected state (awaiting user confirmation)
  if (state is ParkingDetected) {
    return;  // Don't process sensor votes while showing confirmation dialog
  }
  // Process vote normally
}

// parking_status_bloc.dart:381-393
void _onCandidateProgressTick(...) {
  // IGNORE timer ticks when in Parked state (terminal state)
  if (state is Parked) {
    return;  // Don't process timer ticks in terminal state
  }

  // IGNORE timer ticks when in ParkingDetected state (awaiting user confirmation)
  if (state is ParkingDetected) {
    return;  // Don't process timer ticks while showing confirmation dialog
  }
  // Process tick normally
}
```

This prevents the state from changing while the dialog is shown.

#### Dialog Display

```dart
void _showParkingDialog(BuildContext context) {
  showModalBottomSheet(
    isDismissible: true,  // Can swipe down to dismiss
    isScrollControlled: true,
    builder: (_) => ParkingDetectedBottomSheet(...),
  );
}
```

**Dialog Features:**
- Shows current time
- Displays nearby parking zones (fetched via GPS)
- Allows zone selection OR manual duration override
- Slide-to-park confirmation gesture
- Can be dismissed by swiping down

#### Outcome A: User Confirms Parking (Slide to Park)

**Location:** `main.dart:167-212`

```dart
onConfirm: (selectedMinutes, selectedZone) {
  _confirmedParking = true;  // NEW: Prevent race condition with .then() callback
  Navigator.pop();
  parkingBloc.add(UserConfirmedParking());  // → Parked state

  // Set timer duration
  if (selectedMinutes != null) {
    // Manual override takes priority
    timerBloc.add(UpdateRestrictionDuration(selectedMinutes));
  } else if (selectedZone != null) {
    // Use zone's time limit
    if (selectedZone.maximumStayMinutes != null) {
      timerBloc.add(UpdateRestrictionDuration(selectedZone.maximumStayMinutes));
    } else {
      timerBloc.add(UpdateRestrictionDuration(-1));  // No restriction
    }
    timerBloc.add(SetKnownZone(...));
  }

  timerBloc.add(StartTimer());
  navigationCubit.setIndex(2);  // Navigate to timer screen
}
```

**State Transition:** ParkingDetected → **Parked** (terminal state)

**Timer Behavior:**
- Manual override (30/60/120 min): Uses selected duration
- Zone selection: Uses zone's `maximumStayMinutes`
- No zone restriction: Duration = -1 (count up mode)

---

#### Outcome B: User Denies Parking (Cancel Button)

**Location:** `main.dart:218-228`

```dart
onCancel: () {
  _isParkingDialogShowing = false;
  Navigator.of(parentContext).pop();

  // Only reset Bluetooth if it was the trigger (bluetooth vote = parked)
  final btVote = parkingBloc.state.sensorVotes['bluetooth'];
  if (btVote == SensorVote.parked) {
    bluetoothBloc.add(const ResetBluetooth());
  }

  // Revert to Driving state
  parkingBloc.add(const RevertToDriving());
}
```

**State Transition:** ParkingDetected → **StoppedCandidate** (Fixed 2025-01-21)

**Sensor Reset Behavior:**
- **Bluetooth:** Reset only if it was the trigger (conditional check)
- **GPS/Accelerometer:** NOT reset (reflect actual physical state)
- **Gyroscope:** NOT reset (will vote driving in non-StoppedCandidate states due to conditional voting)

**Bug Fix (2025-01-21):** Previously reverted to **Driving** state, skipping StoppedCandidate entirely. Now reverts to **StoppedCandidate** with reset timer (`candidateStartTime = DateTime.now()`), allowing the system to re-detect parking if user stays stopped.

**Rationale:** User dismissed the dialog but is still stopped. Reverting to StoppedCandidate allows:
- If user stays stopped: System can re-detect parking via gyro spike, BT disconnect, or 60s timeout
- If user starts driving: GPS will detect motion and revert to Driving normally

---

#### Outcome C: Dialog Dismissed (Swipe Down Gesture)

**Location:** `main.dart:230-248`

```dart
.then((_) {
  if (!mounted) return;
  // Handle dismissal by swipe down (or any other dismissal method)
  _isParkingDialogShowing = false;

  // CRITICAL: Only revert if user did NOT confirm parking
  // Prevents race condition where .then() fires before UserConfirmedParking processes
  if (!_confirmedParking && parkingBloc.state is ParkingDetected) {
    // Only reset Bluetooth if it was the trigger (bluetooth vote = parked)
    final btVote = parkingBloc.state.sensorVotes['bluetooth'];
    if (btVote == SensorVote.parked) {
      bluetoothBloc.add(const ResetBluetooth());
    }
    parkingBloc.add(const RevertToDriving());
  }

  // Reset confirmation flag for next dialog
  _confirmedParking = false;
})
```

**State Transition:** ParkingDetected → **StoppedCandidate** (same as Outcome B)

**Bug Fix (2025-01-21):**
1. **Race condition fix:** Previously, the `.then()` callback would fire when dialog closed for ANY reason, including user confirmation. This caused a race between `UserConfirmedParking()` and `RevertToDriving()`, sometimes resulting in the state reverting instead of staying Parked. Now uses `_confirmedParking` flag to prevent revert when user confirmed.
2. **Unified dismissal behavior:** Now both gyro spike dismissal AND bluetooth disconnect dismissal revert to **StoppedCandidate** (not Driving), providing consistent behavior regardless of trigger type.

**Dialog Re-showing Logic:**
- When re-entering StoppedCandidate, `candidateStartTime` resets to `now` (fresh 60-second window)
- Bluetooth vote cleared to "unknown" (if it was trigger), prevents instant re-promotion
- Gyro/timeout triggers can occur again after meeting their conditions
- If user stays stopped, system can re-detect parking faster

---

### State 5: Parked (Terminal State)

**Location:** `parking_status_bloc.dart:317-328`

```dart
// ------------------------------
// PARKED (Terminal State - No transitions out)
// ------------------------------
if (state is Parked) {
  // Parked is a terminal state - no automatic transitions
  // User must manually reset if they want to return to driving detection
  return Parked(
    sensorVotes: sensorVotes,
    drivingVotes: drivingVotes,
    parkedVotes: parkedVotes,
  );
}
```

**Characteristics:**
- No automatic transitions out
- Sensors continue updating votes, but state machine ignores them (blocked at event handler level)
- Timer is running in background
- User can manually reset via `ResetParking` event

**Exit Path:**
```dart
void _onResetParking(ResetParking event, Emitter<ParkingState> emit) {
  _cancelParkingDetectionTimer();
  _cancelCandidateProgressTimer();
  _resetRevertTracking();

  // Reset all sensor blocs
  gyroBloc.add(const ResetGyro());
  accBloc.add(const ResetAcc());
  bluetoothBloc.add(const ResetBluetooth());
  gpsSpeedBloc.add(const GpsSpeedReset());

  // Reset to unknown state
  emit(const ParkingUnknown());
}
```

---

## Summary Tables

### Sensor Vote Summary

| Sensor         | Driving Vote                              | Parked Vote                                 | Unknown Vote              |
|----------------|-------------------------------------------|---------------------------------------------|---------------------------|
| **GPS**        | Speed > 10 km/h + 20m for 10s (confirmed) | Speed ≤ 10 km/h + low disp. for 4-6s (confirmed) | Until confirmed     |
| **Accelerometer** | RMS > 0.5 m/s²                          | RMS < 0.4 m/s² for 5s + quiet ratio > 70%  | Initial state             |
| **Gyroscope**  | Rotation ≤ 0.8 rad/s                      | Rotation > 0.8 rad/s (spike)                | -                         |
| **Bluetooth**  | Connected to car audio                    | Disconnected after connection               | No connection history     |

### State Transition Summary

| From State          | To State           | Trigger                                  | Requirements                                    |
|---------------------|--------------------|------------------------------------------|-------------------------------------------------|
| **Unknown**         | Driving            | GPS driving                              | Speed > 10 km/h + distance > 20m for 10s        |
| **Driving**         | StoppedCandidate   | GPS + Acc stopped                        | Both vote parked                                |
| **StoppedCandidate** | ParkingDetected   | Gyro spike                               | Rotation > 0.8 rad/s (instant)                  |
| **StoppedCandidate** | ParkingDetected   | Bluetooth disconnect                     | Disconnected (instant, no other requirements)   |
| **StoppedCandidate** | ParkingDetected   | Timeout                                  | 60 seconds + stopped                            |
| **StoppedCandidate** | Driving           | GPS driving                              | Speed > 10 km/h + distance > 20m for 10s        |
| **ParkingDetected**  | Parked            | User confirms                            | Slide-to-park gesture                           |
| **ParkingDetected**  | StoppedCandidate  | User denies                              | Swipe down or cancel button (timer resets)      |
| **Parked**          | Unknown            | Manual reset                             | ResetParking event                              |

### Promotion Path Comparison

| Path              | Trigger             | Requirements                          | Timing         | User Action              |
|-------------------|---------------------|---------------------------------------|----------------|--------------------------|
| Gyro Spike ⚡      | Rotation > 0.8 rad/s | Only in StoppedCandidate              | Instant        | Picking up phone         |
| BT Disconnect     | Bluetooth unpaired   | After connection (no additional checks) | Instant      | Exiting vehicle          |
| 60s Timeout       | Time elapsed         | 60 seconds + stopped                  | After 60s      | Phone left in car        |
| Revert to Driving | GPS driving          | Speed > 10 km/h + distance > 20m for 10s | After GPS confirms | Red light, not parked |

---

## Technical Implementation Details

### Sensor Reset Behavior on Dialog Dismissal

| Sensor         | Reset on Dismiss? | Reason                                                                 |
|----------------|-------------------|------------------------------------------------------------------------|
| **Bluetooth**  | Conditional       | Only if it was the trigger (prevents re-trigger, clears _wasConnected) |
| **GPS**        | NO                | Reflects actual vehicle motion, needed for revert-to-driving detection |
| **Accelerometer** | NO            | Reflects actual vehicle stillness, needed for state transitions        |
| **Gyroscope**  | NO                | Conditional voting ensures it only matters in StoppedCandidate         |

### Conditional Gyroscope Voting

**Why:** Gyroscope detects phone movement, which happens both when exiting vehicle (parked) and during driving (phone shifts, bumps, red lights).

**Solution:** Only accept gyro "parked" votes in StoppedCandidate state:

```dart
// parking_status_bloc.dart:105-115
if (event.sensorName == 'gyroscope' && event.vote == SensorVote.parked) {
  if (state is StoppedCandidate) {
    updatedVotes[event.sensorName] = event.vote;  // Accept spike
  } else {
    updatedVotes[event.sensorName] = SensorVote.unknown;  // Ignore
  }
}
```

This prevents false positives while preserving detection when actually needed.

### Timeout Counter Reset Logic

**Question:** When user dismisses dialog, does the 60-second timeout reset?

**Answer:** YES, explicitly reset.

**How (Fixed 2025-01-21):**
```dart
// parking_status_bloc.dart:444-462
void _onRevertToDriving(
    RevertToDriving event,
    Emitter<ParkingState> emit,
    ) {
  _cancelParkingDetectionTimer();
  _resetRevertTracking();

  // Revert to StoppedCandidate state (not Driving)
  // User dismissed parking dialog, but we should stay in candidate state
  // This allows the system to re-detect parking if user stays stopped
  _startCandidateProgressTimer();
  emit(StoppedCandidate(
    sensorVotes: state.sensorVotes,
    drivingVotes: state.drivingVotes,
    parkedVotes: state.parkedVotes,
    candidateStartTime: DateTime.now(),  // Reset timer to NOW
    latchedGyroSpikeTime: null,
  ));
}
```

**Process:**
1. User dismisses dialog → `RevertToDriving()` event fires
2. State transitions to **StoppedCandidate** (not Driving)
3. `candidateStartTime` is explicitly set to `DateTime.now()`
4. Timeout counter restarts from 0
5. Candidate progress timer re-starts

**Benefit:** Fresh 60-second window allows the system to re-detect parking if user stays stopped, rather than immediately showing the dialog again.

---

## File Structure

```
parking_status_detection/
├── README.md (this file)
├── parking_status_bloc.dart          # Main state machine
├── parking_status_state.dart         # State definitions
├── parking_status_event.dart         # Event definitions
├── utils.dart                        # Shared utilities (Kalman filters, votes)
│
├── gps/
│   ├── gps_speed_bloc.dart           # GPS speed sensor
│   ├── gps_speed_state.dart
│   ├── gps_speed_event.dart
│   └── gps_speed_config.dart         # GPS thresholds
│
├── accelerometer/
│   ├── acc_bloc.dart                 # Accelerometer sensor
│   ├── acc_state.dart
│   └── acc_event.dart
│
├── gyroscope/
│   ├── gyro_bloc.dart                # Gyroscope sensor
│   ├── gyro_state.dart
│   └── gyro_event.dart
│
└── bluetooth/
    ├── bluetooth_bloc.dart           # Bluetooth sensor
    ├── bluetooth_state.dart
    ├── bluetooth_event.dart
    └── audio_bluetooth_service.dart  # Audio route monitoring
```

---

## Usage Example

### Initialize Parking Detection

```dart
// Create sensor blocs
final locationCubit = LocationCubit();
final accBloc = AccBloc();
final gyroBloc = GyroBloc();
final bluetoothBloc = BluetoothBloc();
final gpsSpeedBloc = GpsSpeedBloc(locationCubit: locationCubit);

// Create parking bloc with sensor dependencies
final parkingBloc = ParkingBloc(
  accBloc: accBloc,
  gyroBloc: gyroBloc,
  bluetoothBloc: bluetoothBloc,
  gpsSpeedBloc: gpsSpeedBloc,
);

// Provide via MultiBlocProvider
BlocProvider<LocationCubit>.value(value: locationCubit),
BlocProvider<AccBloc>.value(value: accBloc),
BlocProvider<GyroBloc>.value(value: gyroBloc),
BlocProvider<BluetoothBloc>.value(value: bluetoothBloc),
BlocProvider<GpsSpeedBloc>.value(value: gpsSpeedBloc),
BlocProvider<ParkingBloc>.value(value: parkingBloc),
```

### Listen to Parking State Changes

```dart
BlocListener<ParkingBloc, ParkingState>(
  listener: (context, state) {
    if (state is ParkingDetected) {
      _showParkingDialog(context);
    }

    if (state is Parked) {
      context.read<TimerBloc>().add(StartTimer());
      context.read<NavigationCubit>().setIndex(2);  // Go to timer screen
    }
  },
  child: ...,
)
```

### Manually Reset Parking Detection

```dart
context.read<ParkingBloc>().add(ResetParking());
```

---

## Testing & Debugging

### Debug Screen

The app includes a debug screen (`debug_screen.dart`) that shows:
- Current parking state
- Sensor votes (GPS, Acc, Gyro, Bluetooth)
- GPS speed (raw/filtered values now identical)
- Accelerometer RMS and quiet ratio
- Gyroscope max rotation
- Bluetooth connection status
- Candidate timer progress (in StoppedCandidate)

### Test Events

```dart
// Manually trigger parking detection (for UI testing)
parkingBloc.add(TriggerTestParkingDetection());

// Manually confirm parking
parkingBloc.add(UserConfirmedParking());

// Revert to driving
parkingBloc.add(RevertToDriving());

// Full reset
parkingBloc.add(ResetParking());
```

### Common Test Scenarios

1. **Start app, drive, park, confirm:**
   - Unknown → Driving (GPS confirms) → StoppedCandidate (GPS+Acc stopped) → ParkingDetected (gyro spike) → Parked (user confirms)

2. **Red light false positive:**
   - Driving → StoppedCandidate (stopped at red) → dialog appears → user dismisses → StoppedCandidate (timer resets) → light turns green → GPS detects motion → Driving

3. **Bluetooth disconnect:**
   - Driving → StoppedCandidate (car stopped) → ParkingDetected (CarPlay disconnects) → Parked (user confirms)

4. **Timeout fallback:**
   - Driving → StoppedCandidate (car stopped, phone left in car) → wait 60s → ParkingDetected → user returns, sees dialog

5. **Already connected Bluetooth:**
   - Start app with CarPlay already connected → BluetoothBloc immediately detects connection → votes "driving"

---

## Performance Considerations

### Sensor Sampling Rates

- **GPS:** Dynamic - 0m distance filter (increased from 1m for faster response)
- **Accelerometer:** ~100 Hz (sensors_plus default)
- **Gyroscope:** ~100 Hz (sensors_plus default)
- **Bluetooth:** Polled every 1 second (increased from 2s for faster detection)

### Memory Usage

- **GPS window:** Stores last 6-8 seconds of samples (~6-8 LocationSample objects)
- **Accelerometer window:** Last 5 seconds (~500 AccSample objects at 100 Hz)
- **Gyroscope window:** Last 3 seconds (~300 GyroSample objects at 100 Hz)
- **Bluetooth:** No buffering, immediate status updates

### CPU Usage

- **Kalman filtering:** Applied to Acc (3D), Gyro (3D), GPS coordinates (2D) - lightweight operations
- **RMS calculation:** Incremental (maintains running sum of squares)
- **Distance calculation:** Haversine formula per GPS sample (~1-2 per second)

---

## Future Improvements

### Potential Enhancements

1. **Machine Learning:** Train classifier on sensor patterns to improve parking detection accuracy
2. **Context Awareness:** Use geofencing to disable detection on highways, enable in parking areas
3. **Battery Optimization:** Adaptive sampling rates based on motion state
4. **Multi-stop Detection:** Handle drive-throughs, gas stations (brief stops, not parking)
5. **Parking Zone Integration:** Auto-suggest parking zones based on detected location

### Known Limitations

1. **GPS Accuracy:** Poor GPS (tunnels, urban canyons) may delay driving detection
2. **Phone Placement:** Gyroscope sensitivity depends on phone position in vehicle
3. **Bluetooth Variability:** Some vehicles maintain connection briefly after exiting
4. **Accelerometer Noise:** Rough roads may delay stillness detection

---

## License & Credits

**Author:** ParkPie Team
**Last Updated:** 2025-01-21
**Flutter Version:** 3.x
**Dependencies:** sensors_plus, geolocator, flutter_audio_output, flutter_bloc

**Recent Changes:**
- 2025-01-21: Fixed dialog dismissal to revert to StoppedCandidate (not Driving), updated CarPlay detection to use name-based matching, corrected GPS threshold documentation (10 km/h, 20m, 10s)

---

**End of Documentation**
