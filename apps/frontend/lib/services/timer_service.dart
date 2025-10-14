import 'dart:convert';
import 'package:http/http.dart' as http;

class TimerService {
  final String backendBaseUrl;

  TimerService({required this.backendBaseUrl});

  // Fetch the nearest restriction duration for a given location and start time
  Future<int?> fetchRestrictionDuration({
    required double lat,
    required double lng,
    required DateTime startTime,
  }) async {
    final url = Uri.parse(
      '$backendBaseUrl/api/map/restrictionduration'
      '?lat=$lat&lng=$lng&startTime=${startTime.toIso8601String()}',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      if (body == null) return null;
      return body['durationMinutes'] as int?;
    } else {
      // You can log errors here or throw if needed
      return null;
    }
  }
}