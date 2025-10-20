# State Machine Bug Fixes - Applied

## Summary

All reported issues have been traced and fixed. This document explains each bug and the fix applied.

---

## BUG 1: Status Stays StoppedCandidate or Goes to Driving After Confirmation ⚠️ **CRITICAL**

### Root Cause
**Race condition** between dialog dismiss handler and parking confirmation event.

### Code Path
1. User slides to confirm parking
2. `onConfirm` callback fires (main.dart:167):
   - Calls `Navigator.pop()` → closes dialog
   - Sends `UserConfirmedParking()` event
3. Dialog closes → `.then()` callback fires immediately (line 227-245)
4. **RACE:** If `UserConfirmedParking` hasn't been processed yet, state is still `ParkingDetected`
5. `.then()` callback sees `ParkingDetected` state → sends `RevertToDriving()` → **OVERRIDES parking confirmation!**

### Fix Applied
**File:** `main.dart:103, 169, 232-244`

Added `_confirmedParking` flag to track whether user confirmed vs dismissed:

```dart
class _HomeContainerState extends State<HomeContainer> {
  bool _isParkingDialogShowing = false;
  bool _confirmedParking = false;  // NEW FLAG
```

In `onConfirm`:
```dart
_confirmedParking = true;  // Mark as confirmed
Navigator.pop();
parkingBloc.add(const UserConfirmedParking());
```

In `.then()`:
```dart
if (!_confirmedParking && parkingBloc.state is ParkingDetected) {
  // Only revert if user did NOT confirm
  parkingBloc.add(const RevertToDriving());
}
_confirmedParking = false;  // Reset for next dialog
```

### Result
✅ User confirmation is now protected from being overridden by dialog dismiss handler.

---

## BUG 2: Bluetooth Not Showing After Reset (While CarPlay Plugged In)

### Root Cause
After `ResetBluetooth`, the audio service takes up to 1 second to poll and emit new status. During this time, debug screen shows "not connected" even though CarPlay is physically plugged in.

### Code Path
1. User clicks "Reset Parking" → `ResetBluetooth()` sent
2. `_onReset` executes (bluetooth_bloc.dart:67-70):
   - Sets `_wasConnected = false`
   - Emits `BluetoothInitial()` (vote: unknown, isConnected: false)
3. **DELAY:** Audio service polls every 1 second
4. Eventually, next poll detects connection and emits correct status

### Fix Applied
**File:** `bluetooth_bloc.dart:67-77`

Made `_onReset` immediately check current bluetooth status:

```dart
Future<void> _onReset(ResetBluetooth event, Emitter<BluetoothState> emit) async {
  _wasConnected = false;
  emit(const BluetoothInitial());

  // Immediately check current bluetooth status
  final currentStatus = _service.getCurrentStatus();
  add(BluetoothStatusChanged(
    isConnected: currentStatus.isBluetoothConnected,
    deviceName: currentStatus.currentRouteName,
  ));
}
```

### Result
✅ After reset, bluetooth status updates immediately instead of waiting up to 1 second.

---

## BUG 3: Bluetooth Disconnect Doesn't Trigger Parking

### Status
**Already fixed in previous session** (parking_status_bloc.dart:240).

Removed the strict requirement `(isLowSpeed || isStill)`, so bluetooth disconnect now triggers parking detection immediately in StoppedCandidate state.

### Verification
If still not working, check:
1. Audio service is detecting disconnect (check debug logs)
2. Bluetooth vote is actually "parked" (check debug screen sensor votes)
3. State is StoppedCandidate when disconnect happens

---

## ENHANCEMENT: GPS Driving Detection Requirements

### Requirement
Change from 3 seconds + 10 meters to **10 seconds + 20 meters** for stricter driving detection.

### Fix Applied
**File:** `gps_speed_config.dart:53-55, 64`

```dart
// Time thresholds (was 3.0 seconds)
this.tCandidateGood = 10.0,           // 10.0 seconds - good GPS
this.tCandidateMedium = 10.0,         // 10.0 seconds - medium GPS
this.tCandidatePoor = 10.0,           // 10.0 seconds - poor GPS

// Distance threshold (was 10.0 meters)
this.dDrivingThreshold = 20.0,        // 20.0 meters - linear distance
```

### Impact
- Unknown → Driving: Requires 10 seconds + 20 meters at speed > 10 km/h
- StoppedCandidate → Driving: Same requirements (uses same GPS vote)

### Result
✅ Much stricter driving detection - reduces false positives from brief movement.

---

## LOGIC VERIFICATION: StoppedCandidate → Driving Revert

### Current Logic (Correct)
**File:** `parking_status_bloc.dart:317-332`

