import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'goals_screen.dart';
import 'create_task_screen.dart';
import 'shop_screen.dart';
import 'profile_screen.dart';
import '../models/app_store.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();

  static MainShellState of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>()!;
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void setIndex(int index) => setState(() => _currentIndex = index);

  @override
  void initState() {
    super.initState();
    AppColors.isDarkMode.addListener(_onThemeChange);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Если Firebase Auth отсутствует (локальный fallback при регистрации/входе)
    // — пробуем восстановить сессию через сохранённые credentials или анонимно.
    if (FirebaseAuth.instance.currentUser == null) {
      await _restoreFirebaseSession();
    }
    try {
      await AppStore.instance.loadUserData();
    } catch (e) {
      AppStore.instance.initializeEmptyProfile();
    }
  }

  /// Восстанавливает Firebase-сессию:
  /// 1. Email + password из SharedPreferences
  /// 2. Анонимный вход как последний резерв
  static Future<void> _restoreFirebaseSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('local_auth_email');
      final password = prefs.getString('local_auth_password');
      if (email != null && password != null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (FirebaseAuth.instance.currentUser != null) return;
      }
    } catch (_) {}
    // Fallback: анонимный вход даёт валидный auth-токен
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {}
  }

  void _onThemeChange() => setState(() {});

  @override
  void dispose() {
    AppColors.isDarkMode.removeListener(_onThemeChange);
    super.dispose();
  }

  /// Show overlay toast message
  OverlayEntry? _toastEntry;

  void showToast(String message, {bool isError = false}) {
    _toastEntry?.remove();
    final overlay = Overlay.of(context);
    _toastEntry = OverlayEntry(
      builder: (_) => _ToastWidget(message: message, isError: isError),
    );
    overlay.insert(_toastEntry!);
    Future.delayed(const Duration(seconds: 2), () {
      _toastEntry?.remove();
      _toastEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardScreen(),
      const GoalsScreen(),
      const CreateTaskScreen(),
      const ShopScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _BottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav> {
  @override
  void initState() {
    super.initState();
    AppColors.isDarkMode.addListener(_onThemeChange);
  }

  void _onThemeChange() => setState(() {});

  @override
  void dispose() {
    AppColors.isDarkMode.removeListener(_onThemeChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'ГЛАВНАЯ'),
      _NavItem(icon: Icons.track_changes_rounded, label: 'ЦЕЛИ'),
      _NavItem(icon: Icons.add_circle_rounded, label: 'ДОБАВИТЬ'),
      _NavItem(icon: Icons.shopping_basket_rounded, label: 'МАГАЗИН'),
      _NavItem(icon: Icons.person_rounded, label: 'ПРОФИЛЬ'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        border: Border(top: BorderSide(color: AppColors.borderDark, width: 1)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == widget.currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 24,
                        color: active ? AppColors.primary : AppColors.textLight,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: active ? AppColors.primary : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  const _ToastWidget({required this.message, required this.isError});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 90,
      left: 0,
      right: 0,
      child: Center(
        child: ScaleTransition(
          scale: _anim,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isError ? AppColors.red : AppColors.success,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (widget.isError ? AppColors.red : AppColors.success)
                      .withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
