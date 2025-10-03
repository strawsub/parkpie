import 'package:shared_preferences/shared_preferences.dart';

class SignZoneStorage {
  static const _prefix = 'sign_zone_';

  Future<int?> readZone(String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$fingerprint');
  }

  Future<void> writeZone(String fingerprint, int zoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$fingerprint', zoneNumber);
  }

  Future<void> removeZone(String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$fingerprint');
  }
}
