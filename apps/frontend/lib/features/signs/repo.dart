import 'package:frontend/core/http_client.dart';
import 'models.dart';

class SignRepository {
  final HttpClient http;
  SignRepository(this.http);

  Future<Health> health() async => Health.fromJson(await http.getJson('/health'));

  Future<String> postgisPointWkt() async {
    final j = await http.getJson('/health/postgis');
    return j['point'] as String;
    // expected: "POINT(144.9631 -37.8136)"
  }

  Future<SignView> create(SignCreateRequest req) async =>
      SignView.fromJson(await http.postJson('/signs', req.toJson()));

  Future<List<SignView>> findNear(double lat, double lng, double meters) async {
    final list = await http.getJsonList('/signs/near?lat=$lat&lng=$lng&meters=$meters');
    return list.map((e) => SignView.fromJson(e as Map<String, dynamic>)).toList();
  }
}
