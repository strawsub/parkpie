# Complete Parking Detection System Documentation

**Last Updated:** 2025-01-20

## Recent Architecture Changes

### 2025-01-20: GPS Filtering Optimization
- **Eliminated double filtering**: GPS speed now uses pre-filtered coordinates from LocationCubit
- **Unified speed threshold**: Changed from hysteresis (1.2-4.1 m/s) to single threshold (2.78 m/s / 10 km/h)
- **Removed "unknown" votes**: GPS now always votes either "driving" or "parked" based on actual state
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
      │ GPS: speed > 10 km/h + distance > 10m for 3s
      ▼
┌─────────────┐
│   Driving   │
└─────────────┘
      │                    ▲
      │ GPS parked         │ GPS: speed > 10 km/h
      │ + Acc still        │ + distance > 10m for 3s
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
Distance threshold: 10 meters (linear distance over time)
Time threshold: 3 seconds for driving confirmation
Window displacement: 12-20 meters (scenario-dependent for parked detection)
Parked confirmation: 4-6 seconds (scenario-dependent)
```

**Voting Logic:**

```dart
// DRIVING VOTE: Speed above threshold
if (speed > 2.78 m/s) {
  // Track distance over time
  if (duration >= 3.0s && linearDistance > 10.0m) {
    return SensorVote.driving;  // CONFIRMED
  }
  return SensorVote.driving;  // Honest reporting: moving but not confirmed
}

// PARKED VOTE: Low speed AND small displacement
if (speed <= 2.78 m/s && displacement <= dWindow) {
  if (duration >= tConfirm) {
    return SensorVote.parked;  // CONFIRMED
  }
  return SensorVote.parked;  // Honest reporting: stopped but not confirmed
}

// No more "unknown" votes - GPS always reflects current physical state
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

**Purpose:** Detect car audio disconnection (CarPlay, Bluetooth stereo)

**Data Source:**
- `audio_bluetooth_service.dart` (singleton)
- Polls `FlutterAudioOutput.getCurrentOutput()` every 2 seconds
- Detects when audio route changes from Bluetooth to other output

**Key State Tracking:**
```dart
bool _wasConnected = false;  // Tracks connection history
AudioInput? _currentRoute;   // Current audio output device
```

**Voting Logic:**

```dart
if (isConnected) {
  vote = SensorVote.driving;    // Connected to car audio = driving
  _wasConnected = true;         // Remember we were connected
} else if (_wasConnected) {
  vote = SensorVote.parked;     // Disconnected after connection = parked
} else {
  vote = SensorVote.unknown;    // No connection history
}
```

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

**Reset Behavior:**
```dart
void _onReset(ResetBluetooth event, Emitter<BluetoothState> emit) {
  _wasConnected = false;         // Clear connection history
  emit(BluetoothInitial());      // Reset to unknown vote
}
```

---

## State Machine: Detailed Transitions

### State 1: Unknown → Driving

**Location:** `parking_status_bloc.dart:173-183`

**Trigger:**
```dart
if (state is ParkingUnknown) {
  // Only GPS detection: speed > 10 km/h + distance > 10m for 3s
  if (gpsVote == SensorVote.driving) {
    return Driving(...);
  }
  // Stay in Unknown until GPS confirms driving
}
```

**Requirements:**
- GPS speed > 2.78 m/s (10 km/h) for ≥3 seconds
- AND linear distance > 10 meters

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

**Location:** `parking_status_bloc.dart:234-242`

```dart
if (hasBtDisconnect && (isLowSpeed || isStill)) {
  _cancelCandidateProgressTimer();
  return ParkingDetected(...);
}
```

**Requirements:**
- Bluetooth disconnected after being connected (`_wasConnected = true`)
- AND (GPS low speed OR Accelerometer still)

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
- GPS speed > 2.78 m/s (10 km/h) for ≥3s
- AND linear distance > 10m

**Scenario:** User stopped at red light, then continues driving

---

### State 4: ParkingDetected → Parked or Driving

**Location:** `main.dart:151-238`

When ParkingDetected is reached, a modal bottom sheet appears asking the user to confirm parking.

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

**Location:** `main.dart:165-210`

