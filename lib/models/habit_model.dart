import 'package:cloud_firestore/cloud_firestore.dart';

class HabitModel {
  final String? id;
  final String title;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isQuickTask;
  /// Повторяющаяся привычка по дням недели ([repeatWeekdays]); иначе разовая/с дедлайном.
  final bool isRecurring;
  /// Дни недели 1=пн … 7=вс (как [DateTime.weekday]). Пусто = каждый день.
  final List<int> repeatWeekdays;
  /// Локальная дата последнего засчитанного выполнения `yyyy-MM-dd` (для [isRecurring] без слотов времени).
  final String? lastCompletedDateKey;
  /// Времена напоминаний за день, локальные строки `HH:mm`, отсортированы. Пусто — одна отметка на день (как раньше).
  final List<String> reminderTimes;
  /// Какие слоты из [reminderTimes] отмечены в день [slotsProgressDateKey].
  final List<String> completedSlotsToday;
  /// Дата, к которой относятся [completedSlotsToday] (`yyyy-MM-dd`).
  final String? slotsProgressDateKey;
  final int xpReward;
  /// Coins granted when the habit is completed (see [AppStore.completeHabitTask]).
  final int coinReward;
  final DateTime? deadline;
  final String? calendarEventId;
  /// Заметка к задаче (экран создания «Описание»).
  final String notes;

  const HabitModel({
    this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
    this.completedAt,
    this.isQuickTask = false,
    this.isRecurring = false,
    this.repeatWeekdays = const [],
    this.lastCompletedDateKey,
    this.reminderTimes = const [],
    this.completedSlotsToday = const [],
    this.slotsProgressDateKey,
    this.xpReward = 10,
    this.coinReward = 0,
    this.deadline,
    this.calendarEventId,
    this.notes = '',
  });

