class AppConfig {
  /// Change this per platform:
  /// - Android Emulator -> 10.0.2.2
  /// - iOS Simulator -> localhost (127.0.0.1)
  /// - Physical device -> your laptop's LAN IP (e.g., 192.168.1.23)
  static const String hostAndroidEmu = '10.0.2.2';
  static const String hostIosSim = '127.0.0.1';

  static const int backendPort = 8080;

  static String baseUrl({required bool isAndroid}) {
    final host = isAndroid ? hostAndroidEmu : hostIosSim;
    return 'http://$host:$backendPort';
  }
}
