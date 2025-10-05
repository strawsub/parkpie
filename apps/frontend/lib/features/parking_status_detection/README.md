⏺ Updated: Complete Parking Detection Logic (Current Implementation)

Changes: Removed 3-second gyro freeze mechanism. Gyro spike now triggers instant promotion to
ParkingDetected.

  ---
Overview: 5-State Machine with Sensor Fusion

┌─────────────┐
│   Unknown   │ ◄─── App starts here
└─────────────┘
│
│ GPS: speed ≥4.1m/s + distance >10m for 3s
▼
┌─────────────┐
│   Driving   │
└─────────────┘
│                    ▲
│ GPS parked         │ GPS: speed ≥4.1m/s
│ + Acc still        │ + distance >10m for 3s
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

  ---
Sensor Layer: 4 Independent Sensors

1. GPS Speed Sensor (gps_speed_bloc.dart)

Purpose: Detect driving via GPS speed + linear distance

Voting Logic:

// DRIVING VOTE: Requires BOTH speed ≥ 4.1 m/s AND distance > 10m for ≥3s
if (speed >= 4.1) {
_drivingCandidateStartTime ??= timestamp;
_drivingLinearDistance = haversineDistance(startSample, currentSample);

    if (duration >= 3.0s && _drivingLinearDistance > 10.0m) {
      return SensorVote.driving;
    }
    return SensorVote.unknown;
}

// PARKED VOTE: BOTH low speed AND small displacement (scenario-aware)
if (speed <= vIn && displacement <= dWindow) {
_parkedCandidateStartTime ??= timestamp;

    if (duration >= tConfirm) {
      return SensorVote.parked;
    }
    return SensorVote.unknown;
}

Key Thresholds:
- Driving: vOut = 4.1 m/s (~14.8 km/h), distance > 10m, time ≥ 3s
- Parked: vIn = 1.2-1.5 m/s (scenario), dWindow = 12-20m (scenario), time = 4-6s (scenario)

  ---
2. Accelerometer Sensor (acc_bloc.dart)

Purpose: Detect vehicle stillness via RMS magnitude

Voting Logic:

if (rms > 0.5) {
return SensorVote.driving;  // High motion
}

if (quietRatio >= 0.7 && rms < 0.4 && duration >= 5.0s) {
return SensorVote.parked;  // Still
}

return SensorVote.unknown;

Key Thresholds:
- Stillness: RMS ≤ 0.40 m/s² (enter), ≥ 0.45 m/s² (exit)
- Driving: RMS > 0.5 m/s²
- Time: 5 seconds of stillness required

  ---
3. Gyroscope Sensor (gyro_bloc.dart)

Purpose: Detect phone rotation spikes (user picking up phone)

Voting Logic:

final maxRotation = max(all magnitudes in 3s window);

if (maxRotation > 0.8) {
return SensorVote.parked;  // Spike detected
} else {
return SensorVote.driving;  // No spike
}

Key Threshold: >0.8 rad/s

Conditional Voting (parking_status_bloc.dart:123-134):
- Only active in StoppedCandidate state
- Ignored in all other states (prevents red-light false positives)

  ---
4. Bluetooth Sensor (bluetooth_bloc.dart)

Purpose: Detect car audio disconnect

Voting Logic:

if (isConnected) {
vote = SensorVote.driving;  // Connected to car audio
} else if (_wasConnected) {
vote = SensorVote.parked;  // Disconnected after connection
} else {
vote = SensorVote.unknown;  // No history
}

  ---
State Machine: Transitions & Logic

State 1: Unknown → Driving

Trigger (parking_status_bloc.dart:192-202):

if (state is ParkingUnknown) {
// Only GPS detection: speed ≥ 4.1 m/s AND distance > 10m for 3s
if (gpsVote == SensorVote.driving) {
return Driving(...);
}
}

Requirements:
- GPS speed ≥ 4.1 m/s for ≥3 seconds
- AND linear distance > 10 meters

No revert back to Unknown once Driving is reached.

  ---
State 2: Driving → StoppedCandidate

Trigger (parking_status_bloc.dart:207-218):

if (state is Driving) {
if (isStopped) {  // GPS parked AND Acc still
_startCandidateProgressTimer();  // 1.5s wall-clock timer
return StoppedCandidate(
candidateStartTime: now,
latchedGyroSpikeTime: null,  // No longer used
);
}
}

Requirements:
- GPS votes SensorVote.parked (speed ≤ 1.2-1.5 m/s for 4-6s)
- AND Accelerometer votes SensorVote.parked (RMS < 0.40 m/s² for 5s)

  ---
State 3: StoppedCandidate → ParkingDetected or Driving

