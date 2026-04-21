import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/app_store.dart';
import '../models/task_model.dart';
import '../widgets/task_item_widget.dart';
import 'create_task_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    setState(() {});
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final goalIndex = store.goals.indexWhere((g) => g.id == widget.goalId);
    if (goalIndex == -1) {
      return const Scaffold(body: Center(child: Text('Цель не найдена')));
    }
    final goal = store.goals[goalIndex];
    final goalTasks = store.getTasksForGoal(widget.goalId);
    final progress = store.goalProgressPercent(widget.goalId);

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
                      const SizedBox(width: 40),
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
                                    child: Text(
                                      progress == 100
                                          ? 'Выполнено!'
                                          : progress >= 50
                                              ? 'Почти у цели!'
                                              : 'В процессе',
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
                                  '$progress%',
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
                                  value: progress / 100.0,
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
                              '${goalTasks.where((t) => !t.completed).length} АКТИВНЫХ',
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

                        if (goalTasks.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.bgWhite,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.add_task_rounded,
                                      size: 36, color: AppColors.textLight),
                                  const SizedBox(height: 8),
                                  Text('Нет задач. Нажмите + чтобы добавить',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        ...goalTasks.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Dismissible(
                              key: Key(t.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  color: AppColors.red,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    title: const Text('Удалить задачу?'),
                                    content: Text(
                                        'Задача «${t.title}» будет удалена.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: Text('Отмена',
                                            style: TextStyle(
                                                color: AppColors.textMuted)),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: Text('Удалить',
                                            style: TextStyle(
                                                color: AppColors.red,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                ) ??
                                    false;
                              },
                              onDismissed: (_) {
                                AppStore.instance.deleteTask(t.id);
                              },
                              child: TaskItemWidget(
                                task: t,
                                onToggle: () => _toggleTask(t, goalTasks),
                              ),
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
                onTap: () => _navigateToCreateTask(context),
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

  void _toggleTask(TaskModel task, List<TaskModel> goalTasks) {
    AppStore.instance.updateTask(task.copyWith(completed: !task.completed));

    if (!task.completed) {
      // was uncompleted, now completing — show reward from the task itself
      if (!task.isXp && task.reward > 0) {
        _showSnack('+${task.reward} монет за задачу!');
      } else if (task.isXp && task.reward > 0) {
        _showSnack('+${task.reward} XP за задачу!');
      } else {
        _showSnack('Задача выполнена!');
      }
    }
  }

  void _navigateToCreateTask(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateTaskScreen(
          isFullPage: true,
          initialGoalId: widget.goalId,
        ),
      ),
    );
  }
}