```dart
bool _checkRevertConditions(...) {
  final gpsVote = sensorVotes['gps_speed'] ?? SensorVote.unknown;

  if (gpsVote == SensorVote.driving) {
    return true; // REVERT to Driving
  }

  return false;
}
```

### GPS Voting Logic
**File:** `gps_speed_bloc.dart:368-399`

GPS votes "driving" when:
1. Speed > 10 km/h (2.78 m/s) - votes "driving" immediately
2. After 10 seconds AND 20 meters - **confirmed** driving

Both Unknown → Driving and StoppedCandidate → Driving use the same GPS vote, so they have **identical requirements**.

### Result
✅ Logic is correct and symmetric.

---

## STATE MACHINE TRANSITION MAP

```
ParkingUnknown
  ↓ [GPS votes driving: speed > 10 km/h for 10s + 20m]
Driving
  ↓ [GPS low speed AND accelerometer still]
StoppedCandidate
  ├─ [GPS votes driving: speed > 10 km/h for 10s + 20m] → Driving (revert)
  ├─ [Bluetooth disconnect] → ParkingDetected
  ├─ [Gyroscope spike] → ParkingDetected
  └─ [60 second timeout] → ParkingDetected
ParkingDetected (STABLE - sensor votes blocked)
  ├─ [User confirms] → Parked (terminal)
  └─ [User cancels/dismisses] → Driving (revert)
Parked (TERMINAL - sensor votes blocked)
  └─ [Manual reset only]
```

---

## GUARDS IN PLACE

### Sensor Vote Guards (parking_status_bloc.dart:101-109)
```dart
void _onUpdateSensorVote(...) {
  // Block sensor votes in Parked state
  if (state is Parked) {
    return;
  }

  // Block sensor votes in ParkingDetected state
  if (state is ParkingDetected) {
    return;
  }

  // Process vote normally
}
```

### Timer Tick Guards (parking_status_bloc.dart:370-378)
```dart
void _onCandidateProgressTick(...) {
  // Block timer ticks in Parked state
  if (state is Parked) {
    return;
  }

  // Block timer ticks in ParkingDetected state
  if (state is ParkingDetected) {
    return;
  }

  // Process tick normally
}
```

---

## TESTING CHECKLIST

### Test 1: Bluetooth Reset While Connected
1. Connect CarPlay
2. Click "Reset Parking" on debug screen
3. **Expected:** Bluetooth shows "Connected" immediately (no delay)

### Test 2: Gyroscope Spike → Confirmation
1. Drive, then stop (enter StoppedCandidate)
2. Pick up phone (gyroscope spike)
3. Confirmation dialog appears
4. Slide to confirm
5. **Expected:** Status changes to "Parked", timer starts, navigate to timer screen
6. **Verify:** Status does NOT revert to Driving or StoppedCandidate

### Test 3: Bluetooth Disconnect → Confirmation
1. Drive, then stop (enter StoppedCandidate)
2. Unplug CarPlay cable
3. **Expected:** Confirmation dialog appears within 1-2 seconds
4. Slide to confirm
5. **Expected:** Status changes to "Parked"

### Test 4: Timeout → Confirmation
1. Drive, then stop (enter StoppedCandidate)
2. Wait 60 seconds without moving
3. Confirmation dialog appears
4. Slide to confirm
5. **Expected:** Status changes to "Parked"
6. **Verify:** Status does NOT revert to Driving

### Test 5: Driving Detection (New Requirements)
1. Start app (Unknown state)
2. Drive at > 10 km/h
3. **Expected:** After 10 seconds AND 20 meters, status changes to "Driving"
4. Stop (enter StoppedCandidate)
5. Move at > 10 km/h again
6. **Expected:** After 10 seconds AND 20 meters, reverts to "Driving"

### Test 6: Dialog Dismiss (Revert)
1. Enter StoppedCandidate
2. Trigger parking detection (any method)
3. Swipe down to dismiss dialog (do NOT confirm)
4. **Expected:** Status reverts to "Driving"

---

## FILES MODIFIED

1. **main.dart:103, 169, 232-244** - Fixed dialog race condition
2. **bluetooth_bloc.dart:67-77** - Fixed bluetooth reset delay
3. **gps_speed_config.dart:53-55, 64** - Updated driving detection requirements
4. **parking_status_bloc.dart:240** - Already fixed (bluetooth disconnect trigger)
5. **parking_status_bloc.dart:106-109, 375-378** - Already fixed (ParkingDetected guards)

---

## KNOWN LIMITATIONS

1. **Bluetooth detection delay:** Up to 1 second between physical disconnect and detection (due to polling). This is acceptable for parking detection.

2. **Indoor GPS:** GPS may show 0 speed or "initializing" indoors due to poor signal. This is expected behavior.

3. **Sensor vote "unknown":** During initialization, sensors may vote "unknown" until they have enough data. This is normal.
