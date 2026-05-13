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
  /// Начало слота в календаре (задачи цели); для старых записей может быть null.
  final DateTime? scheduledAt;
  /// ID события в Google Calendar после синка.
  final String? calendarEventId;
  final num reward;
  final bool isXp;
  final TaskTag? tag;
  bool completed;
  /// Локальное время отметки «выполнено» (для симметричного отката [UserProfile.completionsBeforeNine]).
  final DateTime? completedAt;

  /// Выполненная задача цели скрыта с главного экрана свайпом; в цели по-прежнему видна.
  final bool dismissedFromHome;

  TaskModel({
    required this.id,
    required this.title,
    required this.subtitle,
    this.goalId,
    this.scheduledAt,
    this.calendarEventId,
    required this.reward,
    required this.isXp,
    this.tag,
    this.completed = false,
    this.completedAt,
    this.dismissedFromHome = false,
  });

  TaskModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? goalId,
    DateTime? scheduledAt,
    String? calendarEventId,
    num? reward,
    bool? isXp,
    TaskTag? tag,
    bool? completed,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? dismissedFromHome,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      goalId: goalId ?? this.goalId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      calendarEventId: calendarEventId ?? this.calendarEventId,
      reward: reward ?? this.reward,
      isXp: isXp ?? this.isXp,
      tag: tag ?? this.tag,
      completed: completed ?? this.completed,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      dismissedFromHome: dismissedFromHome ?? this.dismissedFromHome,
    );
  }
}