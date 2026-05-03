// ─── Models ───────────────────────────────────────────────────────────────

class UserModel {
  final String name;
  int level;
  int xp;
  final int xpMax;
  int coins;
  int streak;

  UserModel({
    required this.name,
    required this.level,
    required this.xp,
    required this.xpMax,
    required this.coins,
    required this.streak,
  });
}

class GoalModel {
  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final String iconName;
  final GoalColor color;
  final int progress;
  final int tasksLeft;

  const GoalModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.iconName,
    required this.color,
    required this.progress,
    required this.tasksLeft,
  });
}

enum GoalColor { warning, blue, success }

class TaskModel {
  final String id;
  final String title;
  final String subtitle;
  final String? goalId;
  final num reward;
  final bool isXp;
  final TaskTag? tag;
  bool completed;

  TaskModel({
    required this.id,
    required this.title,
    required this.subtitle,
    this.goalId,
    required this.reward,
    required this.isXp,
    this.tag,
    this.completed = false,
  });
}

class TaskTag {
  final String text;
  final TagType type;

  const TaskTag({required this.text, required this.type});
}

enum TagType { high, medium, repeat }

// ─── Mock Data ────────────────────────────────────────────────────────────

class MockData {
  static UserModel user = UserModel(
    name: 'Дамир',
    level: 12,
    xp: 750,
    xpMax: 1000,
    coins: 450,
    streak: 7,
  );

  static final List<GoalModel> goals = [
    const GoalModel(
      id: 'g1',
      title: 'Спорт',
      subtitle: 'Марафон 2024',
      badge: 'до 12 дек',
      iconName: 'fitness',
      color: GoalColor.warning,
      progress: 60,
      tasksLeft: 3,
    ),
    const GoalModel(
      id: 'g2',
      title: 'Учёба',
      subtitle: 'Английский B2',
      badge: 'до 20 авг',
      iconName: 'book',
      color: GoalColor.blue,
      progress: 40,
      tasksLeft: 12,
    ),
    const GoalModel(
      id: 'g3',
      title: 'Карьера',
      subtitle: 'Senior Designer',
      badge: 'до 30 сен',
      iconName: 'work',
      color: GoalColor.success,
      progress: 20,
      tasksLeft: 8,
    ),
  ];

  static final List<TaskModel> tasks = [
    TaskModel(
      id: 't1',
      title: 'Пробежка 5км',
      subtitle: 'Утро • Спорт',
      goalId: 'g1',
      reward: 20,
      isXp: true,
      tag: const TaskTag(text: 'HIGH', type: TagType.high),
    ),
    TaskModel(
      id: 't2',
      title: 'Урок английского',
      subtitle: '14:00 • Учёба',
      goalId: 'g2',
      reward: 50,
      isXp: true,
      completed: true,
    ),
    TaskModel(
      id: 't3',
      title: 'Медитация',
      subtitle: 'Вечер • Ментальное',
      reward: 10,
      isXp: false,
      tag: const TaskTag(text: 'Ежедневно', type: TagType.repeat),
    ),
    TaskModel(
      id: 't4',
      title: 'Утренняя зарядка',
      subtitle: 'Утро • Спорт',
      goalId: 'g1',
      reward: 5,
      isXp: false,
      tag: const TaskTag(text: 'Ежедневно', type: TagType.repeat),
    ),
    TaskModel(
      id: 't5',
      title: 'Купить кроссовки',
      subtitle: 'Разово',
      goalId: 'g1',
      reward: 0,
      isXp: false,
      tag: const TaskTag(text: 'MEDIUM', type: TagType.medium),
    ),
  ];
}
