# Complete Parking Detection System Documentation

**Last Updated:** 2025-01-21

## Recent Architecture Changes

### 2025-01-21: State Machine Refinements & Bug Fixes
- **Stricter driving detection**: Changed from 3s/10m to 10s/20m requirements for driving confirmation
- **Fixed dialog race condition**: Added `_confirmedParking` flag to prevent state revert when user confirms parking
- **Fixed bluetooth reset delay**: Now uses `forceRefresh()` to immediately update bluetooth status after reset
- **Bluetooth disconnect trigger**: Removed requirement for low speed/still - now triggers instantly in StoppedCandidate
- **ParkingDetected state stability**: Added guards to block sensor votes and timer ticks while in ParkingDetected state
- **CarPlay support**: Now detects both Bluetooth (`AudioPort.bluetooth`) and CarPlay (`AudioPort.carAudio`) as car connections
- **Fixed Driving→StoppedCandidate transition**: Now accepts GPS voting `unknown` (while waiting for parked confirmation) to allow smooth transition when slowing down

### 2025-01-21: GPS Voting Behavior Fix
- **Fixed initial state bug**: GPS now votes `unknown` until driving/parked is confirmed, preventing premature Unknown→Driving transition on app start
- **Confirmation-based voting**: GPS only votes "driving" after meeting both time (10s) AND distance (20m) thresholds
- **Relaxed transition requirements**: `Driving → StoppedCandidate` now requires GPS to NOT be voting "driving" (allows `unknown` or `parked`), preventing GPS confirmation delay from blocking the transition

### 2025-01-20: GPS Filtering Optimization
- **Eliminated double filtering**: GPS speed now uses pre-filtered coordinates from LocationCubit
- **Unified speed threshold**: Changed from hysteresis (1.2-4.1 m/s) to single threshold (2.78 m/s / 10 km/h)
- **Fixed bluetooth initialization**: Now detects existing connections when app starts with CarPlay already connected

### Previous Bug Fixes
- Fixed bluetooth vote update bug: Now listens to ALL BluetoothState types (including BluetoothInitial)
- Fixed dialog dismissal bug: Only resets bluetooth if it was the actual trigger (conditional check added)
- Fixed timeout/gyro dialog loop: Bluetooth reset clears disconnect event, preventing infinite re-showing

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
- **CarPlay**: `AudioPort.carAudio` (wired or wireless CarPlay connection)

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
2. **CarPlay Connection**: Route = `AudioPort.carAudio` → `isConnected = true`
3. **Disconnection**: Route changes to `builtInSpeaker` or other → `isConnected = false`
4. If `_wasConnected = true`, votes `parked` → triggers parking detection

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

**Location:** `parking_status_bloc.dart:173-183`

**Trigger:**
```dart
if (state is ParkingUnknown) {
  // Only GPS detection: speed > 10 km/h + distance > 20m for 10s
  if (gpsVote == SensorVote.driving) {
    return Driving(...);
  }
  // Stay in Unknown until GPS confirms driving
}
```

**Requirements:**
- GPS speed > 2.78 m/s (10 km/h) for ≥10 seconds (increased from 3s for stricter detection)
- AND linear distance > 20 meters (increased from 10m for stricter detection)

**Design Rationale:**
- App starts in Unknown to avoid false driving detection
- Only GPS can trigger initial driving detection (most reliable indicator)
- Once in Driving, never revert back to Unknown

---

### State 2: Driving → StoppedCandidate

**Location:** `parking_status_bloc.dart:188-207`

