import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/app_store.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  @override
  Widget build(BuildContext context) {
    final user = AppStore.instance.userProfile;
    final completedTasksCount = user.completedTasks;
    final chartLabels = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    final todayIndex = DateTime.now().weekday - 1; // Mon=0 .. Sun=6
    final activity = user.weeklyActivity;
    final maxActivity = activity.reduce((a, b) => a > b ? a : b);
    final chartHeights = List.generate(7, (i) {
      if (maxActivity == 0) return 0.0;
      return activity[i] / maxActivity;
    });
    final achievements = [
      _Achievement(
          icon: Icons.wb_sunny_rounded,
          label: 'Ранняя\nпташка',
          description: 'Выполнить 5 задач до 9:00 утра',
          color: AppColors.warningLight,
          iconColor: AppColors.warning,
          locked: false),
      _Achievement(
          icon: Icons.directions_run_rounded,
          label: 'Марафонец',
          description: 'Поддерживать серию 7 дней подряд',
          color: AppColors.primaryLight,
          iconColor: AppColors.primary,
          locked: false),
      _Achievement(
          icon: Icons.workspace_premium_rounded,
          label: 'Эксперт',
          description: 'Достигнуть 10 уровня пользователя',
          color: AppColors.blueLight,
          iconColor: AppColors.blue,
          locked: false),
      _Achievement(
          icon: Icons.lock_rounded,
          label: 'Мастер',
          description: 'Завершить 100 задач с высоким приоритетом',
          color: AppColors.border,
          iconColor: AppColors.textLight,
          locked: true),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Профиль',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const SettingsScreen(),
                        transitionsBuilder: (_, anim, __, child) =>
                            SlideTransition(
                          position: Tween(
                                  begin: const Offset(1, 0), end: Offset.zero)
                              .animate(CurvedAnimation(
                                  parent: anim, curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.settings_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Avatar + name
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryLight,
                                AppColors.primary
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: ClipOval(
                            child: Image.network(
                              'https://i.pravatar.cc/150?img=11',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                child: Icon(Icons.person,
                                    color: AppColors.primary, size: 50),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.bgMain, width: 2),
                            ),
                            child: Text(
                              'LVL ${user.level}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Опытный планировщик',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stat cards
                    _statCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Выполнено',
                      value: '$completedTasksCount',
                      sub: 'всего задач',
                    ),
                    const SizedBox(height: 16),
                    _statCard(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Серия',
                      value: '${user.streak} дней',
                      sub: 'без пропусков',
                    ),
                    const SizedBox(height: 16),
                    _statCard(
                      icon: Icons.toll_rounded,
                      label: 'Монеты',
                      value: '${user.coins}',
                      sub: 'баланс кошелька',
                    ),

                    const SizedBox(height: 20),

                    // Activity chart
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.bgWhite,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Активность за неделю',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 100,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(7, (i) {
                                final isCurrent = i == todayIndex;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    child: GestureDetector(
                                      onTap: () => _showDayInfo(context, chartLabels[i], activity[i]),
                                      child: Container(
                                        color: Colors.transparent, // чтобы вся область столбца ловила клик
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Flexible(
                                              child: FractionallySizedBox(
                                                heightFactor: chartHeights[i],
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 200),
                                                  decoration: BoxDecoration(
                                                    color: isCurrent
                                                        ? AppColors.primary
                                                        : AppColors.primaryLight,
                                                    borderRadius: const BorderRadius.vertical(
                                                      top: Radius.circular(6),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          Divider(color: AppColors.borderDark),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: chartLabels
                                .map((l) => Text(
                                      l,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Achievements
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Достижения',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 19,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: achievements
                          .map((a) => _achievementItem(context, a))
                          .toList(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryDark, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _achievementItem(BuildContext context, _Achievement a) {
    return GestureDetector(
      onTap: () => _showAchievementDialog(context, a),
      child: Opacity(
        opacity: a.locked ? 0.5 : 1.0,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: a.color,
                shape: BoxShape.circle,
                border: Border.all(color: a.iconColor.withValues(alpha: 0.3)),
              ),
              child: Icon(a.icon, color: a.iconColor, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              a.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementDialog(BuildContext context, _Achievement a) {
    // ... оставил содержимое без изменений ...
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.bgWhite,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: a.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: a.iconColor.withValues(alpha: 0.3), width: 2),
                ),
                child: Icon(a.icon, color: a.iconColor, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                a.label.replaceAll('\n', ' '),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                a.locked ? 'Секретное достижение' : 'Достижение разблокировано!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: a.locked ? AppColors.textMuted : AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgMain,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Text(
                  a.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Отлично',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDayInfo(BuildContext context, String dayLabel, int tasksDone) {
    final xpEarned = tasksDone * 10;
    final coinsEarned = tasksDone * 5;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Статистика за $dayLabel',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tasksDone > 0 ? 'Отличный продуктивный день!' : 'В этот день вы отдыхали',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _infoRow(Icons.check_circle_outline_rounded, 'Задач выполнено', '$tasksDone', AppColors.success),
            Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.borderDark),
            ),
            _infoRow(Icons.bar_chart_rounded, 'Опыта получено', '+$xpEarned XP', AppColors.primary),
            Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.borderDark),
            ),
            _infoRow(Icons.toll_rounded, 'Монет заработано', '+$coinsEarned', AppColors.warning),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Achievement {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final Color iconColor;
  final bool locked;
  const _Achievement({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.iconColor,
    required this.locked,
  });
}
