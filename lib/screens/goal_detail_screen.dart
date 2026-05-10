import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/app_store.dart';
import '../models/task_model.dart';
import '../models/habit_model.dart';
import '../services/habit_service.dart';
import '../widgets/task_item_widget.dart';
import 'create_task_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final HabitService _habitService = HabitService();
  bool _attachingExistingTask = false;

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

    final rewardExplained = goalTasks.isEmpty
        ? 'Добавьте задачи и выполните цель полностью, чтобы получить награду.'
        : 'Когда все задачи будут выполнены, вы получите: '
            '+${goal.xpCompletionBonus} XP и +${goal.coinsCompletionBonus} монет.';

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

                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.emoji_events_outlined,
                                      color: AppColors.primaryDark, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Награда за цель',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                rewardExplained,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.38,
                                  color: AppColors.textMuted,
                                ),
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
                                onContentTap: t.completed
                                    ? null
                                    : () {
                                        Navigator.of(context).push<void>(
                                          MaterialPageRoute<void>(
                                            builder: (_) => CreateTaskScreen(
                                              isFullPage: true,
                                              taskToEdit: t,
                                            ),
                                          ),
                                        );
                                      },
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
                onTap: _openAddTaskActions,
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

  void _openAddTaskActions() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Добавить задачу в цель',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _actionTile(
                  icon: Icons.add_task_rounded,
                  title: 'Создать новую задачу',
                  subtitle: 'Откроется форма создания для этой цели',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => CreateTaskScreen(
                          isFullPage: true,
                          initialGoalId: widget.goalId,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _actionTile(
                  icon: Icons.playlist_add_check_rounded,
                  title: 'Привязать существующую задачу',
                  subtitle: 'Выберите из задач без цели',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showAttachExistingTasksSheet();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.bgMain,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
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

  void _showAttachExistingTasksSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (_, controller) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Text(
                        'Существующие задачи',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppColors.textDark),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<HabitModel>>(
                    stream: _habitService.getHabits(),
                    builder: (context, snap) {
                      final list = (snap.data ?? const <HabitModel>[])
                          .where((h) => !h.completed)
                          .toList(growable: false);
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (list.isEmpty) {
                        return Center(
                          child: Text(
                            'Нет подходящих задач без цели',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }
                      return ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final h = list[i];
                          return Material(
                            color: AppColors.bgMain,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _pickPriorityAndAttach(h, ctx),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(Icons.task_alt_rounded,
                                        color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            h.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          if (h.notes.trim().isNotEmpty)
                                            Text(
                                              h.notes.trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded,
                                        color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickPriorityAndAttach(HabitModel habit, BuildContext sheetCtx) async {
    if (_attachingExistingTask) return;
    int selectedPriority = 1; // medium default
    final options = <(int, String, Color)>[
      (0, 'Низкий', AppColors.blue),
      (1, 'Средний', AppColors.primary),
      (2, 'Высокий', AppColors.warning),
    ];
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.bgWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Выберите приоритет',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: options
                        .map(
                          (entry) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: entry.$1 == options.last.$1 ? 0 : 8),
                              child: Material(
                                color: selectedPriority == entry.$1
                                    ? entry.$3.withValues(alpha: 0.18)
                                    : AppColors.bgMain,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setLocal(() {
                                    selectedPriority = entry.$1;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selectedPriority == entry.$1
                                            ? entry.$3
                                            : AppColors.borderDark,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        entry.$2,
                                        style: TextStyle(
                                          color: selectedPriority == entry.$1
                                              ? entry.$3
                                              : AppColors.textDark,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(selectedPriority),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Добавить в цель'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (chosen == null) return;
    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
    if (!mounted) return;
    setState(() => _attachingExistingTask = true);
    try {
      await _attachExistingHabitToGoal(habit, chosen);
    } catch (e, st) {
      debugPrint('Attach existing task error: $e\n$st');
      if (mounted) {
        _showSnack('Не удалось привязать задачу. Попробуйте снова.');
      }
    } finally {
      if (mounted) setState(() => _attachingExistingTask = false);
    }
  }

  Future<void> _attachExistingHabitToGoal(HabitModel habit, int priority) async {
    final store = AppStore.instance;
    final goalIndex = store.goals.indexWhere((g) => g.id == widget.goalId);
    if (goalIndex == -1) return;
    final goal = store.goals[goalIndex];
    final tag = TaskTag(
      text: priority == 2 ? 'Высокий' : (priority == 0 ? 'Низкий' : 'Средний'),
      type: priority == 2
          ? TagType.high
          : (priority == 0 ? TagType.repeat : TagType.medium),
    );
    final when = habit.deadline ?? DateTime.now().add(const Duration(hours: 1));
    final task = TaskModel(
      id: 'task_${DateTime.now().microsecondsSinceEpoch}_${priority}_${habit.id ?? 'h'}',
      title: habit.title,
      subtitle: habit.notes.trim().isEmpty ? 'Цель: ${goal.title}' : habit.notes.trim(),
      goalId: widget.goalId,
      scheduledAt: when,
      reward: 0,
      isXp: true,
      tag: tag,
    );
    await store.addTask(task).timeout(const Duration(seconds: 20));
    if (habit.id != null && habit.id!.isNotEmpty) {
      await _habitService.deleteHabit(habit.id!).timeout(const Duration(seconds: 20));
    }
    _showSnack('Задача привязана к цели');
  }

  void _toggleTask(TaskModel task, List<TaskModel> goalTasks) {
    final store = AppStore.instance;
    final willComplete = !task.completed;
    final xpAward = store.xpRewardForGoalTask(task);
    final reward = willComplete ? xpAward : task.reward;

    final updatedTask = task.copyWith(
      completed: willComplete,
      reward: reward,
      isXp: true,
    );

    store.updateTask(updatedTask);

    if (willComplete) {
      _showSnack('+$xpAward XP за задачу!');
    }
  }

}
