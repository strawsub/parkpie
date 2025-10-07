import 'package:shared_preferences/shared_preferences.dart';

class TimerStorage {
  static const String _keyStartTime = 'parking_timer_start_time';
  static const String _keyIsRunning = 'parking_timer_is_running';
  static const String _keyZoneNumber = 'parking_timer_zone_number';
  static const String _keyZoneName = 'parking_timer_zone_name';

  Future<void> saveStartTime(DateTime startTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStartTime, startTime.toIso8601String());
  }

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

  Future<void> saveIsRunning(bool isRunning) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsRunning, isRunning);
  }

  Future<bool> getIsRunning() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsRunning) ?? false;
  }

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

  Future<Map<String, dynamic>> getZoneInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'zoneNumber': prefs.getInt(_keyZoneNumber),
      'zoneName': prefs.getString(_keyZoneName),
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStartTime);
    await prefs.remove(_keyIsRunning);
    await prefs.remove(_keyZoneNumber);
    await prefs.remove(_keyZoneName);
  }
}
