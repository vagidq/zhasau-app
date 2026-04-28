enum GoalColor { warning, blue, success }

class GoalModel {
  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final String iconName;
  final GoalColor color;
  final int progress;
  final int tasksLeft;
  final DateTime? deadline;
  final DateTime startDate;
  final String? calendarEventId;

  GoalModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.iconName,
    required this.color,
    required this.progress,
    required this.tasksLeft,
    this.deadline,
    DateTime? startDate,
    this.calendarEventId,
  }) : startDate = startDate ?? DateTime.now();

  /// True while deadline hasn't passed (or no deadline set).
  bool get isActive =>
      deadline == null || DateTime.now().isBefore(deadline!);

  GoalModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? badge,
    String? iconName,
    GoalColor? color,
    int? progress,
    int? tasksLeft,
    DateTime? deadline,
    DateTime? startDate,
    String? calendarEventId,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      badge: badge ?? this.badge,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      progress: progress ?? this.progress,
      tasksLeft: tasksLeft ?? this.tasksLeft,
      deadline: deadline ?? this.deadline,
      startDate: startDate ?? this.startDate,
      calendarEventId: calendarEventId ?? this.calendarEventId,
    );
  }
}