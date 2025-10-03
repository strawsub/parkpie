// pin_cubit.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'pin_state.dart';
import 'pin_model.dart';
import 'package:frontend/services/api_config.dart';

class PinCubit extends Cubit<PinState> {
  PinCubit() : super(PinInitial());

  /// Resolve API base
  String _apiBase() {
    return resolveApiBaseUrl();
  }
  // String _apiBase() {
  //   const fromEnv = String.fromEnvironment('API_BASE_URL');
  //   if (fromEnv.isNotEmpty) return fromEnv;
  //   if (kIsWeb) return 'http://localhost:8081';
  //   if (defaultTargetPlatform == TargetPlatform.android) {
  //     return 'http://192.168.18.12:8081'; // FOR TESTING ON SAME WLAN
  //   }
  //   return 'http://localhost:8081';
  // }

  // ---------- Cache helpers ----------
  Future<File?> _cacheFile() async {
    if (kIsWeb) return null; // no file cache on web
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/pins_cache.json');
  }

  Future<void> _saveCacheString(String json) async {
    final file = await _cacheFile();
    if (file == null) return;
    await file.writeAsString(json);
  }

  Future<List<Map<String, dynamic>>?> _readCache() async {
    try {
      final file = await _cacheFile();
      if (file == null || !await file.exists()) return null;
      final txt = await file.readAsString();
      final decoded = jsonDecode(txt);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> _cacheLastModified() async {
    final file = await _cacheFile();
    if (file == null || !await file.exists()) return null;
    return file.lastModified();
  }

  List<Pin> _pinsFromJsonList(List<Map<String, dynamic>> list) {
    return list
        .map((e) => Pin.fromJson(e))
        .where((p) => p.lat != null && p.lng != null)
        .toList();
  }
  // --------------------------------

  Future<void> loadPins({Duration ttl = const Duration(minutes: 5)}) async {
    emit(PinLoading());

    try {
      final file = await _cacheFile();
      if (kDebugMode) print('[PinCubit] Cache file: ${file?.path}');
      final lastMod = await _cacheLastModified();
      if (kDebugMode) print('[PinCubit] Cache lastModified: $lastMod');

      final isFresh =
          lastMod != null && DateTime.now().difference(lastMod) <= ttl;
      if (kDebugMode) {
        print('[PinCubit] Cache fresh (<= ${ttl.inMinutes}m): $isFresh');
      }

      if (isFresh) {
        final cached = await _readCache();
        if (cached != null) {
          if (kDebugMode) {
            print('[PinCubit] Loaded ${cached.length} pins from CACHE (fresh)');
          }
          emit(PinLoaded(_pinsFromJsonList(cached)));
          return;
        } else {
          if (kDebugMode) {
            print('[PinCubit] Cache marked fresh but unreadable.');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('[PinCubit] Cache check error: $e');
    }

    final apiUrl = '${_apiBase()}/api/map/getsignforpin';
    try {
      if (kDebugMode) print('[PinCubit] Fetching NETWORK: $apiUrl');
      final res = await http.get(Uri.parse(apiUrl));
      if (kDebugMode) print('[PinCubit] HTTP ${res.statusCode}');
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      await _saveCacheString(res.body);
      if (kDebugMode) print('[PinCubit] Saved response to cache');

      final decoded = jsonDecode(res.body);
      if (decoded is! List) throw Exception('Unexpected JSON shape');
      final pins = _pinsFromJsonList(decoded.cast<Map<String, dynamic>>());
      if (kDebugMode) {
        print('[PinCubit] Loaded ${pins.length} pins from NETWORK');
      }
      emit(PinLoaded(pins));
    } catch (e) {
      if (kDebugMode) print('[PinCubit] Network failed: $e');
      final cached = await _readCache();
      if (cached != null) {
        if (kDebugMode) {
          print('[PinCubit] Falling back to CACHE. Count=${cached.length}');
        }
        emit(PinLoaded(_pinsFromJsonList(cached)));
      } else {
        if (kDebugMode) print('[PinCubit] No cache available -> error');
        emit(PinError(e.toString()));
      }
    }
  }
}
