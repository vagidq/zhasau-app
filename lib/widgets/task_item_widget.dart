import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../models/task_model.dart';

class TaskItemWidget extends StatefulWidget {
  final TaskModel task;
  final VoidCallback onToggle;

  const TaskItemWidget({
    super.key,
    required this.task,
    required this.onToggle,
  });

  @override
  State<TaskItemWidget> createState() => _TaskItemWidgetState();
}

class _TaskItemWidgetState extends State<TaskItemWidget> {
  bool _tapped = false;

  void _handleTap() {
    if (_tapped) return;
    _tapped = true;
    HapticFeedback.lightImpact();
    widget.onToggle();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _tapped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedOpacity(
        opacity: task.completed ? 0.65 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), blurRadius: 10),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color:
                      task.completed ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: task.completed
                        ? AppColors.primary
                        : AppColors.primaryLight,
                    width: 2,
                  ),
                ),
                child: task.completed
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Title
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: task.completed
                                  ? AppColors.textMuted
                                  : AppColors.textDark,
                              decoration: task.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        // Reward
                        _rewardWidget(task),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Meta row
                    Row(
                      children: [
                        Icon(
                          task.isXp
                              ? Icons.bar_chart_rounded
                              : Icons.access_time_rounded,
                          size: 14,
                          color: _getSubtitleColor(task.subtitle, task.priority),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: _getSubtitleColor(task.subtitle, task.priority),
                          ),
                        ),
                        if (task.tag != null) ...[
                          const SizedBox(width: 8),
                          _tagWidget(task.tag!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rewardWidget(TaskModel task) {
    // Coins + XP (tasks created via CreateTaskScreen)
    if (!task.isXp && task.reward > 0 && task.xpReward > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+${task.reward}',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.toll_rounded, color: AppColors.yellow, size: 14),
            ],
          ),
          Text(
            '+${task.xpReward} XP',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      );
    }
    // Only XP (legacy goal tasks)
    if (task.isXp && task.reward > 0) {
      return Text(
        '+${task.reward} XP',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      );
    }
    // Only coins
    if (!task.isXp && task.reward > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+${task.reward}',
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.toll_rounded, color: AppColors.yellow, size: 16),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _tagWidget(TaskTag tag) {
    switch (tag.type) {
      case TagType.high:
        return _badge(
            tag.text,
            AppColors.redLight,
            AppColors.red,
            null);
      case TagType.medium:
        return _badge(
            tag.text,
            AppColors.warningLight,
            AppColors.warning,
            null);
      case TagType.low:
        return _badge(
            tag.text,
            AppColors.blueLight,
            AppColors.blue,
            null);
      case TagType.repeat:
        return _badge(
            tag.text,
            AppColors.primaryLight,
            AppColors.primary,
            Icons.repeat_rounded);
    }
  }

  Color _getSubtitleColor(String subtitle, int priority) {
    if (subtitle == 'Низкий' || subtitle == 'Средний' || subtitle == 'Высокий') {
      if (priority == 0) return AppColors.blue;
      if (priority == 1) return AppColors.warning;
      if (priority == 2) return AppColors.red;
    }
    return AppColors.textMuted;
  }

  Widget _badge(String text, Color bg, Color fg, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: 12),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
