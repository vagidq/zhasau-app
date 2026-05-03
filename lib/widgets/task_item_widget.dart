import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../models/task_model.dart';

class TaskItemWidget extends StatefulWidget {
  final TaskModel task;
  final VoidCallback onToggle;

  /// Тап по текстовой части карточки (не по чекбоксу) — открыть экран как при создании.
  final VoidCallback? onContentTap;

  const TaskItemWidget({
    super.key,
    required this.task,
    required this.onToggle,
    this.onContentTap,
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
    return AnimatedOpacity(
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
            // Только чекбокс завершает задачу (не всё пустое место карточки).
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
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
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Контент: опционально открывает полный экран редактирования (тап по области текста).
            Expanded(
              child: Builder(
                builder: (context) {
                  final body = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                          _rewardWidget(task),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            task.isXp
                                ? Icons.bar_chart_rounded
                                : Icons.access_time_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          if (task.tag != null) ...[
                            const SizedBox(width: 8),
                            _tagWidget(task.tag!),
                          ],
                        ],
                      ),
                    ],
                  );

                  final canOpenEditor =
                      widget.onContentTap != null && !task.completed;
                  if (!canOpenEditor) return body;

                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onContentTap!();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: body,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardWidget(TaskModel task) {
    if (task.reward == 0) {
      return Text(
        '0',
        style: TextStyle(
          color: AppColors.textLight,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      );
    }
    if (task.isXp) {
      return Text(
        '+${task.reward} XP',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      );
    }
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
