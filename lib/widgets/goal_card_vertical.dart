import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/goal_model.dart';
import '../models/app_store.dart';

class GoalCardVertical extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback onTap;

  const GoalCardVertical({
    super.key,
    required this.goal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final progress = store.goalProgressPercent(goal.id);
    final tasksLeft = store.tasksLeft(goal.id);
    final colors = _goalColors(goal.color);
    final categoryLabel = _categoryLabel(goal);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x05000000), blurRadius: 10),
          ],
        ),
        child: Column(
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(colors.icon, color: colors.fg, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.fg,
                          letterSpacing: 0.5,
                          textBaseline: TextBaseline.alphabetic,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goal.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    goal.deadline != null
                        ? _deadlineBadgeText(goal.deadline!)
                        : 'Без срока',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            // Progress row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Прогресс',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$progress%',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress / 100.0,
                minHeight: 8,
                backgroundColor: AppColors.primaryLight,
                valueColor:
                    AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),

            const SizedBox(height: 16),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '$tasksLeft задач осталось',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Открыть',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalColors {
  final Color bg;
  final Color fg;
  final IconData icon;

  const _GoalColors({required this.bg, required this.fg, required this.icon});
}

_GoalColors _goalColors(GoalColor c) {
  switch (c) {
    case GoalColor.warning:
      return const _GoalColors(
        bg: Color(0xFFFFF3CD),
        fg: Color(0xFF856404),
        icon: Icons.fitness_center_rounded,
      );
    case GoalColor.blue:
      return const _GoalColors(
        bg: Color(0xFFD1ECF1),
        fg: Color(0xFF0C5460),
        icon: Icons.book_rounded,
      );
    case GoalColor.success:
      return const _GoalColors(
        bg: Color(0xFFD4EDDA),
        fg: Color(0xFF155724),
        icon: Icons.work_rounded,
      );
  }
}

String _deadlineBadgeText(DateTime d) {
  const months = <String>[
    '',
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];
  final m = months[d.month];
  final y = DateTime.now().year;
  if (d.year == y) {
    return 'до ${d.day} $m';
  }
  return 'до ${d.day} $m ${d.year}';
}

String _categoryLabel(GoalModel goal) {
  switch (goal.iconName.toLowerCase().trim()) {
    case 'хобби':
      return 'ХОББИ';
    case 'образование':
      return 'ОБРАЗОВАНИЕ';
    case 'карьера':
      return 'КАРЬЕРА';
    case 'здоровье':
      return 'ЗДОРОВЬЕ';
    default:
      switch (goal.color) {
        case GoalColor.warning:
          return 'ЗДОРОВЬЕ';
        case GoalColor.blue:
          return 'ОБРАЗОВАНИЕ';
        case GoalColor.success:
          return 'КАРЬЕРА';
      }
  }
}
