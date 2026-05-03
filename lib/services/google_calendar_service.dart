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
  static const _kEnabled = 'gcal_sync_enabled';
  static const _calendarId = 'primary';

  // ── State ──────────────────────────────────────────────────────────────────
  final ValueNotifier<bool> isSyncEnabled = ValueNotifier(false);
  final ValueNotifier<bool> isSignedIn = ValueNotifier(false);
  final ValueNotifier<String?> accountEmail = ValueNotifier(null);
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  gcal.CalendarApi? _calendarApi;

  // ── Init ───────────────────────────────────────────────────────────────────
  /// Call once at app start (e.g. in main.dart or MainShell).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isSyncEnabled.value = prefs.getBool(_kEnabled) ?? false;

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

    // Try silent sign-in if sync was previously enabled
    if (isSyncEnabled.value) {
      try {
        await _googleSignIn!.signInSilently();
      } catch (e) {
        debugPrint('Google silent sign-in failed: $e');
      }
    }
  }

  Future<void> _initCalendarApi() async {
    if (_currentUser == null) return;
    try {
      final headers = await _currentUser!.authHeaders;
      final client = GoogleAuthClient(headers);
      _calendarApi = gcal.CalendarApi(client);
    } catch (e) {
      debugPrint('Failed to init Calendar API: $e');
      _calendarApi = null;
    }
  }

  // ── Sign In / Out ──────────────────────────────────────────────────────────
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn?.signIn();
      if (account != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kEnabled, true);
        isSyncEnabled.value = true;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, false);
      isSyncEnabled.value = false;
      isSignedIn.value = false;
      accountEmail.value = null;
      _calendarApi = null;
    } catch (e) {
      debugPrint('Google sign-out error: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool get _ready => _calendarApi != null && isSyncEnabled.value;

  /// Re-authenticate if token expired. Returns true if ready.
  Future<bool> _ensureAuth() async {
    if (_calendarApi != null) return true;
    if (_currentUser == null) {
      try {
        await _googleSignIn?.signInSilently();
      } catch (_) {}
    }
    if (_currentUser != null) {
      await _initCalendarApi();
    }
    return _calendarApi != null;
  }

  // ── CRUD Events ────────────────────────────────────────────────────────────

  /// Create an event. Returns the event ID or null on failure.
  Future<String?> createEvent({
    required String title,
    String? description,
    required DateTime start,
    required DateTime end,
    List<int>? reminderMinutes,
    String? colorId,
  }) async {
    if (!_ready) return null;
    if (!await _ensureAuth()) return null;

    try {
      final event = gcal.Event()
        ..summary = title
        ..description = description ?? ''
        ..start = gcal.EventDateTime(dateTime: start, timeZone: 'Asia/Almaty')
        ..end = gcal.EventDateTime(dateTime: end, timeZone: 'Asia/Almaty');

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

      final created = await _calendarApi!.events.insert(event, _calendarId);
      debugPrint('Calendar event created: ${created.id}');
      return created.id;
    } catch (e) {
      debugPrint('Error creating calendar event: $e');
      return null;
    }
  }

  /// Update an existing event by ID.
  Future<bool> updateEvent({
    required String eventId,
    String? title,
    String? description,
    DateTime? start,
    DateTime? end,
    String? colorId,
  }) async {
    if (!_ready) return false;
    if (!await _ensureAuth()) return false;

    try {
      // Fetch current event first
      final existing = await _calendarApi!.events.get(_calendarId, eventId);

      if (title != null) existing.summary = title;
      if (description != null) existing.description = description;
      if (start != null) {
        existing.start = gcal.EventDateTime(dateTime: start, timeZone: 'Asia/Almaty');
      }
      if (end != null) {
        existing.end = gcal.EventDateTime(dateTime: end, timeZone: 'Asia/Almaty');
      }
      if (colorId != null) existing.colorId = colorId;

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
  /// Returns the calendar event ID.
  Future<String?> syncHabitToCalendar(HabitModel habit) async {
    if (!_ready) return null;

    final start = habit.deadline ?? habit.createdAt;
    final end = start.add(const Duration(hours: 1));
    final description = _buildHabitDescription(habit);

    // If already linked — update
    if (habit.calendarEventId != null && habit.calendarEventId!.isNotEmpty) {
      final updated = await updateEvent(
        eventId: habit.calendarEventId!,
        title: '📋 ${habit.title}',
        description: description,
        start: start,
        end: end,
        colorId: habit.completed ? '2' : (habit.isExpired ? '11' : '9'), // green / red / blue
      );
      return updated ? habit.calendarEventId : null;
    }

    // Otherwise — create new
    return await createEvent(
      title: '📋 ${habit.title}',
      description: description,
      start: start,
      end: end,
      reminderMinutes: [30, 10],
      colorId: habit.isQuickTask ? '6' : '9', // orange for quick, blue for regular
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
