import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class SignIngestService {
  final String backendBaseUrl;

  SignIngestService({required this.backendBaseUrl});

  // System instruction used to force structured Gemini output
  static const String _systemInstruction = '''
You are extracting Australian parking sign restrictions exactly as written.
Respond with a single JSON object only. No markdown, prose, or extra keys.
JSON schema:
{
  "location": { "lat": number, "lng": number },
  "restrictions": [
    { "day_of_week": int (1..7), "start_time": "HH:mm", "end_time": "HH:mm", "maximum_stay_minutes": int|null }
  ]
}
Guidelines:
- Include the restrictions exactly as the sign states; omit days that are not listed.
- Multiple entries for the same day are allowed and should be ordered top-to-bottom from the sign.
- Use 24-hour "HH:mm" format; use "00:00" for midnight.
- If the stay duration is unlimited or not stated, set "maximum_stay_minutes" to null.
Return strict JSON only.
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
      Content.text(
        'sign_text:\n$signText\n\nlocation: {"lat": $lat, "lng": $lng}',
      ),
    ];
    final resp = await model.generateContent(content);
    var raw = resp.text ?? '';
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
    if (loc == null || rest == null || rest.isEmpty) {
      throw Exception(
        'Invalid payload: need location and at least one restriction',
      );
    }
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null ||
        lng == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      throw Exception('Invalid location');
    }
    final zone = data['zone_number'];
    if (zone != null) {
      if (zone is! int || zone >= 0) {
        throw Exception('zone_number must be a negative integer when provided');
      }
    }
    for (final entry in rest) {
      final m = entry as Map<String, dynamic>;
      final d = m['day_of_week'];
      final st = m['start_time'];
      final et = m['end_time'];
      final max = m['maximum_stay_minutes'];
      if (d is! int || d < 1 || d > 7) {
        throw Exception('Invalid day_of_week: $d');
      }
      if (st is! String || !_isValidTime(st)) {
        throw Exception('Invalid start_time for day $d');
      }
      if (et is! String || !_isValidTime(et)) {
        throw Exception('Invalid end_time for day $d');
      }
      if (max != null) {
        if (max is! int || max < 0) {
          throw Exception(
            'maximum_stay_minutes must be null or a non-negative integer',
          );
        }
      }
    }
  }

  Future<SignIngestResult> sendToBackend(Map<String, dynamic> body) async {
    final uri = Uri.parse('$backendBaseUrl/signs/ingest');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return SignIngestResult.fromJson(json);
      } catch (e) {
        throw Exception('Unexpected response: ${res.body}');
      }
    }
    throw Exception('Backend error ${res.statusCode}: ${res.body}');
  }

  Future<String> generateExplanation({
    required List<Map<String, dynamic>> restrictions,
    required double lat,
    required double lng,
    required String rawText,
    required String apiKey,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: apiKey,
      systemInstruction: Content.text(
        'You translate structured parking rules into a concise explanation for drivers.',
      ),
    );
    final prompt =
        '''
Sign location: ($lat, $lng)
Original extracted text:
$rawText

Structured restrictions (JSON array):
${jsonEncode(restrictions)}

Explain these rules in friendly Australian English (<=120 words). Mention day ranges and stay limits clearly.
''';
    final response = await model.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? '';
  }
}

class SignIngestResult {
  final int zoneNumber;
  final int restrictionsSaved;
  final int replacedPrevious;

  SignIngestResult({
    required this.zoneNumber,
    required this.restrictionsSaved,
    required this.replacedPrevious,
  });

  factory SignIngestResult.fromJson(Map<String, dynamic> json) {
    final zone = json['zone_number'] as num?;
    if (zone == null) {
      throw Exception('zone_number missing in response');
    }
    final saved = json['restrictions_saved'] as num? ?? 0;
    final replaced = json['replaced_previous'] as num? ?? 0;
    return SignIngestResult(
      zoneNumber: zone.toInt(),
      restrictionsSaved: saved.toInt(),
      replacedPrevious: replaced.toInt(),
    );
  }
}
