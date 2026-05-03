import 'dart:math' show max;

class UserProfile {
  final String id;
  String name;
  /// Почта из Firestore / регистрации (не путать с Google Calendar).
  String? email;
  /// Короткий текст «о себе» (Firestore `bio`).
  String bio;
  /// Ссылка на фото в профиле (Firestore). Если не задано — в UI можно показать фото аккаунта входа.
  String? photoUrl;
  int level;
  int xp;
  final int xpPerLevel = 1000; // XP needed to level up
  int coins;
  int completedTasks;
  int streak; // Days in a row of completing tasks
  DateTime? lastTaskCompletedDate;
  // Tasks completed per weekday: index 0=Mon, 1=Tue, ..., 6=Sun
  /// Только для **текущей** календарной недели (понедельник–воскресенье, локальное время).
  List<int> weeklyActivity;
  List<int> weeklyXp;
  List<int> weeklyCoins;
  /// Локальный понедельник недели, к которой относятся столбцы (`yyyy-MM-dd`). Иначе столбец «Ср» смешивал вчера и сегодня.
  String? weeklyChartWeekMonday;
  /// Id из [kAchievementCatalog], дублируются в Firestore `unlockedAchievements`.
  List<String> unlockedAchievements;
  /// Встроенные награды магазина ([kDefaultShopRewards]), скрытые пользователем.
  List<String> shopHiddenBuiltinIds;
  /// Завершения задач целей с тегом «высокий» приоритет (для достижения «Мастер»).
  int highPriorityCompletions;
  /// Сколько раз отметили выполнение до 9:00 местного времени (задачи и привычки).
  int completionsBeforeNine;

  UserProfile({
    required this.id,
    required this.name,
    this.email,
    this.bio = '',
    this.photoUrl,
    this.level = 1,
    this.xp = 0,
    this.coins = 0,
    this.completedTasks = 0,
    this.streak = 0,
    this.lastTaskCompletedDate,
    List<int>? weeklyActivity,
    List<int>? weeklyXp,
    List<int>? weeklyCoins,
    this.weeklyChartWeekMonday,
    List<String>? unlockedAchievements,
    List<String>? shopHiddenBuiltinIds,
    this.highPriorityCompletions = 0,
    this.completionsBeforeNine = 0,
  }) : weeklyActivity = weeklyActivity ?? List.filled(7, 0),
       weeklyXp = weeklyXp ?? List.filled(7, 0),
       weeklyCoins = weeklyCoins ?? List.filled(7, 0),
       unlockedAchievements = List<String>.from(unlockedAchievements ?? []),
       shopHiddenBuiltinIds =
           List<String>.from(shopHiddenBuiltinIds ?? []);

