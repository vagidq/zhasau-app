enum TagType { low, medium, high, repeat }

class TaskTag {
  final String text;
  final TagType type;

  const TaskTag({required this.text, required this.type});
}

class TaskModel {
  final String id;
  final String title;
  final String subtitle;
  final String? goalId;
  final num reward;   // монеты
  final int xpReward; // XP
  final bool isXp;   // legacy: для задач из цели где нет монет — reward это XP
  final TaskTag? tag;
  final int priority; // 0=Низкий, 1=Средний, 2=Высокий
  bool completed;

  TaskModel({
    required this.id,
    required this.title,
    required this.subtitle,
    this.goalId,
    required this.reward,
    this.xpReward = 0,
    required this.isXp,
    this.tag,
    this.priority = 1,
    this.completed = false,
  });

  TaskModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? goalId,
    num? reward,
    int? xpReward,
    bool? isXp,
    TaskTag? tag,
    int? priority,
    bool? completed,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      goalId: goalId ?? this.goalId,
      reward: reward ?? this.reward,
      xpReward: xpReward ?? this.xpReward,
      isXp: isXp ?? this.isXp,
      tag: tag ?? this.tag,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
    );
  }
}
