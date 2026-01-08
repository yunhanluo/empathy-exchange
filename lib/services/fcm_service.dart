import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Request notification permission
  static Future<bool> requestPermission() async {
    if (kIsWeb) {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    }
    return false;
  }

  // Get FCM token
  static Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        await _messaging.requestPermission();
        String? token = await _messaging.getToken(
          vapidKey:
              'BDLq2LyEoEFq_wAp9VqLeDhyZmtDAGMcvvwBI-6FDaApbc00-zbzo8C8ZutayDfovKXrzLMjOr1MKA_6NOZmzqo',
        );
        return token;
      }
      return null;
    } catch (e) {
      ('Error getting FCM token: $e');
      return null;
    }
  }

  // Initialize FCM
  static Future<void> initialize() async {
    if (!kIsWeb) return;

    await requestPermission();

    String? token = await getToken();
    ('FCM Token: $token');

    // Handle foreground messages
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // print('Nice, a message arrived!');
      // print('Message data: ${message.data}');
      // if (message.notification != null) {
        // print('Message also contained a notification: ${message.notification}');
      // }
    // });

    // Handle background messages (when app is in background)
    // FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // print('A new onMessageOpenedApp event was published!');
      // print('Message data: ${message.data}');
    // });
  }
}
