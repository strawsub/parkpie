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
