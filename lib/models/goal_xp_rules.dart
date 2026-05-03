import 'dart:math' as math;

import 'task_model.dart';

/// Единая логика XP для задач внутри цели (пул делится между задачами × приоритет).
class GoalXpRules {
  GoalXpRules._();

  /// Сколько XP всего распределяется между **всеми** задачами цели (без бонуса за финиш).
  static const int defaultTaskPool = 500;

  /// Бонус за выполнение **всех** задач цели (один раз за цикл, пока снова не появятся незавершённые).
  static const int defaultCompletionBonus = 150;

  static const List<double> priorityMultipliers = [0.82, 1.0, 1.28];

  static double multiplierFromTag(TaskTag? tag) {
    if (tag == null) return 1.0;
    if (tag.type == TagType.high) return priorityMultipliers[2];
    if (tag.type == TagType.repeat) return priorityMultipliers[0];
    if (tag.text.contains('Низкий')) return priorityMultipliers[0];
    return priorityMultipliers[1];
  }

  /// Доля пула на одну задачу до множителя приоритета.
  static int baseSharePerTask(int pool, int taskCount) {
    if (taskCount <= 0) return 0;
    return (pool / taskCount).round();
  }

  static int taskXp({
    required int pool,
    required int taskCount,
    TaskTag? tag,
  }) {
    if (taskCount <= 0) return 0;
    final base = baseSharePerTask(pool, taskCount);
    final m = multiplierFromTag(tag);
    return math.max(5, (base * m).round());
  }
}
