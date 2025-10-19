import 'package:shared_preferences/shared_preferences.dart';

class TimerStorage {
  static const String _keyStartTime = 'parking_timer_start_time';
  static const String _keyIsRunning = 'parking_timer_is_running';
  static const String _keyZoneNumber = 'parking_timer_zone_number';
  static const String _keyZoneName = 'parking_timer_zone_name';
  static const String _keyRestrictionDuration =
      'parking_timer_restriction_duration';
  static const String _keySessionId = 'parking_timer_session_id';

  // Save start time
  Future<void> saveStartTime(DateTime startTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStartTime, startTime.toIso8601String());
  }

  // Get start time
  Future<DateTime?> getStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString(_keyStartTime);
    if (timeString == null) return null;
    try {
      return DateTime.parse(timeString);
    } catch (_) {
      return null;
    }
  }

  // Save running state
  Future<void> saveIsRunning(bool isRunning) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsRunning, isRunning);
  }

  // Get running state
  Future<bool> getIsRunning() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsRunning) ?? false;
  }

  // Save zone info
  Future<void> saveZoneInfo(int? zoneNumber, String? zoneName) async {
    final prefs = await SharedPreferences.getInstance();
    if (zoneNumber != null) {
      await prefs.setInt(_keyZoneNumber, zoneNumber);
    } else {
      await prefs.remove(_keyZoneNumber);
    }
    if (zoneName != null) {
      await prefs.setString(_keyZoneName, zoneName);
    } else {
      await prefs.remove(_keyZoneName);
    }
  }

  // Get zone info
  Future<Map<String, dynamic>> getZoneInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'zoneNumber': prefs.getInt(_keyZoneNumber),
      'zoneName': prefs.getString(_keyZoneName),
    };
  }

  // Save restriction duration
  // Note: -1 is a valid value (indicates "no time limit")
  Future<void> saveRestrictionDuration(int? minutes) async {
    final prefs = await SharedPreferences.getInstance();
    if (minutes != null) {
      // Save any non-null value, including -1 (no time limit) and 0 (count-up)
      await prefs.setInt(_keyRestrictionDuration, minutes);
    } else {
      // Only remove if explicitly null
      await prefs.remove(_keyRestrictionDuration);
    }
  }

  // Get restriction duration
  Future<int?> getRestrictionDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyRestrictionDuration);
  }

  // Save session ID
  Future<void> saveSessionId(int sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySessionId, sessionId);
  }

  // Get session ID
  Future<int?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySessionId);
  }

  // Clear all stored data
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStartTime);
    await prefs.remove(_keyIsRunning);
    await prefs.remove(_keyZoneNumber);
    await prefs.remove(_keyZoneName);
    await prefs.remove(_keyRestrictionDuration);
    await prefs.remove(_keySessionId);
  }

  Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStartTime);
    await prefs.remove(_keyIsRunning);
    await prefs.remove(_keyRestrictionDuration);
    await prefs.remove(_keySessionId);
  }
}
