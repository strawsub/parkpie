import 'dart:convert';
import 'dart:math' show cos, sqrt, asin;
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

// Extension to TimerService for fetching nearby parking zones
extension NearbyZones on TimerService {
  // Fetch nearby parking zones within a certain radius
  // Uses the existing /api/map/getsignforpin endpoint and filters client-side
  Future<List<ParkingZone>> fetchNearbyParkingZones({
    required double lat,
    required double lng,
    double radiusMeters = 100.0, // Default 100m radius
    int maxResults = 5,
  }) async {
    final url = Uri.parse('$backendBaseUrl/api/map/getsignforpin');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is List) {
          // Parse all zones and calculate distances
          final allZones = body
              .map((zoneData) {
                try {
                  return ParkingZone.fromJson(zoneData, lat, lng);
                } catch (e) {
                  debugPrint('Error parsing zone: $e');
                  return null;
                }
              })
              .whereType<ParkingZone>()
              .toList();

          // Filter zones within radius
          final nearbyZones = allZones
              .where((zone) => zone.distanceMeters <= radiusMeters)
              .toList();

          // Sort by distance (closest first)
          nearbyZones.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

          // Limit results
          return nearbyZones.take(maxResults).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching nearby parking zones: $e');
      return [];
    }
  }
}

// Model class for parking zone with restrictions
class ParkingZone {
  final String zoneId;
  final String? zoneName;
  final int? zoneNumber;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final int? maximumStayMinutes;
  final String? startTime;
  final String? endTime;
  final double? occupancyPercent;
  final String? description;

  ParkingZone({
    required this.zoneId,
    this.zoneName,
    this.zoneNumber,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.maximumStayMinutes,
    this.startTime,
    this.endTime,
    this.occupancyPercent,
    this.description,
  });

  factory ParkingZone.fromJson(
    Map<String, dynamic> json,
    double userLat,
    double userLng,
  ) {
    final zoneLat = (json['lat'] as num).toDouble();
    final zoneLng = (json['lng'] as num).toDouble();
    final distance = _calculateDistance(userLat, userLng, zoneLat, zoneLng);

    // Helper to parse int values
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    // Helper to unwrap nested restriction data (handles PGobject format)
    dynamic unwrapRestrictions(dynamic raw) {
      if (raw == null) return null;

      // Handle Postgres PGobject-style payload {type: "json", value: "[...]"}
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        if (map.containsKey('value')) {
          final value = map['value'];
          if (value == null || (value is String && value.isEmpty)) {
            return null;
          }
          return unwrapRestrictions(value);
        }
      }

      if (raw is String) {
        try {
          return jsonDecode(raw);
        } catch (_) {
          return null;
        }
      }

      return raw;
    }

    // Try to extract restriction data from nested restrictions array
    int? maxStayMinutes = parseInt(json['maximum_stay_minutes']);
    String? startTimeStr = json['start_time']?.toString();
    String? endTimeStr = json['end_time']?.toString();

    // If no top-level restriction data, try to extract from restrictions array
    if (maxStayMinutes == null || maxStayMinutes <= 0) {
      final restrictionsRaw = unwrapRestrictions(json['restrictions']);
      if (restrictionsRaw is List && restrictionsRaw.isNotEmpty) {
        // Get current day of week (1=Monday, 7=Sunday)
        final currentDay = DateTime.now().weekday;

        // Try to find restriction for current day
        Map<String, dynamic>? currentRestriction;
        for (final r in restrictionsRaw) {
          if (r is Map<String, dynamic> && r['day_of_week'] == currentDay) {
            currentRestriction = r;
            break;
          }
        }

        // Fall back to first restriction if no current day match
        if (currentRestriction == null && restrictionsRaw.first is Map<String, dynamic>) {
          currentRestriction = restrictionsRaw.first as Map<String, dynamic>;
        }

        if (currentRestriction != null) {
          maxStayMinutes = parseInt(currentRestriction['maximum_stay_minutes']);
          startTimeStr ??= currentRestriction['start_time']?.toString();
          endTimeStr ??= currentRestriction['end_time']?.toString();
        }
      }
    }

    return ParkingZone(
      zoneId: json['id']?.toString() ?? json['zone_number']?.toString() ?? '',
      zoneName: json['zone_name']?.toString(),
      zoneNumber: parseInt(json['zone_number']),
      latitude: zoneLat,
      longitude: zoneLng,
      distanceMeters: distance,
      maximumStayMinutes: maxStayMinutes,
      startTime: startTimeStr,
      endTime: endTimeStr,
      occupancyPercent: (json['occupancy_percent'] as num?)?.toDouble(),
      description: json['description']?.toString(),
    );
  }

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)}m away';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)}km away';
    }
  }

  String get formattedTimeLimit {
    if (maximumStayMinutes == null || maximumStayMinutes! <= 0) {
      return 'No time limit';
    }
    final hours = maximumStayMinutes! ~/ 60;
    final mins = maximumStayMinutes! % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}min limit';
    } else if (hours > 0) {
      return '${hours}h limit';
    } else {
      return '${mins}min limit';
    }
  }

  String get formattedOccupancy {
    if (occupancyPercent == null) return 'Unknown';
    if (occupancyPercent! < 30) return 'Low';
    if (occupancyPercent! < 70) return 'Medium';
    return 'High';
  }

  // Calculate distance between two coordinates using Haversine formula
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // 2 * R * asin... (R = 6371 km in meters)
  }
}
