import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Firebase might not be fully configured/supported on current platform (e.g. Windows)
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Handle foreground FCM messages
    FirebaseMessaging.onMessage.listen((message) {
      showLocalNotification(
        message.notification?.title ?? 'LiFe',
        message.notification?.body ?? '',
      );
    });
  }

  static Future<void> showLocalNotification(String title, String body) async {
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
  }
}