3 Promotion Paths (Instant):

Path 1: Gyro Spike ⚡ NEW: INSTANT (parking_status_bloc.dart:256-265)

// 3. GYRO SPIKE LOGIC: Instant Promotion (no freeze window)
if (hasGyroSpike) {
_cancelCandidateProgressTimer();
return ParkingDetected(...);  // IMMEDIATE
}

Requirements:
- Gyroscope rotation > 0.8 rad/s

Timing: Instant (no 3s freeze delay)

  ---
Path 2: Bluetooth Disconnect (parking_status_bloc.dart:245-254)

if (hasBtDisconnect && (isLowSpeed || isStill)) {
_cancelCandidateProgressTimer();
return ParkingDetected(...);
}

Requirements:
- Bluetooth disconnected after being connected
- AND (GPS low speed OR Accelerometer still)

Timing: Instant

  ---
Path 3: 60-Second Timeout (parking_status_bloc.dart:267-278)

if (candidateDuration >= 60.0s && (isLowSpeed || isGpsStale)) {
_cancelCandidateProgressTimer();
return ParkingDetected(...);
}

Requirements:
- 60 seconds in StoppedCandidate
- AND (GPS still parked OR GPS stale)

Timing: After 60s

Purpose: Handle case where user parks but doesn't pick up phone

  ---
Revert to Driving (parking_status_bloc.dart:227-243)

if (gpsVote == SensorVote.driving) {
_cancelCandidateProgressTimer();
return Driving(...);
}

Requirements:
- GPS speed ≥ 4.1 m/s for ≥3s
- AND linear distance > 10m

  ---
State 4: ParkingDetected → Parked or Driving

Dialog (main.dart:147-180):
- Shows "Are you parked?" with Yes/No buttons
- Cannot dismiss by tapping outside or back button
- No auto-confirm timer - stays open until user acts

Outcome A: User Confirms "Yes" (parking_status_bloc.dart:441-451):
emit(Parked(...));  // Terminal state

Outcome B: User Clicks "No" (parking_status_bloc.dart:471-485):
emit(Driving(...));  // Revert to Driving without resetting sensors

Outcome C: Automatic Revert (parking_status_bloc.dart:317-333):
// If GPS detects driving motion while dialog is open
if (gpsVote == SensorVote.driving) {
return Driving(...);
}

  ---
State 5: Parked (Terminal)

Behavior (parking_status_bloc.dart:346-354):
// No automatic transitions out
// User must manually reset
return Parked(...);

Exit: Manual reset only (ResetParking event → ParkingUnknown)

  ---
Key Changes from Previous Version

❌ Removed: 3-Second Gyro Freeze Window

Old Logic:
// Spike detected → latch → wait 3s → promote
if (timeSinceSpike >= 3.0s) {
return ParkingDetected(...);
}

New Logic (parking_status_bloc.dart:256-265):
// Spike detected → immediate promotion
if (hasGyroSpike) {
return ParkingDetected(...);  // INSTANT
}

Impact:
- Faster parking detection when user picks up phone
- No more waiting period after rotation spike detected
- Simplified state machine (removed latchedGyroSpikeTime tracking)

  ---
Summary: Promotion Paths from StoppedCandidate

| Path              | Trigger             | Requirements                          | Timing
|
|-------------------|---------------------|---------------------------------------|-------------------------
|
| Gyro Spike ⚡      | Rotation >0.8 rad/s | Gyro active only in StoppedCandidate  | Instant ✨
|
| BT Disconnect     | Bluetooth unpaired  | After being connected + still stopped | Instant
|
| 60s Timeout       | Time elapsed        | Still stopped or GPS stale            | After 60s
|
| Revert to Driving | GPS driving         | Speed ≥4.1m/s + distance >10m for 3s  | As soon as GPS confirms
|

  ---
Complete State Flow

Unknown
├─ GPS driving (speed ≥4.1m/s + dist >10m for 3s) → Driving
└─ Stay in Unknown

Driving
├─ GPS parked + Acc still → StoppedCandidate
└─ Stay in Driving

StoppedCandidate
├─ Gyro spike (>0.8 rad/s) → ParkingDetected ⚡ INSTANT
├─ BT disconnect + stopped → ParkingDetected (instant)
├─ 60s timeout + stopped → ParkingDetected
├─ GPS driving → Driving (revert)
└─ Stay in StoppedCandidate

ParkingDetected
├─ User "Yes" → Parked
├─ User "No" → Driving
├─ GPS driving → Driving (auto-revert)
└─ Stay in ParkingDetected (dialog open)

Parked
└─ Manual reset only → Unknown