class Pin {
  final dynamic kerbsideId;
  final double? lat;
  final double? lng;

  const Pin({required this.kerbsideId, required this.lat, required this.lng});

  factory Pin.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return Pin(
      kerbsideId: json['kerbsideid'],
      lat: parseDouble(json['lat']),
      lng: parseDouble(json['lng']),
    );
  }
}