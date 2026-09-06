import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'payment_notifications',
    'Payment Notifications',
    description: 'Notifications for pending and partial payments',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: initializationSettings,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'payment_notifications',
      'Payment Notifications',
      channelDescription:
          'Notifications for pending and partial payments',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }
}