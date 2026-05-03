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

  /// Ключ для вкладок «Здоровье» / «Образование» … (строго в нижнем регистре).
  /// Совпадает с тем, как карточка выводит категорию (iconName + запасной цвет).
  String get categoryFilterKey {
    final raw = iconName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    const ru = {'здоровье', 'образование', 'карьера', 'хобби'};
    if (ru.contains(raw)) return raw;
    if (raw == 'fitness' || raw == 'health') return 'здоровье';
    if (raw == 'education' || raw == 'book') return 'образование';
    if (raw == 'career' || raw == 'work') return 'карьера';
    if (raw == 'hobby' || raw == 'palette') return 'хобби';
    switch (color) {
      case GoalColor.warning:
        return 'здоровье';
      case GoalColor.blue:
        return 'образование';
      case GoalColor.success:
        return 'карьера';
    }
  }

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