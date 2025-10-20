# State Machine Bug Fixes Required

## CRITICAL BUG: Race Condition in Dialog Dismiss Handler

**File:** `main.dart:225-238`

**Problem:** When user confirms parking, two events race:
1. `Navigator.pop()` → `.then()` callback → `RevertToDriving()`
2. `UserConfirmedParking()` event processing

The `.then()` callback fires when bottom sheet closes for ANY reason, including confirmation. If `UserConfirmedParking` hasn't been processed yet, state is still `ParkingDetected`, so `.then()` sends `RevertToDriving()` which overrides the parking confirmation.

**Fix:** Set a flag in `onConfirm` to prevent `.then()` from reverting:

```dart
bool _confirmedParking = false;

onConfirm: (...) {
  _isParkingDialogShowing = false;
  _confirmedParking = true;  // NEW FLAG
  Navigator.of(parentContext).pop();
  parkingBloc.add(const UserConfirmedParking());
  // ...rest of confirm logic
},

.then((_) {
  if (!mounted) return;
  _isParkingDialogShowing = false;

  // Only revert if NOT confirmed
  if (!_confirmedParking && parkingBloc.state is ParkingDetected) {
    // ...revert logic
  }
  _confirmedParking = false;  // Reset flag
});
```

---

## BUG: Bluetooth Status Not Showing After Reset

**File:** `bluetooth_bloc.dart:67-70`

**Problem:** After `ResetBluetooth`, audio service takes up to 1 second to poll and emit new status.

**Fix:** Immediately check audio route after reset:

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

---

## ENHANCEMENT: GPS Driving Detection Requirements

**File:** `gps_speed_config.dart:53-55, 64`

**Current:** 3 seconds, 10 meters
**Required:** 10 seconds, 20 meters

**Fix:**
```dart
this.tCandidateGood = 10.0,           // 10.0 seconds (was 3.0)
this.tCandidateMedium = 10.0,         // 10.0 seconds (was 3.0)
this.tCandidatePoor = 10.0,           // 10.0 seconds (was 3.0)
this.dDrivingThreshold = 20.0,        // 20.0 meters (was 10.0)
```

---

## LOGIC VERIFICATION: StoppedCandidate → Driving Revert

**Current logic is CORRECT:** Uses same GPS driving vote as Unknown → Driving.

Both require GPS to vote "driving", which happens when:
- Speed > 10 km/h (immediate)
- After confirmation: 10 seconds AND 20 meters (after fix above)

---

## TIMING: Bluetooth Disconnect Detection

**Current:** Polls every 1 second
**Delay:** Up to 1 second between physical disconnect and detection

This is acceptable for parking detection. No fix needed unless real-time detection required.

---

## VERIFICATION: Bluetooth Disconnect Trigger

**Current logic is CORRECT after previous fix:**
- Line 240: `if (hasBtDisconnect)` - no additional requirements
- Should trigger ParkingDetected when bluetooth disconnects in StoppedCandidate

If still not working, need to verify:
1. Audio service is detecting disconnect
2. Bluetooth vote is actually "parked"
3. No other code is resetting bluetooth before vote processed
