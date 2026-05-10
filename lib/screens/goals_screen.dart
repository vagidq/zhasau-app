import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/goal_card_vertical.dart';
import 'goal_detail_screen.dart';
import 'create_goal_screen.dart';
import '../models/app_store.dart';
import '../models/goal_model.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  int _activeFilter = 0;
  final _filters = ['Все', 'Здоровье', 'Образование', 'Карьера', 'Хобби'];

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreChanged);
    AppColors.isDarkMode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_onStoreChanged);
    AppColors.isDarkMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    setState(() {});
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  bool _goalMatchesFilter(GoalModel g, int filterIndex) {
    if (filterIndex == 0) return true;
    return g.categoryFilterKey == _filters[filterIndex].toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      const SizedBox(width: 34),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Мои цели',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.notifications_none_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Search box
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.bgWhite,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded,
                                  color: AppColors.primary, size: 22),
                              const SizedBox(width: 12),
                              Text(
                                'Поиск целей',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Filter tabs
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filters.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 16),
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () =>
                                  setState(() => _activeFilter = i),
                              child: Column(
                                children: [
                                  Text(
                                    _filters[i],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _activeFilter == i
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    height: 2,
                                    width: _activeFilter == i ? 40 : 0,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius:
                                          BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Divider(
                            height: 1, color: AppColors.borderDark),
                        const SizedBox(height: 20),
                        // Goal cards
                        ...AppStore.instance.goals
                            .where((g) => _goalMatchesFilter(g, _activeFilter))
                            .map(
                          (g) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Dismissible(
                              key: Key(g.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  color: AppColors.red,
                                  borderRadius: BorderRadius.circular(20),
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
                                        borderRadius: BorderRadius.circular(20)),
                                    title: const Text('Удалить цель?'),
                                    content: Text(
                                        'Цель «${g.title}» и все её задачи будут удалены.'),
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
                                ) ?? false;
                              },
                              onDismissed: (_) {
                                AppStore.instance.deleteGoal(g.id);
                              },
                              child: GoalCardVertical(
                                goal: g,
                                onTap: () => _openGoal(g),
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
                onTap: () => Navigator.of(context).push(
                  _slideRoute(const CreateGoalScreen()),
                ),
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

  void _openGoal(goal) {
    Navigator.of(context).push(_slideRoute(GoalDetailScreen(goalId: goal.id)));
  }
}
final store = AppStore.instance;
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
