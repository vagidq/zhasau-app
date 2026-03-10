import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../data/mock_data.dart';
import '../widgets/goal_card_vertical.dart';
import 'goal_detail_screen.dart';
import 'create_goal_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  int _activeFilter = 0;
  final _filters = ['Все', 'Здоровье', 'Карьера', 'Хобби'];

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
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.menu_rounded,
                              size: 26, color: AppColors.textDark),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Мои цели',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
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
                        ...MockData.goals.map(
                          (g) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GoalCardVertical(
                              goal: g,
                              onTap: () => _openGoal(g),
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
