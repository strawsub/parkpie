# 📦 Where Timer Data is Saved

## The timer data is saved in SharedPreferences - a local key-value storage on the device. This is like a small database that survives app restarts.

### Location:

  - iOS: NSUserDefaults
  - Android: SharedPreferences (XML file in app's data directory)
  - File: lib/features/timer/timer_storage.dart

### What Gets Saved:

  // These 4 keys are stored:
  1. 'parking_timer_start_time'    → ISO 8601 timestamp (e.g., "2025-10-07T14:23:45.123Z")
  2. 'parking_timer_is_running'    → boolean (true/false)
  3. 'parking_timer_zone_number'   → int (e.g., -9999)
  4. 'parking_timer_zone_name'     → string (e.g., "Test Zone - 2P")

  ---
## ⚙️ How It Works

### When You Start the Timer:

  1. Saves DateTime.now() to parking_timer_start_time
  2. Saves true to parking_timer_is_running
  3. Saves zone info (if provided)

  // From timer_bloc.dart:162-164
  await _storage.saveStartTime(startTime);
  await _storage.saveIsRunning(true);
  await _storage.saveZoneInfo(event.zoneNumber, event.zoneName);

### When App Reopens:

  1. TimerBloc is created in main.dart:64
  2. Automatically loads saved data via LoadTimer event
  3. Calculates elapsed time from saved start time:

### // From timer_bloc.dart:38-41
  final startTime = await _storage.getStartTime();
  final elapsed = DateTime.now().difference(startTime);

  4. Timer continues counting from where it left off! ✅

  ---
# 🔄 Timer States & Persistence

  | State       | What's Saved           | What Happens on App Restart                 |
  |-------------|------------------------|---------------------------------------------|
  | Not Started | Nothing                | Shows initial screen                        |
  | Running     | Start time + zone info | Calculates elapsed time and continues       |
  | Stopped     | Clears is_running flag | Shows last elapsed time (but doesn't count) |
  | Reset       | Clears everything      | Back to initial state                       |

  ---
# 🧪 Test It Yourself:

  1. Start timer with test zone
  2. Note the time (e.g., 00:15)
  3. Close the app completely (swipe it away)
  4. Wait 30 seconds
  5. Reopen the app
  6. Result: Timer should show ~00:45 (15s + 30s) ✅

  ---
# 📍 Code References

  Storage Implementation:
  - lib/features/timer/timer_storage.dart - All save/load logic

  Timer Persistence:
  - lib/features/timer/timer_bloc.dart:27-52 - _onLoadTimer() method
  - lib/main.dart:64 - Timer initialization with LoadTimer event

  What Makes It Work:
  // main.dart:64
  BlocProvider(create: (_) => TimerBloc()..add(const LoadTimer())),

  The ..add(const LoadTimer()) runs immediately when the app starts, loading any saved timer state!

  ---
 Even if you:
  - ✅ Close the app
  - ✅ Restart your phone
  - ✅ Kill the app from task manager

  The timer will continue counting correctly when you reopen it!