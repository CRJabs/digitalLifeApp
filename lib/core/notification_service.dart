import 'dart:developer' as dev;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings),
      );

      // Request notification permissions for Android 13+
      final androidImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      // Request notification permissions for iOS
      final iosImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      dev.log('NotificationService — failed to initialize or request permission: $e');
    }
  }

  static Future<void> showLocalNotification(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'life_channel',
        'LiFe Alerts',
        channelDescription: 'Attendance and event notifications',
        importance: Importance.high,
        priority: Priority.high,
      );
      await _plugin.show(
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) & 0x7FFFFFFF, // unique ID
        title,
        body,
        const NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      dev.log('NotificationService — failed to show notification: $e');
    }
  }
}
