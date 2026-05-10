import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../theme/app_colors.dart';

/// Стабильные id для поля Firestore `unlockedAchievements`.
class AchievementIds {
  AchievementIds._();

  static const earlyBird = 'early_bird';
  static const weekStreak = 'week_streak';
  static const level10 = 'level_10';
  static const priorityMaster = 'priority_master';
}

class AchievementItem {
  final String id;
  final IconData icon;
  /// Короткая подпись под иконкой (можно с \n).
  final String label;
  final String description;
  final Color color;
  final Color iconColor;

  AchievementItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.iconColor,
  });
}

/// Каталог пересобирается при обращении — цвета [AppColors] актуальны для светлой/тёмной темы.
List<AchievementItem> get kAchievementCatalog => [
  AchievementItem(
    id: AchievementIds.earlyBird,
    icon: Icons.wb_sunny_rounded,
    label: 'Ранняя\nпташка',
    description:
        'Завершить 5 задач или привычек до 9:00 по местному времени (каждое завершение до 9:00 считается).',
    color: AppColors.warningLight,
    iconColor: AppColors.warning,
  ),
  AchievementItem(
    id: AchievementIds.weekStreak,
    icon: Icons.directions_run_rounded,
    label: 'Марафонец',
    description:
        'Серия из 7 календарных дней подряд (счётчик «Серия»). График ниже — только текущая неделя Пн–Вс.',
    color: AppColors.primaryLight,
    iconColor: AppColors.primary,
  ),
  AchievementItem(
    id: AchievementIds.level10,
    icon: Icons.workspace_premium_rounded,
    label: 'Эксперт',
    description: 'Достичь 10 уровня (суммарный опыт в профиле).',
    color: AppColors.blueLight,
    iconColor: AppColors.blue,
  ),
  AchievementItem(
    id: AchievementIds.priorityMaster,
    icon: Icons.emoji_events_rounded,
    label: 'Мастер',
    description: 'Завершить 100 задач целей с тегом «Высокий» приоритет.',
    color: AppColors.warningLight,
    iconColor: AppColors.warning,
  ),
];

bool achievementConditionMet(String id, UserProfile profile) {
  switch (id) {
    case AchievementIds.earlyBird:
      return profile.completionsBeforeNine >= 5;
    case AchievementIds.weekStreak:
      return profile.streak >= 7;
    case AchievementIds.level10:
      return profile.level >= 10;
    case AchievementIds.priorityMaster:
      return profile.highPriorityCompletions >= 100;
    default:
      return false;
  }
}

/// Условие выполнено, но id ещё не в списке разблокированных.
List<String> newlyUnlockedAchievementIds(UserProfile profile) {
  final have = profile.unlockedAchievements.toSet();
  final out = <String>[];
  for (final item in kAchievementCatalog) {
    if (!have.contains(item.id) && achievementConditionMet(item.id, profile)) {
      out.add(item.id);
    }
  }
  return out;
}