**Trigger:**
```dart
if (state is Driving) {
  if (isStopped) {  // GPS parked AND Acc still
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
- GPS votes `SensorVote.parked` (speed ≤ 2.78 m/s, low displacement)
- AND Accelerometer votes `SensorVote.parked` (RMS < 0.40 m/s² for 5s)

**Helper Definitions:**
```dart
final gpsVote = sensorVotes['gps_speed'];
final accVote = sensorVotes['accelerometer'];
final isLowSpeed = gpsVote == SensorVote.parked;
final isStill = accVote == SensorVote.parked;
final isStopped = isLowSpeed && isStill;
```

**Candidate Progress Timer:**
- Fires every 1.5 seconds (wall-clock)
- Re-evaluates state even if GPS samples are stale
- Ensures timeout promotion works even with irregular GPS updates

---

### State 3: StoppedCandidate → ParkingDetected or Driving

**Location:** `parking_status_bloc.dart:212-276`

StoppedCandidate is a **waiting state** where the system looks for evidence that the user has actually parked and left the vehicle. There are 3 promotion paths and 1 revert path.

#### Promotion Path 1: Gyro Spike ⚡ (Instant)

**Location:** `parking_status_bloc.dart:245-253`

```dart
// 3. GYRO SPIKE LOGIC: Instant Promotion
if (hasGyroSpike) {
  _cancelCandidateProgressTimer();
  return ParkingDetected(...);  // IMMEDIATE
}
```

**Requirements:**
- Gyroscope rotation > 0.8 rad/s in 3-second window
- Only active in StoppedCandidate state (conditional voting)

**Timing:** Instant (no delay)

**User Action:** Picking up phone to leave vehicle

---

#### Promotion Path 2: Bluetooth Disconnect (Instant)

**Location:** `parking_status_bloc.dart:238-248`

```dart
// Accept bluetooth disconnect even if not fully stopped yet (transitioning)
if (hasBtDisconnect) {
  _cancelCandidateProgressTimer();
  return ParkingDetected(...);
}
```

**Requirements (Fixed 2025-01-21):**
- Bluetooth disconnected after being connected (`_wasConnected = true`)
- Only active in StoppedCandidate state (no additional speed/stillness requirements)

**Bug Fix:** Removed the requirement for `(isLowSpeed || isStill)`. Previously, bluetooth disconnect was only triggered if GPS or accelerometer also voted parked. Now triggers instantly when disconnected in StoppedCandidate, even if sensors are still transitioning.

**Timing:** Instant

**User Action:** Exiting vehicle, disconnecting from CarPlay/Bluetooth stereo

---

#### Promotion Path 3: 60-Second Timeout

**Location:** `parking_status_bloc.dart:256-266`

```dart
if (candidateDuration >= 60.0s && (isLowSpeed || isGpsStale)) {
  _cancelCandidateProgressTimer();
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

**Location:** `parking_status_bloc.dart:216-231`

```dart
if (shouldRevert) {
  _cancelCandidateProgressTimer();
  _resetRevertTracking();
  return Driving(...);
}

// Revert check
bool _checkRevertConditions(...) {
  final gpsVote = sensorVotes['gps_speed'];

  // Only revert if GPS votes "driving"
  if (gpsVote == SensorVote.driving) {
    return true;  // REVERT to Driving
  }

  return false;  // Don't revert
}
```

**Requirements:**
- GPS speed > 2.78 m/s (10 km/h) for ≥10s (same as Unknown → Driving)
- AND linear distance > 20m (same as Unknown → Driving)

**Scenario:** User stopped at red light, then continues driving

---

### State 4: ParkingDetected → Parked or Driving

**Location:** `main.dart:151-238`

When ParkingDetected is reached, a modal bottom sheet appears asking the user to confirm parking.

**State Stability (Fixed 2025-01-21):**

ParkingDetected is now a **stable state** - sensor votes and timer ticks are blocked while awaiting user confirmation:

```dart
// parking_status_bloc.dart:106-109
void _onUpdateSensorVote(...) {
  if (state is Parked) {
    return;  // Block sensor votes in Parked
  }

  if (state is ParkingDetected) {
    return;  // Block sensor votes in ParkingDetected
  }
  // Process vote normally
}

// parking_status_bloc.dart:375-378
void _onCandidateProgressTick(...) {
  if (state is Parked) {
    return;  // Block timer ticks in Parked
  }

  if (state is ParkingDetected) {
    return;  // Block timer ticks in ParkingDetected
  }
  // Process tick normally
}
```

This prevents the state from reverting to Driving or StoppedCandidate while the dialog is shown.

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

#### Outcome B: User Denies Parking (Swipe Down / Cancel)

**Location:** `main.dart:212-222`

```dart
onCancel: () {
  Navigator.pop();

  // Only reset Bluetooth if it was the trigger
  final btVote = parkingBloc.state.sensorVotes['bluetooth'];
  if (btVote == SensorVote.parked) {
    bluetoothBloc.add(ResetBluetooth());
  }

  // Revert to Driving state
  parkingBloc.add(RevertToDriving());
}
```

**State Transition:** ParkingDetected → **Driving**

**Sensor Reset Behavior:**
- **Bluetooth:** Reset only if it was the trigger (conditional check)
- **GPS/Accelerometer:** NOT reset (reflect actual physical state)
- **Gyroscope:** NOT reset (will vote driving in Driving state due to conditional voting)

**Rationale:** User was stopped at red light, not actually parked

---

#### Outcome C: Dialog Dismissed (Swipe Down Gesture)

**Location:** `main.dart:227-245`

```dart
.then((_) {
  if (!mounted) return;

  // CRITICAL: Only revert if user did NOT confirm parking
  // Prevents race condition where .then() fires before UserConfirmedParking processes
  if (!_confirmedParking && parkingBloc.state is ParkingDetected) {
    // Only reset Bluetooth if it was the trigger
    final btVote = parkingBloc.state.sensorVotes['bluetooth'];
    if (btVote == SensorVote.parked) {
      bluetoothBloc.add(ResetBluetooth());
    }
    parkingBloc.add(RevertToDriving());
  }

  // Reset confirmation flag for next dialog
  _confirmedParking = false;
}
```

**Behavior:** Same as Outcome B (treated as denial), but with race condition protection

**Bug Fix (2025-01-21):** Previously, the `.then()` callback would fire when dialog closed for ANY reason, including user confirmation. This caused a race between `UserConfirmedParking()` and `RevertToDriving()`, sometimes resulting in the state reverting to Driving instead of staying Parked. Now uses `_confirmedParking` flag to prevent revert when user confirmed.

**Dialog Re-showing Logic:**
- When re-entering StoppedCandidate, `candidateStartTime` resets to `now`
- Timeout counter restarts from 0
- Bluetooth vote cleared to "unknown" (if it was trigger), prevents instant re-promotion
- Gyro/timeout triggers can occur again after meeting their conditions

---

### State 5: Parked (Terminal State)

**Location:** `parking_status_bloc.dart:294-302`

```dart
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
- Sensors continue updating votes, but state machine ignores them
- Timer is running in background
- User can manually reset via `ResetParking` event

**Exit Path:**
```dart
void _onResetParking(ResetParking event, Emitter<ParkingState> emit) {
  _cancelParkingDetectionTimer();
  _cancelCandidateProgressTimer();

  // Reset all sensor blocs
  gyroBloc.add(ResetGyro());
  accBloc.add(ResetAcc());
  bluetoothBloc.add(ResetBluetooth());
  gpsSpeedBloc.add(GpsSpeedReset());

  emit(ParkingUnknown());
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
| **ParkingDetected**  | Driving           | User denies                              | Swipe down or cancel button                     |
| **Parked**          | Unknown            | Manual reset                             | ResetParking event                              |

### Promotion Path Comparison

| Path              | Trigger             | Requirements                          | Timing         | User Action              |
|-------------------|---------------------|---------------------------------------|----------------|--------------------------|
| Gyro Spike ⚡      | Rotation > 0.8 rad/s | Only in StoppedCandidate              | Instant        | Picking up phone         |
| BT Disconnect     | Bluetooth unpaired   | After connection (no additional checks) | Instant      | Exiting vehicle          |
| 60s Timeout       | Time elapsed         | 60 seconds + stopped                  | After 60s      | Phone left in car        |
| Revert to Driving | GPS driving          | Speed > 10 km/h + distance > 20m for 10s | After GPS confirms | Red light, not parked |

---

## Bug Fixes & Implementation Notes

### Bug Fix 1: Dialog Race Condition (CRITICAL - Fixed 2025-01-21)

**Issue:** After user confirmed parking by sliding, the state would sometimes revert to Driving or StoppedCandidate instead of staying Parked.

**Root Cause:** Race condition between dialog dismiss handler and parking confirmation event:
1. User slides to confirm
2. `onConfirm` calls `Navigator.pop()` → dialog closes
3. `onConfirm` sends `UserConfirmedParking()` event → queued for processing
4. `.then()` callback fires immediately when dialog closes
5. **RACE:** If `UserConfirmedParking` hasn't been processed yet, state is still `ParkingDetected`
6. `.then()` sees `ParkingDetected` → sends `RevertToDriving()` → **OVERRIDES confirmation!**

**Fix (main.dart:103, 169, 232-244):**
```dart
class _HomeContainerState extends State<HomeContainer> {
  bool _confirmedParking = false;  // NEW FLAG

  onConfirm: (...) {
    _confirmedParking = true;  // Mark as confirmed
    Navigator.pop();
    parkingBloc.add(UserConfirmedParking());
  }

  .then((_) {
    if (!_confirmedParking && parkingBloc.state is ParkingDetected) {
      // Only revert if user did NOT confirm
      parkingBloc.add(RevertToDriving());
    }
    _confirmedParking = false;  // Reset
  });
}
```

**Result:** User confirmation is now protected from being overridden.

---

### Bug Fix 2: Bluetooth Status Not Showing After Reset (Fixed 2025-01-21)

**Issue:** After clicking "Reset Parking", bluetooth status would show "not connected" even when CarPlay was plugged in, and would never update even after several minutes.

**Root Cause:**
- `bluetooth_bloc.dart` calls `_service.getCurrentStatus()` after reset
- `getCurrentStatus()` returns cached `_currentRoute` value
- If cache is null or stale, returns wrong status
- Timer polls every 1 second, but only emits if route **changed** (line 55-57 in audio_bluetooth_service.dart)
- If route hasn't changed (still bluetooth), it never emits!

**Fix (audio_bluetooth_service.dart:33-37, bluetooth_bloc.dart:67-75):**
```dart
// audio_bluetooth_service.dart
Future<void> forceRefresh() async {
  await _checkAudioRoute();
  _emitStatus();  // Always emit, even if route unchanged
}

// bluetooth_bloc.dart
Future<void> _onReset(ResetBluetooth event, Emitter<BluetoothState> emit) async {
  _wasConnected = false;
  emit(BluetoothInitial());

  // Force immediate refresh to check hardware and emit status
  await _service.forceRefresh();
}
```

**Result:** After reset, bluetooth status updates immediately with correct hardware state.

---

### Bug Fix 3: ParkingDetected State Instability (Fixed 2025-01-21)

**Issue:** While ParkingDetected dialog was shown, if sensors changed votes (e.g., GPS started voting "driving"), the state could revert to Driving before user confirmed.

**Fix (parking_status_bloc.dart:106-109, 375-378):**
```dart
void _onUpdateSensorVote(...) {
  if (state is ParkingDetected) {
    return;  // Block sensor votes while showing dialog
  }
}

void _onCandidateProgressTick(...) {
  if (state is ParkingDetected) {
    return;  // Block timer ticks while showing dialog
  }
}
```

**Result:** ParkingDetected is now a stable state - only user input can change it.

---

### Bug Fix 4: Bluetooth Disconnect Not Triggering (Fixed 2025-01-21)

**Issue:** When unplugging CarPlay in StoppedCandidate state, parking detection dialog did not appear.

**Root Cause:** Line 239 had requirement `if (hasBtDisconnect && (isLowSpeed || isStill))`. If GPS or accelerometer hadn't voted "parked" yet, bluetooth disconnect was ignored.

**Fix (parking_status_bloc.dart:240):**
```dart
// OLD: if (hasBtDisconnect && (isLowSpeed || isStill))
// NEW: if (hasBtDisconnect)
```

**Result:** Bluetooth disconnect now triggers parking detection instantly in StoppedCandidate, regardless of other sensor states.

---

### Bug Fix 5: Bluetooth Vote Not Updating After Reset

**Issue:** When `ResetBluetooth` was called, it emitted `BluetoothInitial` with `vote="unknown"`, but `ParkingBloc` only listened for `BluetoothConnectionStatus` events. This caused bluetooth vote to stay "parked" in `sensorVotes` map, triggering infinite dialog loop.

**Fix (parking_status_bloc.dart:77-84):**
```dart
_bluetoothSubscription = bluetoothBloc.stream.listen((bluetoothState) {
  // Listen to all bluetooth states (including BluetoothInitial for reset)
  add(UpdateSensorVote(
    sensorName: 'bluetooth',
    vote: bluetoothState.vote,
  ));
});
```

**Result:** Now properly updates vote to "unknown" when bluetooth is reset, preventing instant re-promotion after dialog dismissal.

---

### Bug Fix 6: Unconditional Bluetooth Reset

**Issue:** `ResetBluetooth()` was called whenever dialog was dismissed, regardless of which trigger (bluetooth/gyro/timeout) caused `ParkingDetected`. This could clear legitimate bluetooth state.

**Fix (main.dart:216-218, 231-233):**
```dart
// Only reset Bluetooth if it was the trigger
final btVote = parkingBloc.state.sensorVotes['bluetooth'];
if (btVote == SensorVote.parked) {
  bluetoothBloc.add(ResetBluetooth());
}
```

**Result:** Preserves bluetooth state when timeout or gyro triggered the dialog. Bluetooth only resets if it was actually the trigger.

---

### Bug Fix 7: GPS Double Filtering

**Issue:** Both `LocationCubit` and `GpsSpeedBloc` applied separate Kalman filters, causing slow response and redundant computation.

**Fix (2025-01-20):**
- `GpsSpeedBloc` now subscribes to `LocationCubit.stream` instead of raw GPS
- Uses pre-filtered coordinates to calculate speed
- Removed Kalman speed filter entirely
- Single filtering point: coordinates only

**Result:** Faster GPS speed response, cleaner architecture, eliminated redundancy.

---

### Bug Fix 8: GPS Unknown Votes During Driving

**Issue:** GPS voted "unknown" when speed was between 1.2-4.1 m/s (hysteresis gap), causing state machine confusion during slowdown.

**Fix (2025-01-20):**
- Unified `vIn` and `vOut` to 2.78 m/s (10 km/h)
- GPS always votes driving or parked based on actual state
- "Unknown" only used during initialization (first 2 samples)

**Result:** GPS sensor now honestly reports current state, no more ambiguous votes.

---

### Bug Fix 9: Initial State Always Shows Driving (Fixed 2025-01-21)

**Issue:** When opening the app, the initial state would quickly transition from `Unknown` to `Driving` or `StoppedCandidate`, even when not actually driving yet.

**Root Cause:** GPS bloc used "honest reporting" - it voted `driving` or `parked` **immediately** based on current speed, even before meeting confirmation requirements (10s + 20m). The parking_status_bloc would see `gpsVote == SensorVote.driving` and immediately transition `Unknown → Driving`.

**Fix (gps_speed_bloc.dart:398-399, 416-417, 422):**
```dart
// OLD: Return SensorVote.driving/parked immediately (honest reporting)
if (speed > vThreshold) {
  if (duration >= tCandidate && linearDistance > dDrivingThreshold) {
    return SensorVote.driving;  // CONFIRMED
  }
  return SensorVote.driving;  // ← BUG: votes immediately without confirmation
}

// NEW: Return SensorVote.unknown until confirmed
if (speed > vThreshold) {
  if (duration >= tCandidate && linearDistance > dDrivingThreshold) {
    return SensorVote.driving;  // CONFIRMED
  }
  return SensorVote.unknown;  // ← FIX: wait for confirmation
}
```

**Result:** App now stays in `Unknown` state until GPS **confirms** driving (10s + 20m), preventing premature state transitions on app start.

---

### Bug Fix 10: Bluetooth Not Detecting Existing Connections

**Issue:** When app started with CarPlay already connected, `initialize()` returned early because `_isInitialized = true`, never checking current audio route.

**Fix (audio_bluetooth_service.dart:33-57):**
```dart
Future<void> initialize() async {
  // Always check current audio route, even if already initialized
  await _checkAudioRoute();

  if (_isInitialized) {
    _emitStatus();  // Emit current status for new listeners
    return;
  }

  _startMonitoring();
  _isInitialized = true;
}
```

**Result:** Now detects bluetooth connections regardless of when they occurred relative to app start.

---

### Bug Fix 11: CarPlay Disconnect Not Triggering Parking Detection (Fixed 2025-01-21)

**Issue:** Bluetooth disconnect worked for wireless Bluetooth, but wired CarPlay disconnect did not trigger parking detection dialog.

**Root Cause:** The code only checked for `AudioPort.bluetooth`, but CarPlay uses `AudioPort.carAudio`. When CarPlay cable was unplugged:
- Route changed: `carAudio` → `builtInSpeaker`
- But `isBluetoothConnected` remained `false` (both before and after)
- No change detected → no `parked` vote → no dialog

**Fix (audio_bluetooth_service.dart:37-40):**
```dart
// Check if audio route is a car connection (Bluetooth or CarPlay)
bool _isCarConnection(AudioInput? route) {
  if (route == null) return false;
  return route.port == AudioPort.bluetooth || route.port == AudioPort.carAudio;
}
```

Updated `getCurrentStatus()` and `_emitStatus()` to use `_isCarConnection()` helper.

**Result:** Now detects **both** Bluetooth and CarPlay as car connections:
- **Bluetooth connected**: `AudioPort.bluetooth` → `isConnected = true` → votes `driving`
- **CarPlay connected**: `AudioPort.carAudio` → `isConnected = true` → votes `driving`
- **Disconnect**: Route changes to `builtInSpeaker` → `isConnected = false` → votes `parked`

**Supported Scenarios:**
- Wireless Bluetooth car audio ✅
- Wired CarPlay ✅
- Wireless CarPlay ✅
- Bluetooth headphones (not treated as car connection) ❌

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

**Answer:** YES, automatically.

**How:**
1. User dismisses dialog → state transitions to Driving
2. Car still stopped → GPS + Acc still vote parked
3. State transitions back to StoppedCandidate
4. **NEW** `candidateStartTime` is set to `DateTime.now()`
5. Timeout counter restarts from 0

No explicit reset needed - the state transition creates a fresh `StoppedCandidate` with new timestamp.

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
   - Driving → StoppedCandidate (stopped at red) → dialog appears → user dismisses → Driving (light turns green, GPS detects motion)

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
**Last Updated:** 2025-01-20
**Flutter Version:** 3.x
**Dependencies:** sensors_plus, geolocator, flutter_audio_output, flutter_bloc

---

**End of Documentation**
