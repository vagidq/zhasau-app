import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../data/mock_data.dart';

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
    final colors = _goalColors(goal.color);
    final categoryLabel = _categoryLabel(goal.color);

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
                        goal.subtitle,
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
                    goal.badge,
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
                  '${goal.progress}%',
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
                value: goal.progress / 100.0,
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
                      '${goal.tasksLeft} задачи осталось',
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
                    child: const Text('Подробнее',
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
  _GoalColors({required this.bg, required this.fg, required this.icon});
}

_GoalColors _goalColors(GoalColor c) {
  switch (c) {
    case GoalColor.warning:
      return _GoalColors(
          bg: AppColors.warningLight,
          fg: AppColors.warning,
          icon: Icons.fitness_center_rounded);
    case GoalColor.blue:
      return _GoalColors(
          bg: AppColors.blueLight,
          fg: AppColors.blue,
          icon: Icons.menu_book_rounded);
    case GoalColor.success:
      return _GoalColors(
          bg: AppColors.successLight,
          fg: AppColors.success,
          icon: Icons.work_rounded);
  }
}

String _categoryLabel(GoalColor c) {
  switch (c) {
    case GoalColor.warning:
      return 'ЗДОРОВЬЕ';
    case GoalColor.blue:
      return 'ОБРАЗОВАНИЕ';
    case GoalColor.success:
      return 'КАРЬЕРА';
  }
}
