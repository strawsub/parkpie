import 'package:flutter/foundation.dart';

String resolveApiBaseUrl() {
  const fromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://parkpie-90018.azurewebsites.net',
  );
  if (fromEnv.isNotEmpty) {
    return fromEnv;
  }
  if (kIsWeb) {
    return 'http://localhost:8080';
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'https://parkpie-90018.azurewebsites.net';
}
