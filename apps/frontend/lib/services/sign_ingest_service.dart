import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class SignIngestService {
  final String backendBaseUrl;

  SignIngestService({required this.backendBaseUrl});

  // System instruction used to force strict JSON shape
  static const String _systemInstruction = '''
You are extracting Australian parking sign rules for 7 days (1=Mon … 7=Sun).
Output a single JSON object ONLY. No prose, no markdown, no extra keys.
JSON schema:
{
  "location": { "lat": number, "lng": number },
  "restrictions": [
    { "day_of_week": int, "start_time": "HH:mm", "end_time": "HH:mm", "maximum_stay_minutes": int },
    ... exactly 7 items, day_of_week must be 1..7 one each
  ]
}
If some days are missing in the sign, infer and replicate the nearest applicable day to fill all 1..7.
Times must be 24-hour "HH:mm". Use "00:00" if needed.
Ensure exactly 7 unique day_of_week values (1..7).
Respond with JSON only.
''';

  Future<Map<String, dynamic>> extractSignJson({
    required String signText,
    required double lat,
    required double lng,
    required String apiKey,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-pro-latest',
      apiKey: apiKey,
      systemInstruction: Content.text(_systemInstruction),
    );
    final content = [
      Content.text('sign_text:\n$signText\n\nlocation: {"lat": $lat, "lng": $lng}')
    ];
    final resp = await model.generateContent(content);
    var raw = resp.text ?? '';
    // Trim to JSON object in case of formatting noise
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) raw = raw.substring(start, end + 1);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return data;
  }

  bool _isValidTime(String s) => RegExp(r'^[0-2][0-9]:[0-5][0-9]$').hasMatch(s);

  void validatePayload(Map<String, dynamic> data) {
    final loc = data['location'] as Map<String, dynamic>?;
    final rest = data['restrictions'] as List<dynamic>?;
    if (loc == null || rest == null || rest.length != 7) {
      throw Exception('Invalid payload: need location and exactly 7 restrictions');
    }
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw Exception('Invalid location');
    }
    final seen = <int>{};
    for (final r in rest) {
      final m = r as Map<String, dynamic>;
      final d = m['day_of_week'];
      final st = m['start_time'];
      final et = m['end_time'];
      final max = m['maximum_stay_minutes'];
      if (d is! int || d < 1 || d > 7) throw Exception('Invalid day_of_week: $d');
      if (!seen.add(d)) throw Exception('Duplicate day_of_week: $d');
      if (st is! String || !_isValidTime(st)) throw Exception('Invalid start_time for day $d');
      if (et is! String || !_isValidTime(et)) throw Exception('Invalid end_time for day $d');
      if (max is! int || max < 0) throw Exception('Invalid maximum_stay_minutes for day $d');
    }
    if (seen.length != 7) throw Exception('Missing days 1..7');
  }

  Future<int> sendToBackend(Map<String, dynamic> body) async {
    final uri = Uri.parse('$backendBaseUrl/signs/ingest');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return int.tryParse(res.body.trim()) ?? 0;
    }
    throw Exception('Backend error ${res.statusCode}: ${res.body}');
  }
}

