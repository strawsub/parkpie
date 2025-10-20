import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
- If the sign applies every day (no specific days are written), generate seven entries covering days_of_week 1 through 7 with identical times.
Return strict JSON only.
''';

  Future<Map<String, dynamic>> extractSignJson({
    required String signText,
    required double lat,
    required double lng,
    required String apiKey,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
      systemInstruction: Content.text(_systemInstruction),
    );

    const maxRetries = 3;
    String? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final prompt = attempt == 1
            ? 'sign_text:\n$signText\n\nlocation: {"lat": $lat, "lng": $lng}'
            : '''
PREVIOUS ATTEMPT FAILED - STRICT JSON REQUIRED!

sign_text:
$signText

location: {"lat": $lat, "lng": $lng}

CRITICAL: You MUST respond with ONLY valid JSON matching the exact schema. No markdown, no prose, no extra text. Start with { and end with }. Previous error: $lastError

REQUIRED JSON FORMAT:
{"location": {"lat": $lat, "lng": $lng}, "restrictions": [{"day_of_week": 1, "start_time": "HH:mm", "end_time": "HH:mm", "maximum_stay_minutes": 120}]}

RULES:
- If the sign text applies every day (no days listed), generate seven entries with day_of_week 1..7 and identical times.''';

        final content = [Content.text(prompt)];
        final resp = await model.generateContent(content);
        var raw = resp.text ?? '';

        // Clean up response - extract JSON if wrapped in markdown or other text
        var jsonStr = raw.trim();
        if (jsonStr.contains('```')) {
          // Remove markdown code blocks
          jsonStr = jsonStr.replaceAll(RegExp(r'```(?:json)?'), '');
        }

        final start = jsonStr.indexOf('{');
        final end = jsonStr.lastIndexOf('}');
        if (start >= 0 && end > start) {
          jsonStr = jsonStr.substring(start, end + 1);
        }

        // Attempt to parse JSON
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;

        // Validate basic structure before returning
        _validateBasicJsonStructure(data);

        return data;
      } catch (e) {
        lastError = e.toString();
        if (attempt == maxRetries) {
          throw Exception(
            'Failed to extract valid JSON after $maxRetries attempts. Last error: $lastError',
          );
        }
        // Wait briefly before retry
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    throw Exception('Unexpected error in extractSignJson');
  }

  void _validateBasicJsonStructure(Map<String, dynamic> data) {
    // Quick validation before full validation - check essential structure
    if (!data.containsKey('location') || !data.containsKey('restrictions')) {
      throw Exception('Missing required fields: location or restrictions');
    }

    final location = data['location'];
    if (location is! Map<String, dynamic> ||
        !location.containsKey('lat') ||
        !location.containsKey('lng')) {
      throw Exception('Invalid location structure');
    }

    final restrictions = data['restrictions'];
    if (restrictions is! List || restrictions.isEmpty) {
      throw Exception(
        'Invalid restrictions structure - must be non-empty array',
      );
    }
  }

  bool _isValidTime(String s) =>
      RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(s);

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
    if (zone != null && (zone is! int || zone <= 0)) {
      throw Exception('zone_number must be a positive integer when provided');
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
    required String localeTag,
    required DateTime capturedAt,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
      systemInstruction: Content.text(
        'You translate structured parking rules into a concise explanation for drivers.',
      ),
    );
    final localDateTime = _formatLocalDateTime(localeTag, capturedAt);
    final weekdayEn = DateFormat('EEEE', 'en_US').format(capturedAt);
    final prompt =
        '''
Sign location: ($lat, $lng)
Original extracted text:
$rawText

Structured restrictions (JSON array):
${jsonEncode(restrictions)}

Current user locale: $localeTag
Current local date/time: ${capturedAt.toIso8601String()} (weekday: $weekdayEn, formatted: $localDateTime)

Explain these rules concisely in the user's language ($localeTag) and make them aware of the restrictions that apply at the current local time. Mention day ranges, stay limits, and highlight whether parking is currently allowed.
Keep the response under 130 words.
''';
    final response = await model.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? '';
  }

  String _formatLocalDateTime(String localeTag, DateTime dateTime) {
    try {
      final formatter = DateFormat.yMMMMEEEEd(localeTag).add_Hm();
      return formatter.format(dateTime);
    } catch (_) {
      final fallback = DateFormat('y-MM-dd HH:mm');
      return fallback.format(dateTime);
    }
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
