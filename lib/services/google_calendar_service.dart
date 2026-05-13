import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:shared_preferences/shared_preferences.dart';
import 'google_auth_client.dart';
import '../models/habit_model.dart';
import '../models/goal_model.dart';
import '../models/task_model.dart';

/// Service for Google Calendar two-way sync.
///
/// Sign-in → create/read/update/delete events ↔ Zhasau tasks & goals.
class GoogleCalendarService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final GoogleCalendarService instance = GoogleCalendarService._();
  GoogleCalendarService._();

  // ── Keys ───────────────────────────────────────────────────────────────────
  /// До версии с привязкой к Firebase uid флаг был общим на устройство — из‑за этого
  /// календарь «течёт» между аккаунтами приложения.
  static const _kEnabledLegacy = 'gcal_sync_enabled';
  static const _kPrefsMigratedPerUser = 'gcal_prefs_migrated_per_user_v2';
  static const _calendarId = 'primary';

  static String _enabledPrefsKey(String firebaseUid) =>
      'gcal_sync_enabled_$firebaseUid';

  // ── State ──────────────────────────────────────────────────────────────────
  final ValueNotifier<bool> isSyncEnabled = ValueNotifier(false);
  final ValueNotifier<bool> isSignedIn = ValueNotifier(false);
  final ValueNotifier<String?> accountEmail = ValueNotifier(null);
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  gcal.CalendarApi? _calendarApi;
  /// IANA-таймзона основного календаря Google (например, `Asia/Almaty`).
  /// Кешируем после успешного входа, чтобы создавать события в том же поясе,
  /// в котором пользователь их видит в Google Calendar.
  String? _primaryCalendarTimeZone;
  /// Последний [User.uid], для которого применена синхронизация prefs + Google.
  String? _boundFirebaseUid;
  Future<void> _bindQueue = Future<void>.value();

  // ── Init ───────────────────────────────────────────────────────────────────
  /// Call once at app start (e.g. in main.dart or MainShell).
  Future<void> init() async {
    _googleSignIn = GoogleSignIn(
      scopes: <String>[
        gcal.CalendarApi.calendarScope,
      ],
    );

    _googleSignIn!.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      isSignedIn.value = account != null;
      accountEmail.value = account?.email;
      if (account != null) {
        _initCalendarApi();
      } else {
        _calendarApi = null;
      }
    });
  }

  /// Вызывать из [FirebaseAuth.authStateChanges]: отвязать Google-сессию при смене /
  /// выходе из аккаунта Firebase и подставить флаг синхронизации для текущего uid.
  Future<void> bindToFirebaseUser(String? firebaseUid) async {
    _bindQueue = _bindQueue.then((_) async {
      try {
        await _bindToFirebaseUserImpl(firebaseUid);
      } catch (e, st) {
        debugPrint('bindToFirebaseUser: $e\n$st');
      }
    });
    await _bindQueue;
  }

  Future<void> _bindToFirebaseUserImpl(String? firebaseUid) async {
    if (_boundFirebaseUid == firebaseUid) return;

    try {
      await _googleSignIn?.signOut();
    } catch (e) {
      debugPrint('Google sign-out on user switch: $e');
    }
    _calendarApi = null;
    _currentUser = null;
    _primaryCalendarTimeZone = null;
    isSignedIn.value = false;
    accountEmail.value = null;

    _boundFirebaseUid = firebaseUid;

    if (firebaseUid == null || firebaseUid.isEmpty) {
      isSyncEnabled.value = false;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled = await _readAndMigrateSyncEnabled(prefs, firebaseUid);
    isSyncEnabled.value = enabled;

    if (enabled && _googleSignIn != null) {
      try {
        await _googleSignIn!.signInSilently();
      } catch (e) {
        debugPrint('Google silent sign-in after bind: $e');
      }
    }
  }

  Future<bool> _readAndMigrateSyncEnabled(
    SharedPreferences prefs,
    String firebaseUid,
  ) async {
    final key = _enabledPrefsKey(firebaseUid);
    if (prefs.containsKey(key)) {
      return prefs.getBool(key) ?? false;
    }
    final migrated = prefs.getBool(_kPrefsMigratedPerUser) ?? false;
    if (!migrated) {
      final legacy = prefs.getBool(_kEnabledLegacy) ?? false;
      await prefs.setBool(key, legacy);
      await prefs.remove(_kEnabledLegacy);
      await prefs.setBool(_kPrefsMigratedPerUser, true);
      return legacy;
    }
    return false;
  }

  Future<void> _initCalendarApi() async {
    if (_currentUser == null) {
      debugPrint('initCalendarApi: _currentUser=null, пропускаем');
      return;
    }
    try {
      final headers = await _currentUser!.authHeaders;
      final client = GoogleAuthClient(headers);
      _calendarApi = gcal.CalendarApi(client);
      debugPrint('initCalendarApi: Calendar API готов');
      unawaited(_refreshPrimaryCalendarTimeZone());
    } catch (e) {
      debugPrint('initCalendarApi: ошибка получения authHeaders: $e');
      _calendarApi = null;
    }
  }

  /// Узнаём таймзону основного календаря пользователя, чтобы создавать
  /// события в том же поясе. Иначе если устройство в одной TZ, а календарь
  /// в другой — время «съезжает» на разницу часов.
  Future<void> _refreshPrimaryCalendarTimeZone() async {
    final api = _calendarApi;
    if (api == null) return;
    try {
      final cal = await api.calendars.get(_calendarId);
      final tz = cal.timeZone;
      if (tz != null && tz.isNotEmpty) {
        _primaryCalendarTimeZone = tz;
        debugPrint('Primary calendar timezone: $tz');
      }
    } catch (e) {
      debugPrint('Не удалось получить timezone календаря: $e');
    }
  }

  // ── Sign In / Out ──────────────────────────────────────────────────────────
  /// Последняя причина неуспеха [signIn]; для отображения пользователю.
  String? lastSignInError;

  Future<bool> signIn() async {
    lastSignInError = null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      debugPrint('Google Calendar sign-in: нет пользователя Firebase');
      lastSignInError = 'Сначала войдите в аккаунт приложения.';
      return false;
    }
    try {
      final account = await _googleSignIn?.signIn();
      if (account != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_enabledPrefsKey(uid), true);
        await prefs.remove(_kEnabledLegacy);
        await prefs.setBool(_kPrefsMigratedPerUser, true);
        isSyncEnabled.value = true;
        return true;
      }
      lastSignInError = 'Вы отменили вход в Google.';
      return false;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      final msg = e.toString();
      if (msg.contains('network_error') ||
          msg.contains('ApiException: 7') ||
          msg.contains('UnknownHost')) {
        lastSignInError =
            'Нет подключения к Google. Проверьте интернет на устройстве/эмуляторе.';
      } else if (msg.contains('ApiException: 10') ||
          msg.contains('DEVELOPER_ERROR')) {
        lastSignInError =
            'Google Sign-In не настроен (DEVELOPER_ERROR). Проверьте SHA‑1 и OAuth client.';
      } else if (msg.contains('sign_in_canceled')) {
        lastSignInError = 'Вы отменили вход в Google.';
      } else {
        lastSignInError = 'Не удалось войти в Google: $msg';
      }
      return false;
    }
  }

  Future<void> signOut() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      await _googleSignIn?.signOut();
      final prefs = await SharedPreferences.getInstance();
      if (uid != null && uid.isNotEmpty) {
        await prefs.setBool(_enabledPrefsKey(uid), false);
      }
      isSyncEnabled.value = false;
      isSignedIn.value = false;
      accountEmail.value = null;
      _calendarApi = null;
      _primaryCalendarTimeZone = null;
    } catch (e) {
      debugPrint('Google sign-out error: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool get _ready => _calendarApi != null && isSyncEnabled.value;

  /// Возвращает локальное wall-clock значение [d] как DateTime без признака UTC.
  /// Нужно потому, что googleapis сериализует UTC-DateTime с суффиксом `Z`,
  /// и Google игнорирует параметр `timeZone`.
  DateTime _stripTz(DateTime d) {
    final local = d.isUtc ? d.toLocal() : d;
    return DateTime(local.year, local.month, local.day, local.hour,
        local.minute, local.second, local.millisecond, local.microsecond);
  }

  /// Таймзона, в которой надо создавать события.
  ///
  /// Приоритет: таймзона основного календаря пользователя (`_primaryCalendarTimeZone`),
  /// чтобы введённое в приложении «16:00» отображалось как «16:00» и в Google
  /// Calendar (даже если устройство стоит в другой TZ). Если по какой-то причине
  /// календарную TZ получить не удалось — падаем на смещение устройства
  /// (`Etc/GMT±N`).
  String _deviceTimeZoneName(DateTime moment) {
    final calTz = _primaryCalendarTimeZone;
    if (calTz != null && calTz.isNotEmpty) return calTz;
    final offset = moment.isUtc
        ? moment.toLocal().timeZoneOffset
        : moment.timeZoneOffset;
    final totalMinutes = offset.inMinutes;
    if (totalMinutes == 0) return 'Etc/GMT';
    if (totalMinutes % 60 != 0) return 'UTC';
    final hours = totalMinutes ~/ 60;
    return hours > 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}';
  }

  /// День недели 1…7 подходит под расписание привычки (пустой список = каждый день).
  bool _habitRunsOnWeekday(HabitModel habit, int weekday) {
    if (!habit.isRecurring) return true;
    if (habit.repeatWeekdays.isEmpty) return true;
    return habit.repeatWeekdays.contains(weekday);
  }

  /// Локальная дата+время из календарной даты [day] и строки `HH:mm`.
  DateTime? _dateTimeFromHmOnDay(DateTime day, String hm) {
    final n = HabitModel.normalizeTimeHm(hm);
    if (n == null) return null;
    final parts = n.split(':');
    final h = int.tryParse(parts[0]);
    final mi = int.tryParse(parts[1]);
    if (h == null || mi == null) return null;
    return DateTime(day.year, day.month, day.day, h, mi);
  }

  /// Момент начала для синхронизации с Google Calendar.
  ///
  /// Для разовой задачи с [HabitModel.deadline] — берём дедлайн.
  /// Для повторяющейся с [HabitModel.reminderTimes] — **первое** подходящее
  /// сочетание дня недели и времени слота **на или после даты создания**
  /// привычки (стабильно при повторных синках). Раньше использовался
  /// [HabitModel.createdAt] целиком — в календаре оказывалось время нажатия
  /// «Сохранить», а не выбранные 12:05.
  DateTime _habitCalendarStartLocal(HabitModel habit) {
    if (habit.deadline != null) {
      return habit.deadline!;
    }
    if (habit.reminderTimes.isNotEmpty) {
      final anchor = DateTime(
        habit.createdAt.year,
        habit.createdAt.month,
        habit.createdAt.day,
      );
      for (var offset = 0; offset < 14; offset++) {
        final day = anchor.add(Duration(days: offset));
        if (!_habitRunsOnWeekday(habit, day.weekday)) continue;
        for (final hm in habit.reminderTimes) {
          final dt = _dateTimeFromHmOnDay(day, hm);
          if (dt != null) return dt;
        }
      }
    }
    return habit.createdAt;
  }

  /// Re-authenticate if token expired. Returns true if ready.
  Future<bool> _ensureAuth() async {
    if (_calendarApi != null) return true;
    if (_currentUser == null) {
      try {
        final account = await _googleSignIn?.signInSilently();
        if (account == null) {
          debugPrint(
              'ensureAuth: signInSilently вернул null (нет кеша/сети/доступа)');
        }
      } catch (e) {
        debugPrint('ensureAuth: signInSilently error: $e');
      }
    }
    if (_currentUser != null) {
      await _initCalendarApi();
      // Возможна ситуация: _currentUser есть, но токен протух → authHeaders падает.
      // Тогда повторно вызовем silent sign-in, чтобы плагин обновил токен.
      if (_calendarApi == null) {
        try {
          await _googleSignIn?.signInSilently();
        } catch (e) {
          debugPrint('ensureAuth: повторный signInSilently error: $e');
        }
        if (_currentUser != null) {
          await _initCalendarApi();
        }
      }
    }
    if (_calendarApi == null) {
      debugPrint(
          'ensureAuth: не удалось получить Calendar API (вероятно нет сети к google.com)');
    }
    return _calendarApi != null;
  }

  // ── CRUD Events ────────────────────────────────────────────────────────────

  /// RRULE для привычки «каждый день»: 7 вхождений подряд (неделя вперёд).
  static const _kDailyHabitWeekRrule = <String>['RRULE:FREQ=DAILY;COUNT=7'];

  /// Повторяющаяся привычка «каждый день» ([repeatWeekdays] пусто) — в Calendar
  /// одна серия на 7 дней; иначе без RRULE (одно событие как раньше).
  bool _habitEveryDayRecurring(HabitModel habit) {
    return habit.isRecurring && habit.repeatWeekdays.isEmpty;
  }

  /// Повтор по выбранным дням недели (1=пн … 7=вс).
  bool _habitWeekdayRecurring(HabitModel habit) {
    return habit.isRecurring && habit.repeatWeekdays.isNotEmpty;
  }

  /// Один или несколько id событий Calendar, сохранённых в Firestore через `|`.
  List<String> _parseStoredCalendarEventIds(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Удаляет все события, перечисленные в [raw] (один id или `a|b|c`).
  Future<void> deleteStoredCalendarEventIds(String? raw) async {
    for (final id in _parseStoredCalendarEventIds(raw)) {
      await deleteEvent(id);
    }
  }

  /// Строки `HH:mm` для слотов в календаре (если слотов нет — время из [createdAt]).
  List<String> _habitCalendarTimeStrings(HabitModel habit) {
    if (habit.reminderTimes.isNotEmpty) {
      return List<String>.from(habit.reminderTimes);
    }
    final c = habit.createdAt;
    return [
      '${c.hour.toString().padLeft(2, '0')}:${c.minute.toString().padLeft(2, '0')}',
    ];
  }

  /// Все вхождения привычки «по дням недели» в окне из **7 календарных дней**
  /// начиная с даты создания (локально), с выбранными днями и временами слотов.
  List<DateTime> _habitWeekdaySlotsInSevenDayWindow(HabitModel habit) {
    final anchor = DateTime(
      habit.createdAt.year,
      habit.createdAt.month,
      habit.createdAt.day,
    );
    final weekdays = habit.repeatWeekdays.toSet();
    final times = _habitCalendarTimeStrings(habit);
    final out = <DateTime>[];
    for (var offset = 0; offset < 7; offset++) {
      final day = anchor.add(Duration(days: offset));
      if (!weekdays.contains(day.weekday)) continue;
      for (final hm in times) {
        final dt = _dateTimeFromHmOnDay(day, hm);
        if (dt != null) out.add(dt);
      }
    }
    out.sort();
    return out;
  }

  /// Create an event. Returns the event ID or null on failure.
  Future<String?> createEvent({
    required String title,
    String? description,
    required DateTime start,
    required DateTime end,
    List<int>? reminderMinutes,
    String? colorId,
    List<String>? recurrence,
  }) async {
    if (!_ready) return null;
    if (!await _ensureAuth()) return null;

    try {
      final tz = _deviceTimeZoneName(start);
      final event = gcal.Event()
        ..summary = title
        ..description = description ?? ''
        // Локальное wall-clock + явная IANA-таймзона устройства:
        // Google интерпретирует время как «вот это число часов:минут в этом TZ».
        ..start = gcal.EventDateTime(dateTime: _stripTz(start), timeZone: tz)
        ..end = gcal.EventDateTime(dateTime: _stripTz(end), timeZone: tz);

      if (recurrence != null && recurrence.isNotEmpty) {
        event.recurrence = recurrence;
      }

      // Reminders
      if (reminderMinutes != null && reminderMinutes.isNotEmpty) {
        event.reminders = gcal.EventReminders(
          useDefault: false,
          overrides: reminderMinutes
              .map((m) => gcal.EventReminder(method: 'popup', minutes: m))
              .toList(),
        );
      }

      // Color (1-11, Google Calendar palette)
      if (colorId != null) {
        event.colorId = colorId;
      }

      debugPrint(
        'Calendar createEvent: title="$title" start=$start end=$end tz=$tz '
        'recurrence=${recurrence ?? const []}',
      );
      final created = await _calendarApi!.events.insert(event, _calendarId);
      debugPrint('Calendar event created: ${created.id}');
      return created.id;
    } catch (e, st) {
      debugPrint('Error creating calendar event: $e\n$st');
      return null;
    }
  }

  /// Update an existing event by ID.
  ///
  /// [recurrence]: если передан (в т.ч. пустой список) — перезаписывает правила
  /// повтора серии; `null` — поле в API не трогаем.
  Future<bool> updateEvent({
    required String eventId,
    String? title,
    String? description,
    DateTime? start,
    DateTime? end,
    String? colorId,
    List<String>? recurrence,
  }) async {
    if (!_ready) return false;
    if (!await _ensureAuth()) return false;

    try {
      // Fetch current event first
      final existing = await _calendarApi!.events.get(_calendarId, eventId);

      if (title != null) existing.summary = title;
      if (description != null) existing.description = description;
      if (start != null) {
        existing.start = gcal.EventDateTime(
          dateTime: _stripTz(start),
          timeZone: _deviceTimeZoneName(start),
        );
      }
      if (end != null) {
        existing.end = gcal.EventDateTime(
          dateTime: _stripTz(end),
          timeZone: _deviceTimeZoneName(end),
        );
      }
      if (colorId != null) existing.colorId = colorId;
      if (recurrence != null) {
        existing.recurrence = recurrence.isEmpty ? null : recurrence;
      }

      await _calendarApi!.events.update(existing, _calendarId, eventId);
      return true;
    } catch (e) {
      debugPrint('Error updating calendar event: $e');
      return false;
    }
  }

  /// Delete an event by ID.
  Future<bool> deleteEvent(String eventId) async {
    if (!_ready) return false;
    if (!await _ensureAuth()) return false;

    try {
      await _calendarApi!.events.delete(_calendarId, eventId);
      return true;
    } catch (e) {
      debugPrint('Error deleting calendar event: $e');
      return false;
    }
  }

  /// List events in a time range.
  Future<List<gcal.Event>> listEvents({
    required DateTime timeMin,
    required DateTime timeMax,
  }) async {
    if (!_ready) return [];
    if (!await _ensureAuth()) return [];

    try {
      final events = await _calendarApi!.events.list(
        _calendarId,
        timeMin: timeMin.toUtc(),
        timeMax: timeMax.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );
      return events.items ?? [];
    } catch (e) {
      debugPrint('Error listing calendar events: $e');
      return [];
    }
  }

  // ── Sync Habits ↔ Calendar ─────────────────────────────────────────────────

  /// Sync a habit (task) to Google Calendar.
  ///
  /// Возвращает один id события или несколько, склеенных через `|` (режим
  /// «по дням недели» на неделю вперёд).
  Future<String?> syncHabitToCalendar(HabitModel habit) async {
    if (!isSyncEnabled.value) {
      debugPrint('syncHabitToCalendar: isSyncEnabled=false');
      return null;
    }
    if (_calendarApi == null) {
      debugPrint('syncHabitToCalendar: api=null, re-auth attempt');
      if (!await _ensureAuth()) {
        debugPrint('syncHabitToCalendar: re-auth failed');
        return null;
      }
    }

    final description = _buildHabitDescription(habit);
    final stored = habit.calendarEventId;
    var parsedIds = _parseStoredCalendarEventIds(stored);
    final dailyWeek = _habitEveryDayRecurring(habit);
    final weekdayWeek = _habitWeekdayRecurring(habit);

    // ——— Выбранные дни недели: отдельное событие на каждый слот в течение 7 дней
    if (weekdayWeek) {
      final slots = _habitWeekdaySlotsInSevenDayWindow(habit);
      debugPrint(
        'syncHabitToCalendar (weekdays): "${habit.title}" slots=${slots.length} '
        'days=${habit.repeatWeekdays}',
      );
      await deleteStoredCalendarEventIds(stored);
      if (slots.isEmpty) return null;
      final newIds = <String>[];
      final colorId = habit.completed ? '2' : (habit.isExpired ? '11' : '9');
      for (final slotStart in slots) {
        final slotEnd = slotStart.add(const Duration(hours: 1));
        final id = await createEvent(
          title: '📋 ${habit.title}',
          description: description,
          start: slotStart,
          end: slotEnd,
          reminderMinutes: const [30, 10],
          colorId: colorId,
          recurrence: null,
        );
        if (id != null && id.isNotEmpty) newIds.add(id);
      }
      if (newIds.isEmpty) return null;
      return newIds.join('|');
    }

    final start = _habitCalendarStartLocal(habit);
    final end = start.add(const Duration(hours: 1));
    debugPrint(
      'syncHabitToCalendar: title="${habit.title}" start=$start '
      '(deadline=${habit.deadline}, reminders=${habit.reminderTimes})',
    );

    if (parsedIds.length > 1) {
      await deleteStoredCalendarEventIds(stored);
      parsedIds = [];
    }

    if (parsedIds.length == 1) {
      final updated = await updateEvent(
        eventId: parsedIds.first,
        title: '📋 ${habit.title}',
        description: description,
        start: start,
        end: end,
        colorId: habit.completed ? '2' : (habit.isExpired ? '11' : '9'),
        recurrence: dailyWeek ? _kDailyHabitWeekRrule : const <String>[],
      );
      if (updated) return parsedIds.first;
      await deleteEvent(parsedIds.first);
    }

    return await createEvent(
      title: '📋 ${habit.title}',
      description: description,
      start: start,
      end: end,
      reminderMinutes: const [30, 10],
      colorId: habit.isQuickTask ? '6' : '9',
      recurrence: dailyWeek ? _kDailyHabitWeekRrule : null,
    );
  }

  String _buildHabitDescription(HabitModel habit) {
    final parts = <String>[];
    parts.add('Zhasau задача');
    if (habit.isQuickTask) parts.add('⚡ Быстрая задача');
    if (habit.isRecurring) parts.add('🔁 Повтор по дням');
    if (habit.reminderTimes.isNotEmpty) {
      parts.add('Время: ${habit.reminderTimes.join(', ')}');
    }
    if (habit.notes.isNotEmpty) parts.add(habit.notes);
    parts.add('XP: +${habit.xpReward}');
    if (habit.completed) parts.add('✅ Выполнено');
    return parts.join('\n');
  }

  /// Текст в описании событий, созданных приложением (не считать «внешними»).
  static bool _isZhasauOwnedCalendarDescription(String? description) {
    final desc = description ?? '';
    return desc.contains('Zhasau задача') ||
        desc.contains('Zhasau цель') ||
        desc.contains('Zhasau·task·goal');
  }

  // ── Sync goal-linked tasks (TaskModel) ↔ Calendar ───────────────────────────

  /// Создаёт или обновляет событие для задачи цели ([TaskModel.goalId] не null).
  Future<String?> syncGoalTaskToCalendar(TaskModel task, GoalModel goal) async {
    if (!_ready) return null;
    if (task.goalId == null || task.goalId!.isEmpty) return null;
    if (!await _ensureAuth()) return null;

    final start = task.scheduledAt ?? DateTime.now();
    final end = start.add(const Duration(hours: 1));
    final description = _buildGoalTaskDescription(task, goal);

    if (task.calendarEventId != null && task.calendarEventId!.isNotEmpty) {
      final updated = await updateEvent(
        eventId: task.calendarEventId!,
        title: _goalTaskEventTitle(task),
        description: description,
        start: start,
        end: end,
        colorId: task.completed ? '2' : '9',
      );
      return updated ? task.calendarEventId : null;
    }

    return createEvent(
      title: _goalTaskEventTitle(task),
      description: description,
      start: start,
      end: end,
      reminderMinutes: const [30, 10],
      colorId: task.completed ? '2' : '9',
    );
  }

  String _goalTaskEventTitle(TaskModel task) {
    if (task.completed) return '✅ ${task.title}';
    return '📌 ${task.title}';
  }

  String _buildGoalTaskDescription(TaskModel task, GoalModel goal) {
    final lines = <String>[
      'Zhasau·task·goal',
      'Цель: ${goal.title}',
      task.subtitle,
      'Награда: ${task.reward.toInt()} XP',
    ];
    if (task.completed) lines.add('✅ Выполнено');
    return lines.join('\n');
  }

  // ── Sync Goals ↔ Calendar ──────────────────────────────────────────────────

  /// Sync a goal to Google Calendar as an all-day event span.
  Future<String?> syncGoalToCalendar(GoalModel goal) async {
    if (!_ready) return null;

    final description = 'Zhasau цель\n'
        '📌 ${goal.subtitle}\n'
        '🏷 ${goal.badge}\n'
        'Прогресс: ${goal.progress}%\n'
        'Осталось задач: ${goal.tasksLeft}';

    // If already linked — update
    if (goal.calendarEventId != null && goal.calendarEventId!.isNotEmpty) {
      try {
        if (!await _ensureAuth()) return null;
        final existing = await _calendarApi!.events.get(
            _calendarId, goal.calendarEventId!);

        existing.summary = '🎯 ${goal.title} — ${goal.subtitle}';
        existing.description = description;

        await _calendarApi!.events.update(
            existing, _calendarId, goal.calendarEventId!);
        return goal.calendarEventId;
      } catch (e) {
        debugPrint('Error updating goal event: $e');
        return null;
      }
    }

    // Create as all-day event if deadline exists
    if (goal.deadline != null) {
      try {
        if (!await _ensureAuth()) return null;

        final event = gcal.Event()
          ..summary = '🎯 ${goal.title} — ${goal.subtitle}'
          ..description = description
          ..start = gcal.EventDateTime(
            date: goal.deadline,
          )
          ..end = gcal.EventDateTime(
            date: goal.deadline!.add(const Duration(days: 1)),
          )
          ..colorId = '5' // yellow for goals
          ..reminders = gcal.EventReminders(
            useDefault: false,
            overrides: [
              gcal.EventReminder(method: 'popup', minutes: 1440), // 1 day before
              gcal.EventReminder(method: 'popup', minutes: 60),   // 1 hour before
            ],
          );

        final created = await _calendarApi!.events.insert(event, _calendarId);
        return created.id;
      } catch (e) {
        debugPrint('Error creating goal event: $e');
        return null;
      }
    }
    return null;
  }

  // ── Fetch from Calendar → Zhasau ───────────────────────────────────────────

  /// Pull events from Google Calendar for today.
  /// Returns events that are NOT Zhasau-originated (external events).
  Future<List<gcal.Event>> fetchExternalEvents({
    DateTime? from,
    DateTime? to,
  }) async {
    final now = DateTime.now();
    final start = from ?? DateTime(now.year, now.month, now.day);
    final end = to ?? start.add(const Duration(days: 1));

    final events = await listEvents(timeMin: start, timeMax: end);

    return events.where((e) => !_isZhasauOwnedCalendarDescription(e.description)).toList();
  }

  /// Fetch ALL events for a specific date (including Zhasau-created).
  Future<List<gcal.Event>> fetchEventsForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return await listEvents(timeMin: start, timeMax: end);
  }

  /// Fetch events for a month (for calendar view dots).
  Future<Map<DateTime, List<gcal.Event>>> fetchEventsForMonth(
      int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final events = await listEvents(timeMin: start, timeMax: end);

    final Map<DateTime, List<gcal.Event>> grouped = {};
    for (final event in events) {
      final eventDate = event.start?.dateTime ?? event.start?.date;
      if (eventDate != null) {
        final key = DateTime(eventDate.year, eventDate.month, eventDate.day);
        grouped.putIfAbsent(key, () => []).add(event);
      }
    }
    return grouped;
  }

  // ── Bulk Sync ──────────────────────────────────────────────────────────────

  /// Sync all habits and goals to Google Calendar.
  /// Returns a map of model IDs → calendar event IDs.
  Future<Map<String, String>> syncAll({
    required List<HabitModel> habits,
    required List<GoalModel> goals,
  }) async {
    if (!_ready) return {};
    isSyncing.value = true;

    final Map<String, String> results = {};

    try {
      for (final habit in habits) {
        final eventId = await syncHabitToCalendar(habit);
        if (eventId != null && habit.id != null) {
          results[habit.id!] = eventId;
        }
      }

      for (final goal in goals) {
        final eventId = await syncGoalToCalendar(goal);
        if (eventId != null) {
          results[goal.id] = eventId;
        }
      }
    } catch (e) {
      debugPrint('Bulk sync error: $e');
    } finally {
      isSyncing.value = false;
    }

    return results;
  }
}