  /// Ключ `yyyy-MM-dd` локального понедельника для [at].
  static String mondayKeyFor(DateTime at) {
    final day = DateTime(at.year, at.month, at.day);
    final monday =
        day.subtract(Duration(days: day.weekday - DateTime.monday));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  /// Если наступила новая календарная неделя (или первый запуск) — обнуляет столбцы и обновляет ключ.
  /// Возвращает `true`, если данные изменились и их стоит записать в Firestore.
  bool ensureWeeklyBucketsForCurrentWeek() {
    final key = mondayKeyFor(DateTime.now());
    if (weeklyChartWeekMonday == key) return false;
    for (var i = 0; i < 7; i++) {
      weeklyActivity[i] = 0;
      weeklyXp[i] = 0;
      weeklyCoins[i] = 0;
    }
    weeklyChartWeekMonday = key;
    return true;
  }
  int calculateLevel(int totalXp) {
    return (totalXp ~/ xpPerLevel) + 1;
  }

  // Get XP progress to next level (0-100%)
  int getXpProgressPercent() {
    final xpInCurrentLevel = xp % xpPerLevel;
    return ((xpInCurrentLevel / xpPerLevel) * 100).toInt();
  }

  // Add XP and auto-level up
  void addXp(int amount) {
    xp += amount;
    level = calculateLevel(xp);
  }

  // Add coins
  void addCoins(int amount) {
    coins += amount;
  }

  // Update streak when task is completed
  void updateStreak() {
    final today = DateTime.now();
    final isToday = lastTaskCompletedDate != null &&
        lastTaskCompletedDate!.year == today.year &&
        lastTaskCompletedDate!.month == today.month &&
        lastTaskCompletedDate!.day == today.day;

    if (!isToday) {
      final isYesterday = lastTaskCompletedDate != null &&
          lastTaskCompletedDate!.year == today.year &&
          lastTaskCompletedDate!.month == today.month &&
          lastTaskCompletedDate!.day == today.day - 1;

      if (isYesterday) {
        streak += 1;
      } else {
        streak = 1;
      }
    }

    lastTaskCompletedDate = today;
  }

  void incrementCompletedTasks() {
    completedTasks += 1;
  }

  // Increment today's weekday slot (Mon=0 .. Sun=6), только в рамках текущей календарной недели.
  void incrementWeeklyActivity({int xp = 0, int coins = 0}) {
    ensureWeeklyBucketsForCurrentWeek();
    final todayIndex = DateTime.now().weekday - 1;
    weeklyActivity[todayIndex] += 1;
    weeklyXp[todayIndex] += xp;
    weeklyCoins[todayIndex] += coins;
  }

  /// Откат начисления за день при снятии отметки с привычки (симметрия к одному вызову [incrementWeeklyActivity]).
  void decrementWeeklyActivity({int xp = 0, int coins = 0}) {
    ensureWeeklyBucketsForCurrentWeek();
    final todayIndex = DateTime.now().weekday - 1;
    if (weeklyActivity[todayIndex] > 0) {
      weeklyActivity[todayIndex] -= 1;
    }
    weeklyXp[todayIndex] = (weeklyXp[todayIndex] - xp);
    if (weeklyXp[todayIndex] < 0) weeklyXp[todayIndex] = 0;
    weeklyCoins[todayIndex] = (weeklyCoins[todayIndex] - coins);
    if (weeklyCoins[todayIndex] < 0) weeklyCoins[todayIndex] = 0;
  }

  // Get XP needed for next level
  int getXpForNextLevel() {
    return xpPerLevel - (xp % xpPerLevel);
  }

  /// Звание в профиле по данным из БД: [completedTasks], [level], [streak].
  ///
  /// Берётся **наивысший** ранг из трёх шкал (кто больше натянул — тот ранг и показываем).
  /// Пока нет ни одного завершённого дела ([completedTasks] == 0), ранг не выше
  /// «Начинающий» (даже при странном уровне в данных), без «Опытный» из ниоткуда.
  String get plannerRankTitle {
    int tierTasks(int t) {
      if (t <= 0) return 0;
      if (t < 10) return 1;
      if (t < 50) return 2;
      if (t < 150) return 3;
      return 4;
    }

    int tierLevel(int l) {
      if (l <= 1) return 0;
      if (l == 2) return 1;
      if (l <= 4) return 2;
      if (l <= 9) return 3;
      return 4;
    }

    /// Дни подряд с отметками (серия).
    int tierStreak(int s) {
      if (s <= 0) return 0;
      if (s < 7) return 1;
      if (s < 14) return 2;
      if (s < 30) return 3;
      return 4;
    }

    final tt = tierTasks(completedTasks);
    final tl = tierLevel(level);
    final ts = tierStreak(streak);
    final raw = max(tt, max(tl, ts));

    final int tier;
    if (completedTasks == 0) {
      tier = raw.clamp(0, 1);
    } else {
      tier = raw;
    }

    switch (tier) {
      case 0:
        return 'Новичок';
      case 1:
        return 'Начинающий планировщик';
      case 2:
        return 'Активный планировщик';
      case 3:
        return 'Опытный планировщик';
      default:
        return 'Мастер планирования';
    }
  }

  // Create copy with updates
  UserProfile copyWith({
    String? name,
    String? email,
    String? bio,
    String? photoUrl,
    int? level,
    int? xp,
    int? coins,
    int? completedTasks,
    int? streak,
    DateTime? lastTaskCompletedDate,
    List<int>? weeklyActivity,
    List<int>? weeklyXp,
    List<int>? weeklyCoins,
    String? weeklyChartWeekMonday,
    List<String>? unlockedAchievements,
    List<String>? shopHiddenBuiltinIds,
    int? highPriorityCompletions,
    int? completionsBeforeNine,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      completedTasks: completedTasks ?? this.completedTasks,
      streak: streak ?? this.streak,
      lastTaskCompletedDate: lastTaskCompletedDate ?? this.lastTaskCompletedDate,
      weeklyActivity: weeklyActivity ?? List.of(this.weeklyActivity),
      weeklyXp: weeklyXp ?? List.of(this.weeklyXp),
      weeklyCoins: weeklyCoins ?? List.of(this.weeklyCoins),
      weeklyChartWeekMonday:
          weeklyChartWeekMonday ?? this.weeklyChartWeekMonday,
      unlockedAchievements: unlockedAchievements ?? List.of(this.unlockedAchievements),
      shopHiddenBuiltinIds:
          shopHiddenBuiltinIds ?? List.of(this.shopHiddenBuiltinIds),
      highPriorityCompletions:
          highPriorityCompletions ?? this.highPriorityCompletions,
      completionsBeforeNine:
          completionsBeforeNine ?? this.completionsBeforeNine,
    );
  }
}