```dart
onConfirm: (selectedMinutes, selectedZone) {
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

**Location:** `main.dart:224-237`

```dart
.then((_) {
  if (!mounted) return;

  // Handle dismissal by swipe down
  if (parkingBloc.state is ParkingDetected) {
    // Only reset Bluetooth if it was the trigger
    final btVote = parkingBloc.state.sensorVotes['bluetooth'];
    if (btVote == SensorVote.parked) {
      bluetoothBloc.add(ResetBluetooth());
    }
    parkingBloc.add(RevertToDriving());
  }
}
```

**Behavior:** Same as Outcome B (treated as denial)

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
| **GPS**        | Speed > 10 km/h                           | Speed ≤ 10 km/h + low displacement          | Initialization only       |
| **Accelerometer** | RMS > 0.5 m/s²                          | RMS < 0.4 m/s² for 5s + quiet ratio > 70%  | Initial state             |
| **Gyroscope**  | Rotation ≤ 0.8 rad/s                      | Rotation > 0.8 rad/s (spike)                | -                         |
| **Bluetooth**  | Connected to car audio                    | Disconnected after connection               | No connection history     |

### State Transition Summary

| From State          | To State           | Trigger                                  | Requirements                                    |
|---------------------|--------------------|------------------------------------------|-------------------------------------------------|
| **Unknown**         | Driving            | GPS driving                              | Speed > 10 km/h + distance > 10m for 3s         |
| **Driving**         | StoppedCandidate   | GPS + Acc stopped                        | Both vote parked                                |
| **StoppedCandidate** | ParkingDetected   | Gyro spike                               | Rotation > 0.8 rad/s (instant)                  |
| **StoppedCandidate** | ParkingDetected   | Bluetooth disconnect                     | Disconnected + stopped (instant)                |
| **StoppedCandidate** | ParkingDetected   | Timeout                                  | 60 seconds + stopped                            |
| **StoppedCandidate** | Driving           | GPS driving                              | Speed > 10 km/h + distance > 10m for 3s         |
| **ParkingDetected**  | Parked            | User confirms                            | Slide-to-park gesture                           |
| **ParkingDetected**  | Driving           | User denies                              | Swipe down or cancel button                     |
| **Parked**          | Unknown            | Manual reset                             | ResetParking event                              |

### Promotion Path Comparison

| Path              | Trigger             | Requirements                          | Timing         | User Action              |
|-------------------|---------------------|---------------------------------------|----------------|--------------------------|
| Gyro Spike ⚡      | Rotation > 0.8 rad/s | Only in StoppedCandidate              | Instant        | Picking up phone         |
| BT Disconnect     | Bluetooth unpaired   | After connection + stopped            | Instant        | Exiting vehicle          |
| 60s Timeout       | Time elapsed         | 60 seconds + stopped                  | After 60s      | Phone left in car        |
| Revert to Driving | GPS driving          | Speed > 10 km/h + distance > 10m      | As soon as GPS confirms | Red light, not parked |

---

## Bug Fixes & Implementation Notes

### Bug Fix 1: Bluetooth Vote Not Updating After Reset

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

### Bug Fix 2: Unconditional Bluetooth Reset

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

### Bug Fix 3: GPS Double Filtering

**Issue:** Both `LocationCubit` and `GpsSpeedBloc` applied separate Kalman filters, causing slow response and redundant computation.

**Fix (2025-01-20):**
- `GpsSpeedBloc` now subscribes to `LocationCubit.stream` instead of raw GPS
- Uses pre-filtered coordinates to calculate speed
- Removed Kalman speed filter entirely
- Single filtering point: coordinates only

**Result:** Faster GPS speed response, cleaner architecture, eliminated redundancy.

---

### Bug Fix 4: GPS Unknown Votes During Driving

**Issue:** GPS voted "unknown" when speed was between 1.2-4.1 m/s (hysteresis gap), causing state machine confusion during slowdown.

**Fix (2025-01-20):**
- Unified `vIn` and `vOut` to 2.78 m/s (10 km/h)
- GPS always votes driving or parked based on actual state
- "Unknown" only used during initialization (first 2 samples)

**Result:** GPS sensor now honestly reports current state, no more ambiguous votes.

---

### Bug Fix 5: Bluetooth Not Detecting Existing Connections

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

- **GPS:** Dynamic - 0m distance filter during initialization (15s), then 1m filter
- **Accelerometer:** ~100 Hz (sensors_plus default)
- **Gyroscope:** ~100 Hz (sensors_plus default)
- **Bluetooth:** Polled every 2 seconds

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
