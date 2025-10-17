import 'dart:convert';

class Pin {
  final String? id;
  final double? lat;
  final double? lng;
  final double? occupancyPercent;
  final String? startTime;
  final String? endTime;
  final int? maximumStayMinutes;
  final String? description;
  final List<ParkingRestriction> restrictions;

  const Pin({
    required this.lat,
    required this.lng,
    this.id,
    this.occupancyPercent,
    this.startTime,
    this.endTime,
    this.maximumStayMinutes,
    this.description,
    this.restrictions = const [],
  });

  factory Pin.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    dynamic unwrapRestrictions(dynamic raw) {
      if (raw == null) return null;

      // Handle Postgres PGobject-style payload {type: "json", value: "[...]" }
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

    List<ParkingRestriction> parseRestrictions(dynamic raw) {
      final resolved = unwrapRestrictions(raw);
      if (resolved is! List) return const [];

      final topLevelOccupancy = parseDouble(json['occupancy_percent']);
      final parentId =
          json['id']?.toString() ?? json['zone_number']?.toString();
      final List<ParkingRestriction> parsed = [];

      for (final entry in resolved) {
        if (entry is! Map<String, dynamic>) continue;
        final merged = Map<String, dynamic>.from(entry);
        merged.putIfAbsent('id', () => parentId);
        if (merged['occupancy_percent'] == null && topLevelOccupancy != null) {
          merged['occupancy_percent'] = topLevelOccupancy;
        }
        parsed.add(ParkingRestriction.fromJson(merged));
      }

      return List.unmodifiable(parsed);
    }

    final restrictions = parseRestrictions(json['restrictions']);
    final firstRestriction = restrictions.isNotEmpty
        ? restrictions.first
        : null;
    final startTimeRaw = json['start_time'] ?? firstRestriction?.startTime;
    final endTimeRaw = json['end_time'] ?? firstRestriction?.endTime;
    final maxStayRaw =
        json['maximum_stay_minutes'] ?? firstRestriction?.maximumStayMinutes;

    return Pin(
      id: json['id']?.toString() ?? json['zone_number']?.toString(),
      lat: parseDouble(json['lat']),
      lng: parseDouble(json['lng']),
      occupancyPercent:
          parseDouble(json['occupancy_percent']) ??
          firstRestriction?.occupancyPercent,
      startTime: startTimeRaw?.toString(),
      endTime: endTimeRaw?.toString(),
      maximumStayMinutes: parseInt(maxStayRaw),
      description: json['description']?.toString(),
      restrictions: restrictions,
    );
  }
}

// New model for individual parking restrictions
class ParkingRestriction {
  final String? id;
  final int dayOfWeek; // 1-7 (1=Monday, 7=Sunday)
  final String startTime;
  final String endTime;
  final int maximumStayMinutes;
  final double? occupancyPercent;

  const ParkingRestriction({
    this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.maximumStayMinutes,
    this.occupancyPercent,
  });

  factory ParkingRestriction.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return ParkingRestriction(
      id: json['id']?.toString(),
      dayOfWeek: json['day_of_week'] ?? 1,
      startTime: json['start_time']?.toString() ?? '00:00:00',
      endTime: json['end_time']?.toString() ?? '23:59:59',
      maximumStayMinutes: json['maximum_stay_minutes'] ?? 0,
      occupancyPercent: parseDouble(json['occupancy_percent']),
    );
  }

  // Convert time string to DateTime for comparison
  DateTime get startDateTime {
    final now = DateTime.now();
    final parts = startTime.split(':');
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  DateTime get endDateTime {
    final now = DateTime.now();
    final parts = endTime.split(':');
    var endDate = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );

    // Handle overnight restrictions (end time is next day)
    if (endDate.isBefore(startDateTime)) {
      endDate = endDate.add(const Duration(days: 1));
    }
    return endDate;
  }

  // Check if current time falls within this restriction
  bool isCurrentlyActive() {
    final now = DateTime.now();
    final currentDayOfWeek =
        now.weekday; // DateTime.weekday: 1=Monday, 7=Sunday

    if (currentDayOfWeek != dayOfWeek) return false;

    final currentTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );

    // Handle normal time ranges (start < end)
    if (!endDateTime.isBefore(startDateTime)) {
      return currentTime.isAfter(startDateTime) &&
          currentTime.isBefore(endDateTime);
    }

    // Handle overnight ranges (end < start) - e.g., 10 PM to 6 AM
    return currentTime.isAfter(startDateTime) ||
        currentTime.isBefore(endDateTime);
  }

  // Format time for display (remove seconds)
  String get formattedStartTime {
    final parts = startTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  String get formattedEndTime {
    final parts = endTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }
}

// Enhanced model for location with multiple restrictions
class ParkingLocation {
  final double lat;
  final double lng;
  final String? description;
  final List<ParkingRestriction> restrictions;

  const ParkingLocation({
    required this.lat,
    required this.lng,
    this.description,
    required this.restrictions,
  });

  // Group restrictions by day of week
  Map<int, List<ParkingRestriction>> get restrictionsByDay {
    final Map<int, List<ParkingRestriction>> grouped = {};
    for (final restriction in restrictions) {
      grouped.putIfAbsent(restriction.dayOfWeek, () => []).add(restriction);
    }
    return grouped;
  }

  // Get current active restriction
  ParkingRestriction? get currentRestriction {
    try {
      return restrictions.firstWhere((r) => r.isCurrentlyActive());
    } catch (e) {
      return restrictions.isNotEmpty ? restrictions.first : null;
    }
  }

  // Get restrictions for a specific day
  List<ParkingRestriction> getRestrictionsForDay(int dayOfWeek) {
    return restrictions.where((r) => r.dayOfWeek == dayOfWeek).toList();
  }

  // Convert from Pin data (including multi-day restrictions) while preserving legacy fallbacks.
  factory ParkingLocation.fromPin(Pin pin) {
    final hasApiRestrictions = pin.restrictions.isNotEmpty;

    final List<ParkingRestriction> resolvedRestrictions = hasApiRestrictions
        ? pin.restrictions
        : [
            ParkingRestriction(
              id: pin.id,
              dayOfWeek: DateTime.now().weekday,
              startTime: pin.startTime ?? '00:00:00',
              endTime: pin.endTime ?? '23:59:59',
              maximumStayMinutes: pin.maximumStayMinutes ?? 0,
              occupancyPercent: pin.occupancyPercent,
            ),
          ];

    final enriched =
        resolvedRestrictions
            .map(
              (r) => ParkingRestriction(
                id: r.id,
                dayOfWeek: r.dayOfWeek,
                startTime: r.startTime,
                endTime: r.endTime,
                maximumStayMinutes: r.maximumStayMinutes,
                occupancyPercent: r.occupancyPercent ?? pin.occupancyPercent,
              ),
            )
            .toList()
          ..sort((a, b) {
            final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
            if (dayCompare != 0) return dayCompare;
            return a.startTime.compareTo(b.startTime);
          });

    return ParkingLocation(
      lat: pin.lat ?? 0,
      lng: pin.lng ?? 0,
      description: pin.description,
      restrictions: List.unmodifiable(enriched),
    );
  }
}
