1. APP START / INITIALIZATION

State: ParkingUnknown

Entry Condition:
- App just launched
- Default initial state

Exit Conditions:
- To Driving: ≥2 driving votes OR GPS vote = driving
- No other exits (can't go directly to parked)

  ---
2. DRIVING SCENARIO

State: Driving (Orange indicator 🟠)

Entry Conditions:

- From Unknown: ≥2 driving votes OR GPS = driving
- From StoppedCandidate: Sustained motion detected (revert conditions met)
- From ParkingDetected: Sustained motion detected
- From Parked: ≥2 driving votes OR GPS = driving

Detection Logic:

- GPS speed vote = driving (v ≥ vOut = 2.5 m/s for 3s)
- OR accelerometer vote = driving (RMS > 0.10)
- OR gyroscope vote = driving (low rotation, stable)
- OR bluetooth connected (car audio active)

Exit Conditions:

- To StoppedCandidate (Normal): GPS low speed (v ≤ 1.2 m/s) AND Acc stillness (RMS ≤ 0.07) for 3s
- To ParkingDetected (BT Fast Path): Stopped + BT disconnects (within 2s of prior connection)

Key Behavior:

- Gyro spikes IGNORED in Driving state (prevents red light false positives)

  ---
3. STOPPED CANDIDATE SCENARIO

State: StoppedCandidate (Yellow indicator 🟡)

Entry Conditions:

- From Driving:
    - GPS vote = parked (v ≤ vIn for 3s)
    - AND Acc vote = parked (RMS ≤ 0.07, quiet ratio ≥ 70% for 3s)
    - AND no BT disconnect (otherwise goes direct to ParkingDetected)

Active Detection Logic:

A. Revert to Driving (Exit to Driving):

GPS Available:
- GPS speed ≥ 2.5 m/s (vOut) for 3s sustained ✅
- OR Acc RMS > 0.10 for 4s sustained ✅

GPS Stale (indoors/tunnels):
- Ignore GPS and gyro completely
- Acc RMS > 0.10 for 4s sustained ✅ (acc-only revert)

B. BT Disconnect Promotion (Exit to ParkingDetected):

- BT was previously connected AND now disconnected
- Stopped condition active (GPS low speed OR Acc stillness)
- Within 2s of disconnect timestamp
- Result: Instant promotion to ParkingDetected ⚡

C. Gyro Spike Evidence Collection:

Phase 1: Spike Detection & Latching
- Gyro spike detected (rotation > threshold)
- Spike latched with timestamp
- Only valid if detected AFTER entering StoppedCandidate

Phase 2: Freeze Window (0-3s after spike)
- Purpose: Ignore acc spike from grabbing phone
- Duration: 3 seconds
- Action: Just wait, no checks

Phase 3: Recovery Window (3-12s after spike)
- Purpose: Check if phone returns to stillness
- Success condition: Acc still (RMS ≤ 0.07) AND Acc vote = parked
- If success: Mark recovery timestamp, start Hold timer
- If fail (>12s): Clear latched spike, stay in Candidate

Phase 4: Hold Window (after recovery, 30s duration)
- Purpose: Verify sustained stillness
- Requirements:
    - Acc RMS ≤ 0.07 continuously
    - GPS low speed (v ≤ vIn) OR GPS stale with IMU confirmation
    - Displacement ≤ dWindow
- If break: Reset hold timer (don't revert, just restart hold)
- If complete: Promote to ParkingDetected ✅

Phase 5: Spike Expiry
- Spike expires after 25s from latch
- If expired: Clear spike + recovery + hold timers

D. Timeout Promotion (Exit to ParkingDetected):

- After 60s in StoppedCandidate with no motion
- Auto-promote to ParkingDetected
- User will see confirmation dialog

Periodic Timer:

- 1.5s wall-clock tick keeps timers advancing
- Works even when GPS samples stale
- Re-evaluates state every tick

  ---
4. PARKING DETECTED SCENARIO

State: ParkingDetected (Purple indicator 🟣)

Entry Conditions:

- From Driving (BT Fast Path): BT disconnect while stopped
- From StoppedCandidate (BT): BT disconnect within 2s
- From StoppedCandidate (Gyro): Hold window completed (30s after recovery)
- From StoppedCandidate (Timeout): 60s with no motion

Detection Logic:

- Evidence collected in StoppedCandidate validates parking
- Auto-confirm timer starts (3 seconds)

Exit Conditions:

- To Parked: Auto-confirm timer completes (3s) → Show dialog → Parked
- To Driving: Sustained motion detected (same revert logic as StoppedCandidate)

User Interaction:

- Dialog shown: "Are you parked?"
- User confirms → Parked state
- User rejects → ResetParking → Unknown → Driving

  ---
5. PARKED SCENARIO

State: Parked (Green indicator 🟢)

Entry Conditions:

- From ParkingDetected: Auto-confirm (3s) OR user confirmation

Detection Logic:

- Vehicle is stationary
- User confirmed parking

Exit Conditions:

- To Driving: ≥2 driving votes OR GPS vote = driving

  ---
SPECIAL SCENARIOS

Red Light Detection (Prevents False Positive):

Timeline:
t=0s:   Vehicle stops at red light
→ Enter StoppedCandidate

t=5s:   User picks up phone (checking map)
→ Gyro spike detected & latched

t=5-8s: Freeze window (ignore acc spike)

t=8s:   User holding phone, moving slightly
→ Acc RMS = 0.09-0.12 (> 0.07 threshold)
→ Quiet ratio = 55% (< 70% threshold)
→ Status: MOVING ❌

t=8-17s: User continues using phone
→ Still moving, RMS > 0.07
→ Recovery FAILS at t=17s (12s deadline)
→ Spike cleared

t=30s:  Light turns green
→ v ≥ 2.5 m/s for 3s
→ Revert to Driving ✅

Result: NO parking detected (correct behavior)

Indoor Parking / GPS Loss:

Timeline:
t=0s:   Enter underground parking
→ StoppedCandidate

t=10s:  GPS stops updating (stale)
→ GPS-stale mode activated
→ Ignore gyro completely
→ Use acc-only revert logic

t=15s:  User picks up phone to exit
→ Gyro spike latched

t=15-18s: Freeze

t=20s:  Phone in pocket, acc still
→ Recovery success

t=20-50s: Hold window (30s)
→ Wall-clock 1.5s timer advances hold
→ IMU confirms stillness (GPS ignored)

t=50s:  Hold complete
→ ParkingDetected → Parked ✅

Result: Parking detected using wall-clock + IMU

BT Disconnect (Instant Detection):

Timeline:
t=0s:   Vehicle stops, engine still on
→ StoppedCandidate
→ BT connected to car audio

t=3s:   User turns off engine
→ BT disconnects from car

t=3.1s: BT disconnect detected
→ Stopped condition active (v=0, RMS=0.03)
→ Within 2s of disconnect
→ INSTANT promotion to ParkingDetected ⚡

t=6s:   Auto-confirm (3s)
→ Show dialog → Parked ✅

Result: Fast parking detection (6s total)

Long Red Light (>60s with Timeout):

Timeline:
t=0s:   Stop at red light
→ StoppedCandidate

t=0-60s: No phone pickup, no BT disconnect
→ No evidence collected
→ Waiting...

t=60s:  Timeout reached
→ Auto-promote to ParkingDetected

t=63s:  Auto-confirm (3s)
→ Dialog: "Are you parked?"
→ User clicks "No"
→ ResetParking() called
→ Return to Unknown

t=64s:  Detect driving
→ Driving state ✅

Result: User override prevents false positive

  ---
SENSOR COORDINATION

4 Active Sensors:
1. GPS Speed - Primary speed detection (v ≤ 1.2 in, v ≥ 2.5 out)
2. Accelerometer - Stillness detection (RMS ≤ 0.07 in, > 0.10 out, quiet ratio ≥ 70%)
3. Gyroscope - Phone pickup detection (rotation > threshold, conditional voting)
4. Bluetooth - Engine off detection (disconnect = instant parking)

Voting System:
- Each sensor votes: driving / parked / unknown
- Gyro votes ONLY count in StoppedCandidate or later (conditional)
- ≥2 driving votes → Driving (with hysteresis)
- Stopped requires GPS + Acc agreement

Evidence Hierarchy:
1. 🔴 BT Disconnect (Strongest) - Instant promotion
2. 🟡 Gyro + Hold (Medium) - 45s minimum (freeze + recovery + hold)
3. ⚪ 60s Timeout (Weakest) - Requires user confirmation

Complete Parking Detection Logic (Corrected)

State Transitions

1. ParkingUnknown → Driving

Entry Conditions:
- App just launched (default initial state)

Exit Conditions:
- To Driving: ≥2 driving votes OR GPS vote = driving
- No other exits (can't go directly to parked)

  ---
2. Driving → StoppedCandidate

Entry Condition: isStopped = true

Where isStopped = isLowSpeed && isStill:
- GPS vote = parked (v ≤ vIn for 3s) AND
- Acc vote = parked (RMS ≤ 0.07, quiet ratio ≥ 70% for 3s)

Both conditions required - this is stricter than just ≥2 votes.

Code:
final isLowSpeed = gpsVote == SensorVote.parked;
final isStill = accVote == SensorVote.parked;
final isStopped = isLowSpeed && isStill;  // BOTH required

if (state is Driving) {
if (isStopped) {
_startCandidateProgressTimer();
return StoppedCandidate(...);
}
}

What Happens on Entry:
- Start 60-second candidate timer
- Latch gyro spike immediately if present
- Store candidateStartTime

  ---
3. StoppedCandidate → Driving (Revert)

Revert to Driving requires sustained evidence (hysteresis protection):

GPS Available:

- GPS speed ≥ 2.5 m/s (vOut) for 3s sustained ✅
- OR Acc RMS > 0.10 for 4s sustained ✅

GPS Stale (indoors/tunnels):

- Ignore GPS and gyro completely
- Acc RMS > 0.10 for 4s sustained ✅ (acc-only revert)

Code:
bool _checkRevertConditions(...) {
// When GPS is stale, ignore gyro and use acc-only revert logic
if (isGpsStale) {
if (currentAccRMS > 0.10) {
_clearMotionStartTime ??= now;
final motionDuration = now.difference(_clearMotionStartTime!);
if (motionDuration >= _sustainedMotionDuration) {  // 4s
return true; // REVERT based on acc alone
}
}
return false;
}

    // GPS is fresh: check for sustained high speed (v >= vOut for 3s)
    if (gpsVote == SensorVote.driving) {
      _highSpeedStartTime ??= now;
      final highSpeedDuration = now.difference(_highSpeedStartTime!);
      if (highSpeedDuration >= _sustainedHighSpeedDuration) {  // 3s
        return true; // REVERT
      }
    }

    // Check for sustained clear motion (acc RMS > 0.10 for 4s)
    if (currentAccRMS > 0.10) {
      _clearMotionStartTime ??= now;
      final motionDuration = now.difference(_clearMotionStartTime!);
      if (motionDuration >= _sustainedMotionDuration) {  // 4s
        return true; // REVERT
      }
    }

    return false;
}

Timing Constants:
- _sustainedHighSpeedDuration = 3 seconds (GPS speed revert)
- _sustainedMotionDuration = 4 seconds (Acc RMS revert)

  ---
4. StoppedCandidate → ParkingDetected (Promotion)

Three Paths:

1. Gyro Spike + 3s Freeze → ParkingDetected
2. Bluetooth Disconnect (instant, if isLowSpeed || isStill) → ParkingDetected
3. 60s Timeout (fallback, if isLowSpeed || isGpsStale) → ParkingDetected

  ---
5. ParkingDetected → Parked

Dialog Behavior:
- "Yes" → Parked
- "No" → Driving (not Unknown)
- Dismissed without button → auto-confirm Parked

  ---
6. Parked (Terminal State)

No automatic transitions out.

  ---
Summary of Key Logic

Entry to StoppedCandidate:

isStopped = (GPS vote = parked) AND (Acc vote = parked)
= (v ≤ vIn for 3s) AND (RMS ≤ 0.07, quiet ≥ 70% for 3s)

Revert to Driving:

GPS Available:
- GPS ≥ 2.5 m/s for 3s OR Acc RMS > 0.10 for 4s

GPS Stale:
- Acc RMS > 0.10 for 4s (ignore GPS and gyro)

Promotion to ParkingDetected:

1. Gyro spike + 3s freeze
2. BT disconnect (instant)
3. 60s timeout
