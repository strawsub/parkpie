import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpClient {
  final String baseUrl;
  HttpClient(this.baseUrl);

  Future<Map<String, dynamic>> getJson(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'));
    _check(res);
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getJsonList(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'));
    _check(res);
    return json.decode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    _check(res);
    return json.decode(res.body) as Map<String, dynamic>;
  }

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }
}