  /// Ключ локальной календарной даты `yyyy-MM-dd`.
  static String dateKeyLocal(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    final y = x.year.toString().padLeft(4, '0');
    final m = x.month.toString().padLeft(2, '0');
    final day = x.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String? normalizeTimeHm(String raw) {
    final t = raw.trim();
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t);
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final mi = int.tryParse(m.group(2)!);
    if (h == null || mi == null) return null;
    if (h < 0 || h > 23 || mi < 0 || mi > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
  }

  static List<String> parseReminderTimes(dynamic raw) {
    if (raw is! List) return const [];
    final set = <String>{};
    for (final e in raw) {
      final n = normalizeTimeHm(e.toString());
      if (n != null) set.add(n);
    }
    final out = set.toList()..sort();
    return out;
  }

  static List<String> parseCompletedSlots(dynamic raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    for (final e in raw) {
      final n = normalizeTimeHm(e.toString());
      if (n != null) out.add(n);
    }
    return out;
  }

  /// Слоты, отмеченные для календарного дня [day] (локально).
  List<String> completedSlotsForDay(DateTime day) {
    final k = dateKeyLocal(day);
    if (slotsProgressDateKey != k) return [];
    return List.from(completedSlotsToday);
  }

  /// Все временные слоты за [day] отмечены.
  bool allReminderSlotsDoneForDay(DateTime day) {
    if (reminderTimes.isEmpty) return false;
    final done = completedSlotsForDay(day);
    return reminderTimes.every((t) => done.contains(t));
  }

  /// Сегодня по календарю отмечено выполнение (для отображения и фильтров).
  bool isDoneForLocalDay(DateTime day) {
    if (isRecurring && reminderTimes.isNotEmpty) {
      return allReminderSlotsDoneForDay(day);
    }
    final key = dateKeyLocal(day);
    final last = lastCompletedDateKey?.trim();
    if (last != null && last.isNotEmpty && last == key) return true;
    if (!isRecurring &&
        completed &&
        completedAt != null &&
        completedAt!.year == day.year &&
        completedAt!.month == day.month &&
        completedAt!.day == day.day) {
      return true;
    }
    return false;
  }

  /// Показывать в списке «сегодня» для повторяющейся привычки.
  bool matchesRepeatOn(DateTime date) {
    if (!isRecurring) return true;
    if (repeatWeekdays.isEmpty) return true;
    return repeatWeekdays.contains(date.weekday);
  }

  /// True if this is a quick task whose deadline has passed without completion.
  bool get isExpired =>
      !completed &&
      deadline != null &&
      DateTime.now().isAfter(deadline!);

  static List<int> _parseWeekdays(dynamic raw) {
    if (raw is! List) return const [];
    final out = <int>[];
    for (final e in raw) {
      final n = (e as num?)?.toInt();
      if (n != null && n >= 1 && n <= 7) out.add(n);
    }
    return out;
  }

  factory HabitModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtRaw = data['createdAt'];

    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else {
      createdAt = DateTime.now();
    }

    final completedAtRaw = data['completedAt'];
    DateTime? completedAt;
    if (completedAtRaw is Timestamp) {
      completedAt = completedAtRaw.toDate();
    }

    final deadlineRaw = data['deadline'];
    DateTime? deadline;
    if (deadlineRaw is Timestamp) {
      deadline = deadlineRaw.toDate();
    }

    final rawLast = data['lastCompletedDateKey'] as String?;
    final lastKey = rawLast?.trim();
    final lastCompletedDateKey =
        (lastKey != null && lastKey.isNotEmpty) ? lastKey : null;

    final rawProg = data['slotsProgressDateKey'] as String?;
    final progK = rawProg?.trim();
    final slotsProgressDateKey =
        (progK != null && progK.isNotEmpty) ? progK : null;

    return HabitModel(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      completed: data['completed'] == true,
      createdAt: createdAt,
      completedAt: completedAt,
      isQuickTask: data['isQuickTask'] == true,
      isRecurring: data['isRecurring'] == true,
      repeatWeekdays: _parseWeekdays(data['repeatWeekdays']),
      lastCompletedDateKey: lastCompletedDateKey,
      reminderTimes: parseReminderTimes(data['reminderTimes']),
      completedSlotsToday: parseCompletedSlots(data['completedSlotsToday']),
      slotsProgressDateKey: slotsProgressDateKey,
      xpReward: (data['xpReward'] as num?)?.toInt() ?? 10,
      coinReward: (data['coinReward'] as num?)?.toInt() ?? 0,
      deadline: deadline,
      calendarEventId: data['calendarEventId'] as String?,
      notes: (data['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'completed': completed,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'isQuickTask': isQuickTask,
      'isRecurring': isRecurring,
      'repeatWeekdays': repeatWeekdays,
      'lastCompletedDateKey': lastCompletedDateKey ?? '',
      'reminderTimes': reminderTimes,
      'completedSlotsToday': completedSlotsToday,
      'slotsProgressDateKey': slotsProgressDateKey ?? '',
      'xpReward': xpReward,
      'coinReward': coinReward,
      if (deadline != null) 'deadline': Timestamp.fromDate(deadline!),
      if (calendarEventId != null) 'calendarEventId': calendarEventId,
      if (notes.isNotEmpty) 'notes': notes,
    };
  }

  HabitModel copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? isQuickTask,
    bool? isRecurring,
    List<int>? repeatWeekdays,
    String? lastCompletedDateKey,
    bool clearLastCompletedDateKey = false,
    List<String>? reminderTimes,
    List<String>? completedSlotsToday,
    String? slotsProgressDateKey,
    bool clearSlotsProgress = false,
    int? xpReward,
    int? coinReward,
    DateTime? deadline,
    String? calendarEventId,
    String? notes,
  }) {
    return HabitModel(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      isQuickTask: isQuickTask ?? this.isQuickTask,
      isRecurring: isRecurring ?? this.isRecurring,
      repeatWeekdays: repeatWeekdays ?? List.from(this.repeatWeekdays),
      lastCompletedDateKey: clearLastCompletedDateKey
          ? null
          : (lastCompletedDateKey ?? this.lastCompletedDateKey),
      reminderTimes: reminderTimes ?? List.from(this.reminderTimes),
      completedSlotsToday: clearSlotsProgress
          ? const []
          : (completedSlotsToday ?? List.from(this.completedSlotsToday)),
      slotsProgressDateKey:
          clearSlotsProgress ? null : (slotsProgressDateKey ?? this.slotsProgressDateKey),
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
      deadline: deadline ?? this.deadline,
      calendarEventId: calendarEventId ?? this.calendarEventId,
      notes: notes ?? this.notes,
    );
  }
}
