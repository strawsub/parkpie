import 'dart:async';
import 'dart:io';

/// Service for monitoring network connectivity
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final _connectivityController = StreamController<bool>.broadcast();
  bool _isOnline = true;
  Timer? _checkTimer;

  /// Stream of network connectivity status
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Current online status
  bool get isOnline => _isOnline;

  /// Starts monitoring network connectivity
  void startMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final online = await checkConnectivity();
      if (online != _isOnline) {
        _isOnline = online;
        _connectivityController.add(_isOnline);
      }
    });

    // Initial check
    checkConnectivity().then((online) {
      _isOnline = online;
      _connectivityController.add(_isOnline);
    });
  }

  /// Stops monitoring network connectivity
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Checks if device has network connectivity
  static Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _checkTimer?.cancel();
    _connectivityController.close();
  }
}
