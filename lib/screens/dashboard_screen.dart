import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/app_store.dart';
import '../models/user_profile.dart';
import '../models/habit_model.dart';
import '../models/task_model.dart' as tm;
import '../services/habit_service.dart';
import '../services/google_calendar_service.dart';
import '../widgets/goal_card_horizontal.dart';
import '../widgets/task_item_widget.dart';
import '../widgets/user_avatar.dart';
import 'notifications_screen.dart';
import 'main_shell.dart';
import 'goal_detail_screen.dart';
import 'create_habit_screen.dart';
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
  /// Сразу убирает карточку после свайпа, пока [AppStore.deleteTask] не завершился (иначе Dismissible падает).
  /// Для выполненных задач цели на главной используется [AppStore.dismissGoalTaskFromHome] — локальный список обновляется сразу.
  final Set<String> _dismissedGoalTaskIds = {};

  final _quickAddController = TextEditingController();
  final _quickAddFocus = FocusNode();
  bool _quickAddBusy = false;

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreChanged);
    AppColors.isDarkMode.addListener(_onThemeChange);
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_onStoreChanged);
    AppColors.isDarkMode.removeListener(_onThemeChange);
    _quickAddController.dispose();
    _quickAddFocus.dispose();
    for (final t in _deleteTimers.values) {
      t.cancel();
    }
    _deleteTimers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppStore.instance.userProfile;
    final xpPercent = user.getXpProgressPercent() / 100.0;

    return ColoredBox(
      color: AppColors.bgMain,
      child: SafeArea(
        child: Column(
          children: [
            // ─── Top bar: бренд без чужого аватара; фото — в карточке приветствия
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        AppColors.primaryDark,
                        AppColors.primary,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'Zhasau',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _NotificationBellButton(
                    unread: AppStore.instance.unreadNotificationCount,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                      height: 1.15,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Привет, '),
                                      TextSpan(
                                        text: '${user.name}!',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              UserAvatar(
                                displayName: user.name,
                                photoUrl: user.photoUrl,
                                radius: 26,
                              ),
                            ],
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
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textDark,
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
                          '${user.streak} ${UserProfile.streakDaysWord(user.streak)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textDark,
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
                              Text(
                                'Опыт (XP)',
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
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.primary),
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

                    Text(
                      'Быстрая задача',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.bgWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.borderDark.withValues(alpha: 0.65),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _quickAddController,
                                focusNode: _quickAddFocus,
                                decoration: InputDecoration(
                                  hintText: 'Запишите задачу на сегодня…',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  hintStyle: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textDark,
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: _submitQuickAdd,
                              ),
                            ),
                            Material(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: _quickAddBusy
                                    ? null
                                    : () => _submitQuickAdd(
                                          _quickAddController.text,
                                        ),
                                child: const SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Icon(
                                    Icons.arrow_upward_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const CreateHabitScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                        label: const Text(
                          'Добавить привычку',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Active Goals
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Активные цели',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => MainShell.of(context).setIndex(1),
                          child: Text(
                            'Все',
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
                        final now = DateTime.now();
                        bool sameCalendarDay(DateTime a) =>
                            a.year == now.year &&
                            a.month == now.month &&
                            a.day == now.day;

                        /// «Задачи на сегодня» — только слот на сегодня или без даты; не весь невыполненный бэклог.
                        final incompleteGoalTasks = AppStore.instance.tasks
                            .where((t) =>
                                t.goalId != null &&
                                t.goalId!.isNotEmpty &&
                                !t.completed &&
                                !_dismissedGoalTaskIds.contains(t.id) &&
                                (t.scheduledAt == null ||
                                    sameCalendarDay(t.scheduledAt!)))
                            .toList();

                        // Активные строки: привычки по слотам времени или одна строка на привычку/задачу.
                        final activeHabitEntries =
                            <({HabitModel habit, String? slot})>[];
                        for (final h in habits) {
                          if (_pendingDelete.contains(h.id) ||
                              _dismissed.contains(h.id)) {
                            continue;
                          }
                          if (h.isRecurring && h.reminderTimes.isNotEmpty) {
                            if (!h.matchesRepeatOn(now)) continue;
                            for (final slot in h.reminderTimes) {
                              if (!h.completedSlotsForDay(now).contains(slot)) {
                                activeHabitEntries.add((habit: h, slot: slot));
                              }
                            }
                            continue;
                          }
                          if (_isHabitActiveToday(h, now)) {
                            activeHabitEntries.add((habit: h, slot: null));
                          }
                        }

                        final upcomingGoalTasks = AppStore.instance.tasks
                            .where((t) =>
                                t.goalId != null &&
                                t.goalId!.isNotEmpty &&
                                !t.completed &&
                                !_dismissedGoalTaskIds.contains(t.id) &&
                                t.scheduledAt != null &&
                                !sameCalendarDay(t.scheduledAt!))
                            .toList()
                          ..sort((a, b) =>
                              a.scheduledAt!.compareTo(b.scheduledAt!));

                        final upcomingHabits = habits
                            .where((h) =>
                                !h.completed &&
                                !h.isExpired &&
                                h.completedAt == null &&
                                !_pendingDelete.contains(h.id) &&
                                !_dismissed.contains(h.id) &&
                                !h.isQuickTask &&
                                h.deadline != null &&
                                !sameCalendarDay(h.deadline!))
                            .toList()
                          ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

                        final upcomingCount =
                            upcomingGoalTasks.length + upcomingHabits.length;

                        final completedSlotRows = <(HabitModel, String)>[];
                        for (final h in habits) {
                          if (!h.isRecurring || h.reminderTimes.isEmpty) {
                            continue;
                          }
                          if (!h.matchesRepeatOn(now)) continue;
                          for (final slot in h.reminderTimes) {
                            if (h.completedSlotsForDay(now).contains(slot)) {
                              completedSlotRows.add((h, slot));
                            }
                          }
                        }

                        final completedWholeHabits = habits.where((h) {
                          if (h.isRecurring && h.reminderTimes.isNotEmpty) {
                            return false;
                          }
                          return h.isDoneForLocalDay(now);
                        }).toList();

                        final completedGoalTasksToday = AppStore.instance.tasks
                            .where((t) =>
                                t.goalId != null &&
                                t.goalId!.isNotEmpty &&
                                t.completed &&
                                !t.dismissedFromHome &&
                                !_dismissedGoalTaskIds.contains(t.id) &&
                                (t.scheduledAt == null ||
                                    sameCalendarDay(t.scheduledAt!)))
                            .toList();

                        final completedShownCount = completedSlotRows.length +
                            completedWholeHabits.length +
                            completedGoalTasksToday.length;

                        // Expired quick tasks (deadline passed, not completed, not dismissed)
                        final expiredHabits = habits
                            .where((h) =>
                                h.isExpired && !_dismissed.contains(h.id))
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Header ──────────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Задачи на сегодня',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${activeHabitEntries.length + incompleteGoalTasks.length}',
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
                                habits.isEmpty &&
                                incompleteGoalTasks.isEmpty &&
                                upcomingCount == 0)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            else if (activeHabitEntries.isEmpty &&
                                incompleteGoalTasks.isEmpty &&
                                completedShownCount == 0 &&
                                expiredHabits.isEmpty &&
                                upcomingCount == 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Пока нет задач на сегодня',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, _) {
                                  final viewH = MediaQuery.sizeOf(context)
                                          .height -
                                      MediaQuery.viewInsetsOf(context).bottom;
                                  final maxH =
                                      (viewH * 0.58).clamp(240.0, 640.0);
                                  return ConstrainedBox(
                                    constraints:
                                        BoxConstraints(maxHeight: maxH),
                                    child: ListView(
                                      primary: false,
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      physics: const ClampingScrollPhysics(),
                                      children: [
                                        if (activeHabitEntries.isEmpty &&
                                            incompleteGoalTasks.isEmpty &&
                                            upcomingCount > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 14),
                                            child: Text(
                                              'На сегодня план пустой. Ниже — что запланировано на другие дни.',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textMuted,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        for (final entry in activeHabitEntries)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: Dismissible(
                                              key: Key(
                                                  '${entry.habit.id ?? entry.habit.title}_${entry.slot ?? 'main'}'),
                                              direction:
                                                  DismissDirection.endToStart,
                                              background: Container(
                                                alignment:
                                                    Alignment.centerRight,
                                                padding: const EdgeInsets.only(
                                                    right: 20),
                                                decoration: BoxDecoration(
                                                  color: AppColors.red,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: Colors.white,
                                                    size: 24),
                                              ),
                                              onDismissed: (_) {
                                                setState(() => _dismissed
                                                    .add(entry.habit.id ?? ''));
                                                _habitService.deleteHabit(
                                                    entry.habit.id ?? '');
                                              },
                                              child: TaskItemWidget(
                                                task: _habitToTask(entry.habit,
                                                    reminderSlot: entry.slot),
                                                onToggle: () {
                                                  if (entry.slot != null) {
                                                    _toggleHabitReminderSlot(
                                                        entry.habit,
                                                        entry.slot!);
                                                  } else {
                                                    _toggleHabit(entry.habit);
                                                  }
                                                },
                                                onContentTap: () {
                                                  if (entry.habit.isRecurring) {
                                                    Navigator.of(context)
                                                        .push<void>(
                                                      MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            CreateHabitScreen(
                                                          habitToEdit:
                                                              entry.habit,
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    Navigator.of(context)
                                                        .push<void>(
                                                      MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            CreateTaskScreen(
                                                          isFullPage: true,
                                                          habitToEdit:
                                                              entry.habit,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                          ),

                                        // ── Задачи из целей (активные) ───────────────
                                        for (final gTask in incompleteGoalTasks)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: Dismissible(
                                              key: Key('goal_task_${gTask.id}'),
                                              direction:
                                                  DismissDirection.endToStart,
                                              background: Container(
                                                alignment:
                                                    Alignment.centerRight,
                                                padding: const EdgeInsets.only(
                                                    right: 20),
                                                decoration: BoxDecoration(
                                                  color: AppColors.red,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                              onDismissed: (_) {
                                                final shell =
                                                    MainShell.maybeOf(context);
                                                setState(() =>
                                                    _dismissedGoalTaskIds
                                                        .add(gTask.id));
                                                AppStore.instance
                                                    .deleteTask(gTask.id)
                                                    .catchError((_) {
                                                  if (!mounted) return;
                                                  setState(() =>
                                                      _dismissedGoalTaskIds
                                                          .remove(gTask.id));
                                                  shell?.showToast(
                                                    'Не удалось удалить задачу',
                                                    isError: true,
                                                  );
                                                });
                                              },
                                              child: TaskItemWidget(
                                                task:
                                                    _goalTaskForDisplay(gTask),
                                                onToggle: () =>
                                                    _toggleGoalTask(gTask),
                                                onContentTap: () {
                                                  Navigator.of(context)
                                                      .push<void>(
                                                    MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          CreateTaskScreen(
                                                        isFullPage: true,
                                                        taskToEdit: gTask,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),

                                        // ── Запланировано на другие дни ─────────────
                                        if (upcomingCount > 0) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.blueLight
                                                      .withValues(alpha: 0.85),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  Icons.event_note_rounded,
                                                  size: 18,
                                                  color: AppColors.blue,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Дальше по плану',
                                                      style: TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            AppColors.textDark,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Не на сегодня, но по расписанию',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.blueLight
                                                      .withValues(alpha: 0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '$upcomingCount',
                                                  style: TextStyle(
                                                    color: AppColors.blue,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.fromLTRB(
                                                12, 14, 12, 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.blueLight
                                                  .withValues(alpha: 0.22),
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              border: Border.all(
                                                color: AppColors.blue
                                                    .withValues(alpha: 0.12),
                                              ),
                                            ),
                                            child: Column(
                                              children: () {
                                                final rows = <({
                                                  DateTime at,
                                                  Widget row
                                                })>[];
                                                for (final h
                                                    in upcomingHabits) {
                                                  rows.add((
                                                    at: h.deadline!,
                                                    row: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 10),
                                                      child: Dismissible(
                                                        key: Key(
                                                            'up_h_${h.id ?? h.title}'),
                                                        direction:
                                                            DismissDirection
                                                                .endToStart,
                                                        background: Container(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  right: 20),
                                                          decoration:
                                                              BoxDecoration(
                                                            color:
                                                                AppColors.red,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16),
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .delete_outline_rounded,
                                                            color: Colors.white,
                                                            size: 24,
                                                          ),
                                                        ),
                                                        onDismissed: (_) {
                                                          setState(() =>
                                                              _dismissed.add(
                                                                  h.id ?? ''));
                                                          _habitService
                                                              .deleteHabit(
                                                                  h.id ?? '');
                                                        },
                                                        child: TaskItemWidget(
                                                          task:
                                                              _habitToTaskUpcoming(
                                                                  h, now),
                                                          onToggle: () =>
                                                              _toggleHabit(h),
                                                          onContentTap: () {
                                                            Navigator.of(
                                                                    context)
                                                                .push<void>(
                                                              MaterialPageRoute<
                                                                  void>(
                                                                builder: (_) =>
                                                                    CreateTaskScreen(
                                                                  isFullPage:
                                                                      true,
                                                                  habitToEdit:
                                                                      h,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ));
                                                }
                                                for (final gTask
                                                    in upcomingGoalTasks) {
                                                  rows.add((
                                                    at: gTask.scheduledAt!,
                                                    row: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 10),
                                                      child: Dismissible(
                                                        key: Key(
                                                            'up_gt_${gTask.id}'),
                                                        direction:
                                                            DismissDirection
                                                                .endToStart,
                                                        background: Container(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  right: 20),
                                                          decoration:
                                                              BoxDecoration(
                                                            color:
                                                                AppColors.red,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16),
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .delete_outline_rounded,
                                                            color: Colors.white,
                                                            size: 24,
                                                          ),
                                                        ),
                                                        onDismissed: (_) {
                                                          final shell =
                                                              MainShell
                                                                  .maybeOf(
                                                                      context);
                                                          setState(() =>
                                                              _dismissedGoalTaskIds
                                                                  .add(
                                                                      gTask
                                                                          .id));
                                                          AppStore.instance
                                                              .deleteTask(
                                                                  gTask.id)
                                                              .catchError(
                                                                  (_) {
                                                            if (!mounted) {
                                                              return;
                                                            }
                                                            setState(() =>
                                                                _dismissedGoalTaskIds
                                                                    .remove(
                                                                        gTask
                                                                            .id));
                                                            shell?.showToast(
                                                              'Не удалось удалить задачу',
                                                              isError: true,
                                                            );
                                                          });
                                                        },
                                                        child: TaskItemWidget(
                                                          task:
                                                              _goalTaskForUpcoming(
                                                                  gTask, now),
                                                          onToggle: () =>
                                                              _toggleGoalTask(
                                                                  gTask),
                                                          onContentTap: () {
                                                            Navigator.of(
                                                                    context)
                                                                .push<void>(
                                                              MaterialPageRoute<
                                                                  void>(
                                                                builder: (_) =>
                                                                    CreateTaskScreen(
                                                                  isFullPage:
                                                                      true,
                                                                  taskToEdit:
                                                                      gTask,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ));
                                                }
                                                rows.sort((a, b) =>
                                                    a.at.compareTo(b.at));
                                                return rows
                                                    .map((e) => e.row)
                                                    .toList();
                                              }(),
                                            ),
                                          ),
                                        ],

                                        // ── Completed today section ──────────────
                                        if (completedShownCount > 0) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                  Icons
                                                      .check_circle_outline_rounded,
                                                  size: 16,
                                                  color: AppColors.primary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Выполнено сегодня · $completedShownCount',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          for (final row in completedSlotRows)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: Dismissible(
                                                key: Key(
                                                    'done_${row.$1.id}_${row.$2}'),
                                                direction:
                                                    DismissDirection.endToStart,
                                                background: Container(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 20),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.red,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  child: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      color: Colors.white,
                                                      size: 24),
                                                ),
                                                onDismissed: (_) {
                                                  _habitService.deleteHabit(
                                                      row.$1.id ?? '');
                                                },
                                                child: Opacity(
                                                  opacity: 0.6,
                                                  child: TaskItemWidget(
                                                    task: _habitToTask(row.$1,
                                                        reminderSlot: row.$2),
                                                    onToggle: () =>
                                                        _toggleHabitReminderSlot(
                                                            row.$1, row.$2),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          for (final habit
                                              in completedWholeHabits)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: Dismissible(
                                                key: Key(
                                                    'done_${habit.id ?? habit.title}'),
                                                direction:
                                                    DismissDirection.endToStart,
                                                background: Container(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 20),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.red,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  child: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      color: Colors.white,
                                                      size: 24),
                                                ),
                                                onDismissed: (_) {
                                                  _habitService.deleteHabit(
                                                      habit.id ?? '');
                                                },
                                                child: Opacity(
                                                  opacity: 0.6,
                                                  child: TaskItemWidget(
                                                    task: _habitToTask(habit),
                                                    onToggle: () =>
                                                        _uncompleteHabitFromDoneList(
                                                            habit),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          for (final gt
                                              in completedGoalTasksToday)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: Dismissible(
                                                key: Key('done_goal_${gt.id}'),
                                                direction:
                                                    DismissDirection.endToStart,
                                                background: Container(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 18),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.blueLight,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    border: Border.all(
                                                      color: AppColors.blue
                                                          .withValues(
                                                              alpha: 0.28),
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons
                                                        .visibility_off_rounded,
                                                    color: AppColors.blue,
                                                    size: 26,
                                                  ),
                                                ),
                                                onDismissed: (_) {
                                                  final shell =
                                                      MainShell.maybeOf(
                                                          context);
                                                  AppStore.instance
                                                      .dismissGoalTaskFromHome(
                                                          gt.id)
                                                      .catchError((_) {
                                                    if (!mounted) return;
                                                    shell?.showToast(
                                                      'Не удалось скрыть задачу с главной',
                                                      isError: true,
                                                    );
                                                  });
                                                },
                                                child: Opacity(
                                                  opacity: 0.6,
                                                  child: TaskItemWidget(
                                                    task:
                                                        _goalTaskForDisplay(gt),
                                                    onToggle: () =>
                                                        _toggleGoalTask(gt),
                                                    onContentTap: null,
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
                                                  size: 16,
                                                  color: AppColors.red),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Просрочено · ${expiredHabits.length}',
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
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: Dismissible(
                                                key: Key(
                                                    'expired_${habit.id ?? habit.title}'),
                                                direction:
                                                    DismissDirection.endToStart,
                                                background: Container(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 20),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.red,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  child: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      color: Colors.white,
                                                      size: 24),
                                                ),
                                                onDismissed: (_) {
                                                  setState(() => _dismissed
                                                      .add(habit.id ?? ''));
                                                  _habitService.deleteHabit(
                                                      habit.id ?? '');
                                                },
                                                child: Opacity(
                                                  opacity: 0.55,
                                                  child: TaskItemWidget(
                                                    task: _habitToTask(habit),
                                                    onToggle: () =>
                                                        _toggleHabit(habit),
                                                    onContentTap: () {
                                                      Navigator.of(context)
                                                          .push<void>(
                                                        MaterialPageRoute<void>(
                                                          builder: (_) =>
                                                              CreateTaskScreen(
                                                            isFullPage: true,
                                                            habitToEdit: habit,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
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

  tm.TaskModel _goalTaskForDisplay(tm.TaskModel task) {
    final gid = task.goalId;
    if (gid == null || gid.isEmpty) return task;
    for (final g in AppStore.instance.goals) {
      if (g.id == gid) {
        return task.copyWith(subtitle: 'Цель · ${g.title}');
      }
    }
    return task;
  }

  Future<void> _toggleGoalTask(tm.TaskModel task) async {
    final gid = task.goalId;
    if (gid == null || gid.isEmpty) return;
    final store = AppStore.instance;
    final willComplete = !task.completed;
    final xpAward = store.xpRewardForGoalTask(task);
    final reward = willComplete ? xpAward : task.reward;
    final updatedTask = task.copyWith(
      completed: willComplete,
      reward: reward,
      isXp: true,
    );

    try {
      await store.updateTask(updatedTask);
    } catch (_) {
      if (!mounted) return;
      MainShell.of(context).showToast('Не удалось сохранить', isError: true);
      return;
    }
    if (!mounted) return;

    if (willComplete) {
      var bonusGranted = false;
      var bonusXp = 0;
      var bonusCoins = 0;
      for (final g in store.goals) {
        if (g.id == gid) {
          bonusGranted = g.completionBonusGranted;
          bonusXp = g.xpCompletionBonus;
          bonusCoins = g.coinsCompletionBonus;
          break;
        }
      }
      final allDone =
          store.getTasksForGoal(gid).every((t) => t.completed);
      if (allDone && bonusGranted && (bonusXp > 0 || bonusCoins > 0)) {
        MainShell.of(context).showToast(
          'Цель выполнена! +$bonusXp XP · +$bonusCoins монет',
        );
      } else {
        MainShell.of(context).showToast('Шаг цели отмечен');
      }
    } else {
      MainShell.of(context).showToast('Шаг цели снова открыт');
    }
  }

  Future<void> _submitQuickAdd(String text) async {
    _quickAddFocus.unfocus();
    if (text.trim().isEmpty) {
      // Если пусто — просто открываем полный экран
      Navigator.of(context)
          .push(_slideRoute(const CreateTaskScreen(isFullPage: true)));
      return;
    }
    if (_quickAddBusy) return;
    setState(() => _quickAddBusy = true);
    try {
      final now = DateTime.now();
      final habit = HabitModel(
        title: text.trim(),
        completed: false,
        createdAt: now,
        isQuickTask: true,
        xpReward: 20,
        deadline: now.add(const Duration(hours: 24)),
      );
      final saved = await _habitService.addHabit(habit);
      _quickAddController.clear();
      if (!mounted) return;
      MainShell.of(context).showToast('Задача добавлена!');

      if (GoogleCalendarService.instance.isSyncEnabled.value) {
        final eventId =
            await GoogleCalendarService.instance.syncHabitToCalendar(saved);
        if (eventId != null &&
            eventId.isNotEmpty &&
            eventId != saved.calendarEventId) {
          await _habitService.updateHabit(
            saved.copyWith(calendarEventId: eventId),
          );
        }
      }
    } on ArgumentError catch (e) {
      if (!mounted) return;
      MainShell.of(context)
          .showToast(e.message ?? 'Проверьте данные', isError: true);
    } catch (_) {
      if (!mounted) return;
      MainShell.of(context).showToast('Ошибка сохранения', isError: true);
    } finally {
      if (mounted) setState(() => _quickAddBusy = false);
    }
  }

  Future<void> _toggleHabitReminderSlot(HabitModel h, String slotHm) async {
    final now = DateTime.now();
    final todayKey = HabitModel.dateKeyLocal(now);
    var done = List<String>.from(h.completedSlotsForDay(now));

    if (done.contains(slotHm)) {
      done.remove(slotHm);
      await _habitService.updateHabit(
        h.copyWith(
          completedSlotsToday: done,
          slotsProgressDateKey: todayKey,
          completed: false,
          clearCompletedAt: true,
          clearLastCompletedDateKey: true,
        ),
      );
      if (mounted) setState(() {});
      return;
    }

    done.add(slotHm);
    done.sort();
    var patch = h.copyWith(
      completedSlotsToday: done,
      slotsProgressDateKey: todayKey,
    );
    final allDone = h.reminderTimes.every((t) => done.contains(t));
    if (allDone) {
      patch = patch.copyWith(
        lastCompletedDateKey: todayKey,
        completed: true,
        completedAt: now,
      );
    }
    await _habitService.updateHabit(patch);
    final n = h.reminderTimes.length;
    final xpPer = n > 0 ? math.max(1, (h.xpReward / n).round()) : h.xpReward;
    await AppStore.instance.completeHabitTask(
      xpReward: xpPer,
      coinReward: 0,
      statsAt: now,
    );
    if (mounted) {
      MainShell.of(context).showToast('+$xpPer XP · $slotHm');
      setState(() {});
    }
  }

  Future<void> _uncompleteHabitFromDoneList(HabitModel habit) async {
    final id = habit.id ?? '';
    if (id.isEmpty) return;
    if (_pendingDelete.contains(id)) {
      _undoCompletion(habit);
      return;
    }
    try {
      await AppStore.instance.revertHabitCompletionRewards(
        xpReward: habit.xpReward,
        coinReward: habit.coinReward,
        completionRecordedAt: habit.completedAt,
      );
      await _habitService.updateHabit(
        habit.copyWith(
          completed: false,
          clearCompletedAt: true,
          clearLastCompletedDateKey: true,
          clearSlotsProgress: true,
        ),
      );
      if (mounted) {
        MainShell.of(context).showToast('Задача снова в списке невыполненных');
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        MainShell.of(context).showToast(
          'Не удалось вернуть задачу',
          isError: true,
        );
      }
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
          content: Text(
            habit.coinReward > 0
                ? 'Задача выполнена! +${habit.xpReward} XP · +${habit.coinReward} монет'
                : 'Задача выполнена! +${habit.xpReward} XP',
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    _habitService.updateHabit(
      habit.copyWith(
        completed: false,
        clearCompletedAt: true,
        clearLastCompletedDateKey: true,
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  Future<void> _confirmDelete(HabitModel habit) async {
    final id = habit.id ?? '';
    if (!_pendingDelete.contains(id)) return;
    _deleteTimers.remove(id);
    setState(() => _pendingDelete.remove(id));
    if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    final at = DateTime.now();
    await AppStore.instance.completeHabitTask(
      xpReward: habit.xpReward,
      coinReward: habit.coinReward,
      statsAt: at,
    );
    await _habitService.updateHabit(
      habit.copyWith(
        completed: true,
        completedAt: at,
        lastCompletedDateKey: HabitModel.dateKeyLocal(at),
      ),
    );
  }

  /// Показать в блоке «Задачи на сегодня» (до отметки и таймера награды).
  /// Привычки с [HabitModel.reminderTimes] разбиваются на строки по слотам — здесь не участвуют.
  bool _isHabitActiveToday(HabitModel h, DateTime now) {
    if (h.isRecurring && h.reminderTimes.isNotEmpty) {
      return false;
    }
    // Быстрая задача: дедлайн через 24 ч — это почти всегда «завтра» по календарю.
    // Не требуем deadline в тот же день, что и сейчас, иначе строка не появляется в списке.
    if (h.isQuickTask) {
      return !h.completed && !h.isExpired && h.completedAt == null;
    }
    if (h.isRecurring) {
      if (!h.matchesRepeatOn(now)) return false;
      if (h.isDoneForLocalDay(now)) return false;
      if (h.isExpired) return false;
      return true;
    }
    return !h.completed &&
        !h.isExpired &&
        h.completedAt == null &&
        (h.deadline == null || _sameCalendarDay(h.deadline!, now));
  }

  bool _sameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  tm.TaskModel _habitToTask(HabitModel habit, {String? reminderSlot}) {
    final now = DateTime.now();
    final doneToday = reminderSlot != null
        ? habit.completedSlotsForDay(now).contains(reminderSlot)
        : habit.isDoneForLocalDay(now);
    String subtitle;
    if (reminderSlot != null) {
      subtitle = habit.notes.isNotEmpty
          ? '🕐 $reminderSlot · ${habit.notes}'
          : '🕐 $reminderSlot · привычка';
    } else if (habit.isRecurring) {
      if (habit.repeatWeekdays.isEmpty) {
        subtitle = habit.notes.isNotEmpty
            ? 'Привычка · каждый день · ${habit.notes}'
            : 'Привычка · каждый день';
      } else {
        const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
        final days = [...habit.repeatWeekdays]..sort((a, b) => a.compareTo(b));
        final label = days.map((d) => names[d - 1]).join(', ');
        subtitle = habit.notes.isNotEmpty
            ? 'Привычка · $label · ${habit.notes}'
            : 'Привычка · $label';
      }
    } else if (habit.notes.isNotEmpty) {
      subtitle = habit.notes;
    } else if (habit.isQuickTask && habit.deadline != null) {
      if (habit.isExpired) {
        subtitle = 'Быстрая задача · просрочено';
      } else {
        final remaining = habit.deadline!.difference(DateTime.now());
        final h = remaining.inHours;
        final m = remaining.inMinutes % 60;
        subtitle = h > 0
            ? 'Быстрая задача · осталось $hч $mм'
            : 'Быстрая задача · осталось $mм';
      }
    } else {
      subtitle =
          (habit.isExpired && habit.deadline != null) ? 'Просрочено' : 'Задача';
    }

    // Награда: быстрые задачи и задачи с экрана «Добавить» хранят xpReward; раньше XP в карточке был только при isQuickTask.
    final int reward;
    final bool isXp;
    if (habit.xpReward > 0) {
      reward = habit.xpReward;
      isXp = true;
    } else if (habit.coinReward > 0) {
      reward = habit.coinReward;
      isXp = false;
    } else {
      reward = 0;
      isXp = true;
    }

    return tm.TaskModel(
      id: habit.id ?? '',
      title: habit.title,
      subtitle: subtitle,
      reward: reward,
      isXp: isXp,
      completed: doneToday,
    );
  }

  String _planDayLabel(DateTime slot, DateTime now) {
    final s = DateTime(slot.year, slot.month, slot.day);
    final t = DateTime(now.year, now.month, now.day);
    final diff = s.difference(t).inDays;
    if (diff == 1) return 'Завтра';
    if (diff == 2) return 'Послезавтра';
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    if (diff >= 3 && diff <= 6) return weekdays[s.weekday - 1];
    const months = [
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
    return '${s.day} ${months[s.month - 1]}';
  }

  String _planTimeHm(DateTime slot) {
    final h = slot.hour.toString().padLeft(2, '0');
    final m = slot.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  tm.TaskModel _goalTaskForUpcoming(tm.TaskModel task, DateTime now) {
    final base = _goalTaskForDisplay(task);
    final st = task.scheduledAt!;
    return base.copyWith(
      subtitle:
          '${_planDayLabel(st, now)} · ${_planTimeHm(st)} · ${base.subtitle}',
    );
  }

  tm.TaskModel _habitToTaskUpcoming(HabitModel habit, DateTime now) {
    final t = _habitToTask(habit);
    final d = habit.deadline!;
    final tail = habit.notes.isNotEmpty ? habit.notes : t.subtitle;
    return t.copyWith(
      subtitle: '${_planDayLabel(d, now)} · ${_planTimeHm(d)} · $tail',
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

class _NotificationBellButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const _NotificationBellButton({
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              unread > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          if (unread > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.bgMain, width: 2),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
