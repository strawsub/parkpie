import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/http_client.dart';
import 'package:frontend/core/config.dart';
import 'repo.dart';
import 'models.dart';
import 'dart:io' show Platform;

final httpClientProvider = Provider<HttpClient>((ref) {
  final isAndroid = Platform.isAndroid; // emulator detection
  return HttpClient(AppConfig.baseUrl(isAndroid: isAndroid));
});

final repoProvider = Provider<SignRepository>((ref) {
  return SignRepository(ref.watch(httpClientProvider));
});

// Simple UI states
final healthProvider = FutureProvider<Health>((ref) {
  return ref.watch(repoProvider).health();
});

final postgisProvider = FutureProvider<String>((ref) {
  return ref.watch(repoProvider).postgisPointWkt();
});

final nearSignsProvider = FutureProvider.family<List<SignView>, ({double lat, double lng, double meters})>((ref, p) {
  return ref.watch(repoProvider).findNear(p.lat, p.lng, p.meters);
});

final createSignProvider = FutureProvider.family<SignView, SignCreateRequest>((ref, req) {
  return ref.watch(repoProvider).create(req);
});
