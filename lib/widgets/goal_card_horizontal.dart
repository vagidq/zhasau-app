import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/goal_model.dart';
import '../models/app_store.dart';

class GoalCardHorizontal extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback onTap;

  const GoalCardHorizontal({
    super.key,
    required this.goal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _goalColors(goal.color);
    final progress = AppStore.instance.goalProgressPercent(goal.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x05000000), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(colors.icon, color: colors.fg, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              goal.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$progress% завершено',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress / 100.0,
                minHeight: 6,
                backgroundColor: AppColors.borderDark,
                valueColor: AlwaysStoppedAnimation(colors.fg),
              ),
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
