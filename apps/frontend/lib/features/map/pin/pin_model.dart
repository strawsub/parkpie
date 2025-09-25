class Pin {
  final String? id;
  final double? lat;
  final double? lng;
  final double? occupancyPercent;
  final String? startTime;
  final String? endTime;
  final int? maximumStayMinutes;
  final String? description;

  const Pin({
    required this.lat,
    required this.lng,
    this.id,
    this.occupancyPercent,
    this.startTime,
    this.endTime,
    this.maximumStayMinutes,
    this.description,
  });

  factory Pin.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return Pin(
      id: json['id']?.toString(),
      lat: parseDouble(json['lat']),
      lng: parseDouble(json['lng']),
      occupancyPercent: parseDouble(json['occupancy_percent']),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      maximumStayMinutes: json['maximum_stay_minutes'],
      description: json['description']?.toString(),
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
    return DateTime(now.year, now.month, now.day,
                    int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  DateTime get endDateTime {
    final now = DateTime.now();
    final parts = endTime.split(':');
    var endDate = DateTime(now.year, now.month, now.day,
                          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));

    // Handle overnight restrictions (end time is next day)
    if (endDate.isBefore(startDateTime)) {
      endDate = endDate.add(const Duration(days: 1));
    }
    return endDate;
  }

  // Check if current time falls within this restriction
  bool isCurrentlyActive() {
    final now = DateTime.now();
    final currentDayOfWeek = now.weekday; // DateTime.weekday: 1=Monday, 7=Sunday

    if (currentDayOfWeek != dayOfWeek) return false;

    final currentTime = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);

    // Handle normal time ranges (start < end)
    if (!endDateTime.isBefore(startDateTime)) {
      return currentTime.isAfter(startDateTime) && currentTime.isBefore(endDateTime);
    }

    // Handle overnight ranges (end < start) - e.g., 10 PM to 6 AM
    return currentTime.isAfter(startDateTime) || currentTime.isBefore(endDateTime);
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

  // Convert from current Pin format (temporary until backend is updated)
  factory ParkingLocation.fromPin(Pin pin) {
    final restriction = ParkingRestriction(
      id: pin.id,
      dayOfWeek: DateTime.now().weekday, // Current day as fallback
      startTime: pin.startTime ?? '00:00:00',
      endTime: pin.endTime ?? '23:59:59',
      maximumStayMinutes: pin.maximumStayMinutes ?? 0,
      occupancyPercent: pin.occupancyPercent,
    );

    return ParkingLocation(
      lat: pin.lat ?? 0,
      lng: pin.lng ?? 0,
      description: pin.description,
      restrictions: [restriction],
    );
  }
}
