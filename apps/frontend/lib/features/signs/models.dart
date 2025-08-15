class Health {
  final bool ok;
  final String dbVersion;
  Health({required this.ok, required this.dbVersion});
  factory Health.fromJson(Map<String, dynamic> j) =>
      Health(ok: j['ok'] as bool, dbVersion: j['dbVersion'] as String);
}

class SignCreateRequest {
  final String text;
  final double lat;
  final double lng;
  SignCreateRequest({required this.text, required this.lat, required this.lng});
  Map<String, dynamic> toJson() => {'text': text, 'lat': lat, 'lng': lng};
}

class SignView {
  final int id;
  final String text;
  final double lat;
  final double lng;
  SignView({required this.id, required this.text, required this.lat, required this.lng});
  factory SignView.fromJson(Map<String, dynamic> j) => SignView(
    id: (j['id'] as num).toInt(),
    text: j['text'] as String,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
  );
}
