import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class TimerService {
  final String backendBaseUrl;

  TimerService({required this.backendBaseUrl});

  // Fetch the nearest restriction duration for a given location and start time
  Future<int?> fetchRestrictionDuration({
    required double lat,
    required double lng,
    required DateTime startTime,
    int? zoneNumber,
  }) async {
    final buffer = StringBuffer(
      '$backendBaseUrl/api/map/restrictionduration'
      '?lat=$lat&lng=$lng&startTime=${startTime.toIso8601String()}',
    );
    if (zoneNumber != null) {
      buffer.write('&zone=$zoneNumber');
    }

    final url = Uri.parse(buffer.toString());

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

  // Create a new parking session
  Future<ParkingSession?> createSession({
    required double lat,
    required double lng,
    required DateTime startTime,
  }) async {
    // Format time as HH:mm:ss
    final timeString =
        '${startTime.hour.toString().padLeft(2, '0')}:'
        '${startTime.minute.toString().padLeft(2, '0')}:'
        '${startTime.second.toString().padLeft(2, '0')}';

    final url = Uri.parse(
      '$backendBaseUrl/api/map/createsession'
      '?lat=$lat&lng=$lng&startTime=$timeString',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);

        if (body['created'] == true) {
          return ParkingSession(
            sessionId: body['session_id'] as int,
            parkingSignId: body['parking_sign_id'] as int?,
            latitude: body['lat'] as double,
            longitude: body['lng'] as double,
            startTime: body['start_time'] as String,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error creating session: $e');
      return null;
    }
  }

  // Delete a parking session by ID
  Future<bool> deleteSession({required int sessionId}) async {
    final url = Uri.parse(
      '$backendBaseUrl/api/map/deletesession?sessionID=$sessionId',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['deleted'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting session: $e');
      return false;
    }
  }
}

// Model class for parking session response
class ParkingSession {
  final int sessionId;
  final int? parkingSignId;
  final double latitude;
  final double longitude;
  final String startTime;

  ParkingSession({
    required this.sessionId,
    this.parkingSignId,
    required this.latitude,
    required this.longitude,
    required this.startTime,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'parkingSignId': parkingSignId,
    'latitude': latitude,
    'longitude': longitude,
    'startTime': startTime,
  };

  factory ParkingSession.fromJson(Map<String, dynamic> json) {
    return ParkingSession(
      sessionId: json['sessionId'] as int,
      parkingSignId: json['parkingSignId'] as int?,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      startTime: json['startTime'] as String,
    );
  }
}
