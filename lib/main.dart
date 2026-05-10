import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app/app.dart';
import 'firebase_options.dart';
import 'services/google_calendar_service.dart';
import 'services/local_notification_service.dart';
import 'services/push_notification_bridge.dart';
import 'theme/app_colors.dart';

/// Пуши и локальные уведомления — после первого кадра.
Future<void> _initMessagingAfterFirstFrame() async {
  if (kIsWeb) return;
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e, st) {
    debugPrint('FCM onBackgroundMessage: $e\n$st');
  }
  // Сначала FCM (свой запрос прав), потом локальные — меньше конфликтов «permissionRequestInProgress».
  final mobile = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (mobile) {
    try {
      await PushNotificationBridge.init();
    } catch (e, st) {
      debugPrint('PushNotificationBridge.init: $e\n$st');
    }
  }
  try {
    await LocalNotificationService.instance.init();
  } catch (e, st) {
    debugPrint('LocalNotificationService.init: $e\n$st');
  }
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      PlatformDispatcher.instance.onError = (error, stack) {
        if (error is MissingPluginException) {
          debugPrint('MissingPlugin (игнор): $error');
          return true;
        }
        debugPrint('PlatformDispatcher error: $error\n$stack');
        return false;
      };

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await AppColors.loadThemePreference();
      try {
        await GoogleCalendarService.instance.init();
        FirebaseAuth.instance.authStateChanges().listen((user) {
          unawaited(
              GoogleCalendarService.instance.bindToFirebaseUser(user?.uid));
        });
        await GoogleCalendarService.instance
            .bindToFirebaseUser(FirebaseAuth.instance.currentUser?.uid);
      } catch (e, st) {
        debugPrint('GoogleCalendarService.init: $e\n$st');
      }
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
      runApp(const ZhasauApp());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initMessagingAfterFirstFrame());
      });
    },
    (e, st) => debugPrint('Uncaught zone error: $e\n$st'),
  );
}
