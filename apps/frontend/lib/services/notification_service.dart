import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );

    _initialized = true;

    // Request permissions for iOS
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleTimerExpiredNotification({
    required DateTime expiryTime,
    String? zoneName,
    int? zoneNumber,
  }) async {
    await cancelTimerNotification();

    // Use zoneName if it's different from "Zone {number}", otherwise just use zone number
    final zoneText = zoneName != null && zoneName != 'Zone $zoneNumber'
        ? zoneName
        : zoneNumber != null
            ? 'Zone $zoneNumber'
            : 'your parking zone';

    const androidDetails = AndroidNotificationDetails(
      'timer_channel',
      'Timer Notifications',
      channelDescription: 'Notifications for parking timer expiration',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      0, // notification id
      'Parking Timer Expired!',
      'Your parking time in $zoneText has ended. Please move your vehicle.',
      tz.TZDateTime.from(expiryTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showImmediateNotification({
    String? zoneName,
    int? zoneNumber,
  }) async {
    // Use zoneName if it's different from "Zone {number}", otherwise just use zone number
    final zoneText = zoneName != null && zoneName != 'Zone $zoneNumber'
        ? zoneName
        : zoneNumber != null
            ? 'Zone $zoneNumber'
            : 'your parking zone';

    const androidDetails = AndroidNotificationDetails(
      'timer_channel',
      'Timer Notifications',
      channelDescription: 'Notifications for parking timer expiration',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      'Parking Timer Expired!',
      'Your parking time in $zoneText has ended. Please move your vehicle.',
      details,
    );
  }

  Future<void> cancelTimerNotification() async {
    await _notifications.cancel(0);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
