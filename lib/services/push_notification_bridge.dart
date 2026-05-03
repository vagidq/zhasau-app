import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'local_notification_service.dart';
import 'user_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// FCM: foreground → локальный показ; токен пишется в Firestore при наличии сессии.
class PushNotificationBridge {
  PushNotificationBridge._();

  static Future<void> _persistTokenToFirestore(String? token) async {
    if (kIsWeb || token == null || token.isEmpty) return;
    try {
      if (FirebaseAuth.instance.currentUser == null) return;
      await UserService().saveFcmTokenToProfile(token);
    } catch (e) {
      debugPrint('FCM persist token: $e');
    }
  }

  /// Вызвать после входа / восстановления сессии, если токен появился раньше пользователя.
  static Future<void> syncTokenToFirestore() async {
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await _persistTokenToFirestore(token);
    } catch (e) {
      debugPrint('FCM sync: $e');
    }
  }

  /// Перед [FirebaseAuth.signOut]: убрать токен из профиля и у инстанса FCM.
  static Future<void> beforeSignOut() async {
    if (kIsWeb) return;
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await UserService().clearFcmTokenFromProfile();
      }
    } catch (e) {
      debugPrint('FCM clear profile: $e');
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('FCM deleteToken: $e');
    }
  }

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

    FirebaseMessaging.instance.onTokenRefresh.listen(_persistTokenToFirestore);

    try {
      final token = await messaging.getToken();
      await _persistTokenToFirestore(token);
    } catch (e) {
      debugPrint('FCM getToken: $e');
    }
  }
}
