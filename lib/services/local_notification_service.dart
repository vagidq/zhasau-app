import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit_model.dart';

/// Локальные уведомления: расписание по привычкам и показ пушей FCM в foreground.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  /// Нативный плагин недоступен (hot restart, сбой регистрации и т.п.) — не дёргать channel повторно.
  bool _nativeUnavailable = false;
  /// Один параллельный init (иначе два вызова → «permissionRequestInProgress»).
  Future<void>? _initFuture;

  static const _habitChannelId = 'habit_reminders';
  static const _habitChannelName = 'Привычки';
  static const _remoteChannelId = 'remote_messages';
  static const _remoteChannelName = 'Сообщения';

  int _stableNotifId(String key) => key.hashCode & 0x7FFFFFFF;

  Future<void> _withAndroidPermissionRetry(Future<dynamic> Function() request) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        await request();
        return;
      } on PlatformException catch (e) {
        if (e.code == 'permissionRequestInProgress') {
          await Future<void>.delayed(Duration(milliseconds: 120 * (attempt + 1)));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> init() async {
    if (_initialized || _nativeUnavailable) return;
    _initFuture ??= _initInternal();
    await _initFuture!;
  }

  Future<void> _initInternal() async {
    if (_initialized || _nativeUnavailable) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final name = info.identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e, st) {
      debugPrint('Timezone: $e\n$st');
      tz.setLocalLocation(tz.UTC);
    }

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidInit,
          iOS: iosInit,
        ),
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (android != null) {
          await _withAndroidPermissionRetry(
              () => android.requestNotificationsPermission());
          await _withAndroidPermissionRetry(
              () => android.requestExactAlarmsPermission());
        }
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }

      await _ensureAndroidChannels();

      _initialized = true;
    } catch (e, st) {
      _nativeUnavailable = true;
      _initFuture = null;
      debugPrint('flutter_local_notifications init failed: $e\n$st');
    }
  }

  Future<void> _ensureAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _habitChannelId,
      _habitChannelName,
      description: 'Напоминания о привычках по расписанию',
      importance: Importance.high,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _remoteChannelId,
      _remoteChannelName,
      description: 'Уведомления из облака',
      importance: Importance.defaultImportance,
    ));
  }

  NotificationDetails get _habitDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _habitChannelId,
          _habitChannelName,
          channelDescription: 'Напоминания о привычках по расписанию',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  NotificationDetails get _remoteDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _remoteChannelId,
          _remoteChannelName,
          channelDescription: 'Уведомления из облака',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      );

  tz.TZDateTime _nextDailyTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// [weekday] 1 = пн … 7 = вс (как [DateTime.weekday]).
  tz.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Пересобрать все отложенные напоминания привычек (после загрузки из Firestore).
  Future<void> rescheduleHabitReminders(List<HabitModel> habits) async {
    if (!_initialized && !_nativeUnavailable) await init();
    if (!_initialized || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    await _plugin.cancelAll();

    for (final h in habits) {
      final id = h.id;
      if (id == null || id.isEmpty) continue;
      if (!h.isRecurring || h.reminderTimes.isEmpty) continue;

      for (final hm in h.reminderTimes) {
        final parts = hm.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        const title = 'Привычка';
        final body = h.title.length > 100
            ? '${h.title.substring(0, 100)}…'
            : h.title;

        if (h.repeatWeekdays.isEmpty) {
          final nid = _stableNotifId('habit|$id|d|$hm');
          final when = _nextDailyTime(hour, minute);
          try {
            await _plugin.zonedSchedule(
              id: nid,
              scheduledDate: when,
              notificationDetails: _habitDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              title: title,
              body: body,
              payload: id,
              matchDateTimeComponents: DateTimeComponents.time,
            );
          } catch (e, st) {
            debugPrint('Schedule habit daily $id $hm: $e\n$st');
          }
        } else {
          for (final wd in h.repeatWeekdays) {
            if (wd < DateTime.monday || wd > DateTime.sunday) continue;
            final nid = _stableNotifId('habit|$id|w$wd|$hm');
            final when = _nextWeekdayTime(wd, hour, minute);
            try {
              await _plugin.zonedSchedule(
                id: nid,
                scheduledDate: when,
                notificationDetails: _habitDetails,
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                title: title,
                body: body,
                payload: id,
                matchDateTimeComponents:
                    DateTimeComponents.dayOfWeekAndTime,
              );
            } catch (e, st) {
              debugPrint('Schedule habit weekly $id $wd $hm: $e\n$st');
            }
          }
        }
      }
    }
  }

  /// Показать уведомление из FCM, когда приложение на экране.
  Future<void> showRemoteNotification(RemoteNotification notification) async {
    if (!_initialized && !_nativeUnavailable) await init();
    if (!_initialized || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    final title = notification.title ?? 'Zhasau';
    final body = notification.body ?? '';
    final id = _stableNotifId('fcm|$title|$body|${DateTime.now().millisecondsSinceEpoch}');
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _remoteDetails,
    );
  }
}
