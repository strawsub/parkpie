// pin_cubit.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'pin_state.dart';
import 'pin_model.dart';

class PinCubit extends Cubit<PinState> {
  PinCubit() : super(PinInitial());

  /// Resolve API base
  String _apiBase() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://localhost:8081';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8081';
    return 'http://localhost:8081';
  }

  /// Load pins from API
  Future<void> loadPins() async {
    emit(PinLoading());
    final apiUrl = '${_apiBase()}/api/map/getlocforpin';

    try {
      final res = await http.get(Uri.parse(apiUrl));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) throw Exception('Unexpected JSON shape');

      final pins = decoded
          .map((e) => Pin.fromJson(e as Map<String, dynamic>))
          .where((p) => p.lat != null && p.lng != null)
          .toList();

      emit(PinLoaded(pins));
    } catch (e) {
      emit(PinError(e.toString()));
    }
  }
}