import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../data/mock_data.dart';
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
  void _refresh() => setState(() {});

  final _quickAddController = TextEditingController();
  final _quickAddFocus = FocusNode();

  @override
  void dispose() {
    _quickAddController.dispose();
    _quickAddFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = MockData.user;
    final xpPercent = user.xp / user.xpMax;

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
                            'До уровня ${user.level + 1} осталось ${user.xpMax - user.xp} XP',
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
                    SizedBox(
                      height: 170,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: MockData.goals.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 16),
                        itemBuilder: (_, i) => GoalCardHorizontal(
                          goal: MockData.goals[i],
                          onTap: () => _openGoal(MockData.goals[i]),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Today Tasks
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
                          child: Text('3 задачи',
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
                    ...MockData.tasks.take(3).map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TaskItemWidget(
                              task: t,
                              onToggle: () {
                                _toggleTask(t);
                                _refresh();
                              },
                            ),
                          ),
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

  void _submitQuickAdd(String text) {
    _quickAddFocus.unfocus();
    if (text.trim().isEmpty) {
      // Если пусто — просто открываем полный экран
      Navigator.of(context).push(_slideRoute(const CreateTaskScreen(isFullPage: true)));
      return;
    }
    // Если есть текст — показываем тост и очищаем поле
    _quickAddController.clear();
    MainShell.of(context).showToast('Задача добавлена!');
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
        MainShell.of(context).showToast('Задача выполнена!');
      }
    } else {
      if (task.isXp) {
        MockData.user.xp = (MockData.user.xp - task.reward).toInt();
      } else {
        MockData.user.coins = (MockData.user.coins - task.reward).toInt();
      }
    }
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
