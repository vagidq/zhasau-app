import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/app_store.dart';
import '../models/habit_model.dart';
import '../models/task_model.dart' as tm;
import '../services/habit_service.dart';
import '../services/google_calendar_service.dart';
import '../widgets/goal_card_horizontal.dart';
import '../widgets/task_item_widget.dart';
import 'main_shell.dart';
import 'goal_detail_screen.dart';
import 'create_task_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final HabitService _habitService = HabitService();
  final Set<String> _pendingDelete = {};
  final Map<String, Timer> _deleteTimers = {};
  final Set<String> _dismissed = {};

  final _quickAddController = TextEditingController();
  final _quickAddFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Listen to AppStore changes to update UI when profile changes
    AppStore.instance.addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    print('DEBUG: _onStoreChanged called');
    if (mounted) {
      print('DEBUG: setState called, mounted=true');
      setState(() {});
    }
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_onStoreChanged);
    _quickAddController.dispose();
    _quickAddFocus.dispose();
    for (final t in _deleteTimers.values) t.cancel();
    _deleteTimers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: DashboardScreen.build called');
    final user = AppStore.instance.userProfile;
    final xpPercent = user.getXpProgressPercent() / 100.0;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top Bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: Image.network(
                        'https://i.pravatar.cc/150?img=11',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(Icons.person, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Zhasau',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _IconBtnLight(
                    icon: Icons.notifications_none_rounded,
                    onTap: () =>
                        MainShell.of(context).showToast('Уведомления пусты'),
                  ),
                ],
              ),
            ),

            // ─── Scrollable content ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bgWhite,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x05000000),
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                              children: [
                                const TextSpan(text: 'Привет, '),
                                TextSpan(
                                  text: '${user.name}!',
                                  style: TextStyle(
                                      color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Stats row
                          Row(
                            children: [
                              Text(
                                'Уровень ${user.level}',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              _vDivider(),
                              Row(
                                children: [
                                  Text(
                                    '${user.coins}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.toll_rounded,
                                      color: AppColors.yellow, size: 18),
                                ],
                              ),
                              _vDivider(),
                              Row(
                                children: [
                                  Text(
                                    '${user.streak} дней',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.local_fire_department,
                                      color: Color(0xFFF97316), size: 18),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // XP row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Опыт (XP)',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${(xpPercent * 100).round()}%',
                                style: TextStyle(
                                  color: AppColors.primary,
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
                              value: xpPercent,
                              minHeight: 8,
                              backgroundColor: AppColors.primaryLight,
                              valueColor: AlwaysStoppedAnimation(
                                  AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'До уровня ${user.level + 1} осталось ${user.getXpForNextLevel()} XP',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick add box — настоящий TextFiled с клавиатурой
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                      decoration: BoxDecoration(
                        color: AppColors.bgWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryLight),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x05943EEA),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quickAddController,
                              focusNode: _quickAddFocus,
                              decoration: InputDecoration(
                                hintText: 'Что нужно сделать?',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                hintStyle: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 15,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textDark,
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (text) => _submitQuickAdd(text),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _submitQuickAdd(
                                _quickAddController.text),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Active Goals
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Активные цели',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => MainShell.of(context).setIndex(1),
                          child: Text('Все',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Builder(builder: (context) {
                      final activeGoals = AppStore.instance.goals
                          .where((g) =>
                              g.isActive &&
                              AppStore.instance.goalProgressPercent(g.id) < 100)
                          .toList();
                      if (activeGoals.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Нет активных целей',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }
                      return SizedBox(
                        height: 185,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: activeGoals.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 16),
                          itemBuilder: (_, i) => GoalCardHorizontal(
                            goal: activeGoals[i],
                            onTap: () => _openGoal(activeGoals[i]),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    // Today Tasks
                    StreamBuilder<List<HabitModel>>(
                      stream: _habitService.getHabits(),
                      builder: (context, snapshot) {
                        final habits = snapshot.data ?? const <HabitModel>[];
                        final today = DateTime.now();

                        // Active: not completed, not expired, not pending, not dismissed
                        final activeHabits = habits
                            .where((h) =>
                                !h.completed &&
                                !h.isExpired &&
                                h.completedAt == null &&
                                !_pendingDelete.contains(h.id) &&
                                !_dismissed.contains(h.id))
                            .take(3)
                            .toList();

                        // Completed today
                        final completedHabits = habits
                            .where((h) =>
                                h.completedAt != null &&
                                h.completedAt!.year == today.year &&
                                h.completedAt!.month == today.month &&
                                h.completedAt!.day == today.day)
                            .toList();

                        // Expired quick tasks (deadline passed, not completed, not dismissed)
                        final expiredHabits = habits
                            .where((h) =>
                                h.isExpired &&
                                !_dismissed.contains(h.id))
                            .toList();

                        // All tasks from AppStore
                        final activeStoreTasks = AppStore.instance.tasks
                            .where((t) => !t.completed)
                            .toList();
                        final completedStoreTasks = AppStore.instance.tasks
                            .where((t) => t.completed)
                            .toList();

                        final totalActive = activeHabits.length + activeStoreTasks.length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Header ──────────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Задачи на сегодня',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('$totalActive задач',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ── AppStore active standalone tasks ─────────
                            for (final task in activeStoreTasks)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Dismissible(
                                  key: Key('store_${task.id}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: AppColors.red,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.white,
                                        size: 24),
                                  ),
                                  onDismissed: (_) =>
                                      AppStore.instance.deleteTask(task.id),
                                  child: TaskItemWidget(
                                    task: task,
                                    onToggle: () => _completeStoreTask(task),
                                  ),
                                ),
                              ),

                            // ── Active habits ────────────────────────────
                            if (snapshot.hasError)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Ошибка загрузки привычек',
                                  style: TextStyle(color: AppColors.red),
                                ),
                              )
                            else if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                habits.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (activeHabits.isEmpty &&
                                completedHabits.isEmpty &&
                                expiredHabits.isEmpty &&
                                activeStoreTasks.isEmpty &&
                                completedStoreTasks.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Пока нет задач',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              )
                            else ...[
                              for (final habit in activeHabits)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Dismissible(
                                    key: Key(habit.id ?? habit.title),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: AppColors.red,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white,
                                          size: 24),
                                    ),
                                    onDismissed: (_) {
                                      setState(() => _dismissed.add(habit.id ?? ''));
                                      _habitService.deleteHabit(habit.id ?? '');
                                    },
                                    child: TaskItemWidget(
                                      task: _habitToTask(habit),
                                      onToggle: () => _toggleHabit(habit),
                                    ),
                                  ),
                                ),

                              // ── Completed today section ──────────────
                              if (completedHabits.isNotEmpty || completedStoreTasks.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded,
                                        size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Выполнено · ${completedHabits.length + completedStoreTasks.length}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Completed store tasks
                                for (final task in completedStoreTasks)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Dismissible(
                                      key: Key('done_store_${task.id}'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        decoration: BoxDecoration(
                                          color: AppColors.red,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.white,
                                            size: 24),
                                      ),
                                      onDismissed: (_) =>
                                          AppStore.instance.deleteTask(task.id),
                                      child: Opacity(
                                        opacity: 0.6,
                                        child: TaskItemWidget(
                                          task: task,
                                          onToggle: () {},
                                        ),
                                      ),
                                    ),
                                  ),
                                // Completed habits
                                for (final habit in completedHabits)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Dismissible(
                                      key: Key('done_${habit.id ?? habit.title}'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        decoration: BoxDecoration(
                                          color: AppColors.red,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.white,
                                            size: 24),
                                      ),
                                      onDismissed: (_) {
                                        _habitService.deleteHabit(habit.id ?? '');
                                      },
                                      child: Opacity(
                                        opacity: 0.6,
                                        child: TaskItemWidget(
                                          task: _habitToTask(habit),
                                          onToggle: () {},
                                        ),
                                      ),
                                    ),
                                  ),
                              ],

                              // ── Expired (failed) quick tasks ─────────
                              if (expiredHabits.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        size: 16, color: AppColors.red),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Невыполненные · ${expiredHabits.length}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                for (final habit in expiredHabits)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Dismissible(
                                      key: Key('expired_${habit.id ?? habit.title}'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        decoration: BoxDecoration(
                                          color: AppColors.red,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.white,
                                            size: 24),
                                      ),
                                      onDismissed: (_) {
                                        setState(() => _dismissed.add(habit.id ?? ''));
                                        _habitService.deleteHabit(habit.id ?? '');
                                      },
                                      child: Opacity(
                                        opacity: 0.55,
                                        child: TaskItemWidget(
                                          task: _habitToTask(habit),
                                          onToggle: () {},
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGoal(goal) {
    Navigator.of(context).push(
      _slideRoute(GoalDetailScreen(goalId: goal.id)),
    );
  }

  Future<void> _submitQuickAdd(String text) async {
    _quickAddFocus.unfocus();
    if (text.trim().isEmpty) {
      // Если пусто — просто открываем полный экран
      Navigator.of(context).push(_slideRoute(const CreateTaskScreen(isFullPage: true)));
      return;
    }
    try {
      final now = DateTime.now();
      final habit = HabitModel(
        title: text.trim(),
        completed: false,
        createdAt: now,
        isQuickTask: true,
        xpReward: 20,
        coinReward: 10,
        deadline: now.add(const Duration(hours: 24)),
      );
      await _habitService.addHabit(habit);
      _quickAddController.clear();
      MainShell.of(context).showToast('Задача добавлена!');

      if (GoogleCalendarService.instance.isSyncEnabled.value) {
        GoogleCalendarService.instance.syncHabitToCalendar(habit);
      }
    } catch (_) {
      MainShell.of(context).showToast('Ошибка сохранения', isError: true);
    }
  }

  Future<void> _toggleHabit(HabitModel habit) async {
    final id = habit.id ?? '';
    if (_pendingDelete.contains(id)) {
      _undoCompletion(habit);
      return;
    }
    try {
      setState(() => _pendingDelete.add(id));
      await _habitService.updateHabit(habit.copyWith(completed: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Задача выполнена! ${habit.coinReward > 0 ? '+${habit.coinReward} монет  ' : ''}+${habit.xpReward} XP'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
          action: SnackBarAction(
            label: 'Отменить',
            textColor: Colors.white,
            onPressed: () => _undoCompletion(habit),
          ),
        ));
      _deleteTimers[id] = Timer(
        const Duration(seconds: 4),
        () => _confirmDelete(habit),
      );
    } catch (_) {
      setState(() => _pendingDelete.remove(id));
      if (!mounted) return;
      MainShell.of(context).showToast('Ошибка обновления', isError: true);
    }
  }

  void _undoCompletion(HabitModel habit) {
    final id = habit.id ?? '';
    _deleteTimers[id]?.cancel();
    _deleteTimers.remove(id);
    setState(() => _pendingDelete.remove(id));
    _habitService.updateHabit(habit.copyWith(completed: false, clearCompletedAt: true));
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  Future<void> _confirmDelete(HabitModel habit) async {
    final id = habit.id ?? '';
    if (!_pendingDelete.contains(id)) return;
    _deleteTimers.remove(id);
    setState(() => _pendingDelete.remove(id));
    if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    await AppStore.instance.completeHabitTask(
      xpReward: habit.xpReward,
      coinReward: habit.coinReward,
    );
    await _habitService.updateHabit(
      habit.copyWith(completed: true, completedAt: DateTime.now()),
    );
  }

  Future<void> _addTestHabit() async {
    try {
      await _habitService.addHabit(
        HabitModel(
          title: 'Test Habit',
          completed: false,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      MainShell.of(context).showToast('Test Habit сохранен');
    } catch (_) {
      if (!mounted) return;
      MainShell.of(context).showToast('Ошибка Firestore', isError: true);
    }
  }

  Future<void> _completeStoreTask(tm.TaskModel task) async {
    try {
      await AppStore.instance.updateTask(task.copyWith(completed: true));
      if (!mounted) return;
      final rewardText = task.xpReward > 0
          ? '+${task.reward} монет  +${task.xpReward} XP'
          : (task.isXp ? '+${task.reward} XP' : '+${task.reward} монет');
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Задача выполнена! $rewardText'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
        ));
    } catch (_) {
      if (!mounted) return;
      MainShell.of(context).showToast('Ошибка обновления', isError: true);
    }
  }

  tm.TaskModel _habitToTask(HabitModel habit) {
    String subtitle;
    if (habit.isQuickTask && habit.deadline != null) {
      if (habit.isExpired) {
        subtitle = 'Быстрая задача · просрочено';
      } else {
        final remaining = habit.deadline!.difference(DateTime.now());
        final h = remaining.inHours;
        final m = remaining.inMinutes % 60;
        subtitle = h > 0
            ? 'Быстрая задача · осталось ${h}ч ${m}м'
            : 'Быстрая задача · осталось ${m}м';
      }
    } else {
      subtitle = 'Задача';
    }

    return tm.TaskModel(
      id: habit.id ?? '',
      title: habit.title,
      subtitle: subtitle,
      reward: habit.isQuickTask ? habit.coinReward : 0,
      xpReward: habit.xpReward,
      isXp: habit.isQuickTask && habit.coinReward == 0,
      completed: habit.completed,
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 16,
        color: AppColors.borderDark,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );
}

Route _slideRoute(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

class _IconBtnLight extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtnLight({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFEDE9FE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}
