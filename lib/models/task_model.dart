enum TagType { high, medium, repeat }

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

  TaskModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? goalId,
    num? reward,
    bool? isXp,
    TaskTag? tag,
    bool? completed,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      goalId: goalId ?? this.goalId,
      reward: reward ?? this.reward,
      isXp: isXp ?? this.isXp,
      tag: tag ?? this.tag,
      completed: completed ?? this.completed,
    );
  }
}