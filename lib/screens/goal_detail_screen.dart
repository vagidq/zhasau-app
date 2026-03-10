import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../data/mock_data.dart';
import '../widgets/task_item_widget.dart';
import 'main_shell.dart';

class GoalDetailScreen extends StatefulWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final goal =
        MockData.goals.firstWhere((g) => g.id == widget.goalId);
    final goalTasks =
        MockData.tasks.where((t) => t.goalId == widget.goalId).toList();
    final progressVal = goal.progress / 100.0;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            goal.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            MainShell.of(context).showToast('Опции цели'),
                        child: Icon(Icons.more_horiz_rounded,
                            size: 26, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progress card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.bgWhite,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Прогресс цели',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text('Почти у цели!',
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${goal.progress}%',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progressVal,
                                  minHeight: 8,
                                  backgroundColor: AppColors.primaryLight,
                                  valueColor:
                                      AlwaysStoppedAnimation(
                                          AppColors.primary),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Начало',
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13)),
                                  Text('Завершено',
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Tasks section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Список задач',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${goalTasks.length} АКТИВНЫХ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...goalTasks.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TaskItemWidget(
                              task: t,
                              onToggle: () {
                                _toggleTask(t);
                                setState(() {});
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // FAB
            Positioned(
              right: 20,
              bottom: 20,
              child: GestureDetector(
                onTap: () =>
                    MainShell.of(context).showToast('Создать задачу'),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x669333EA),
                        blurRadius: 25,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleTask(task) {
    task.completed = !task.completed;
    if (task.completed) {
      if (task.isXp) {
        MockData.user.xp = (MockData.user.xp + task.reward).toInt();
        MainShell.of(context).showToast('+${task.reward} XP!');
      } else if (task.reward > 0) {
        MockData.user.coins = (MockData.user.coins + task.reward).toInt();
        MainShell.of(context).showToast('+${task.reward} монет!');
      } else {
        MainShell.of(context).showToast('Задача выпонена!');
      }
    } else {
      if (task.isXp) {
        MockData.user.xp = (MockData.user.xp - task.reward).toInt();
      } else {
        MockData.user.coins = (MockData.user.coins - task.reward).toInt();
      }
    }
  }
}
