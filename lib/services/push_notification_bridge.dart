import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Подписка на FCM: foreground → локальное уведомление; background handler регистируется из [main].
class PushNotificationBridge {
  PushNotificationBridge._();

  static Future<void> init() async {
    if (kIsWeb) return;

    final messaging = FirebaseMessaging.instance;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n != null) {
        LocalNotificationService.instance.showRemoteNotification(n);
      }
    });

    try {
      final token = await messaging.getToken();
      debugPrint('FCM token: $token');
    } catch (e) {
      debugPrint('FCM getToken: $e');
    }
  }
}
