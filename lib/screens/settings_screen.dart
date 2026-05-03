import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../models/app_store.dart';
import 'main_shell.dart';
import '../services/auth_service.dart';
import '../services/local_auth_service.dart';
import '../services/google_calendar_service.dart';
import '../services/habit_service.dart';
import '../services/push_notification_bridge.dart';
import 'splash_screen.dart';
import 'edit_profile_screen.dart';

/// Почта для пункта «Поддержка» (замените на свою перед публикацией).
const String _kSupportEmail = 'ruslan.zlobin.06@mail.ru';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final LocalAuthService _localAuthService = LocalAuthService();
  final HabitService _habitService = HabitService();
  // Локальные состояния для свитчеров
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;

  /// Экран открыт поверх стека из профиля — над виджетом может не быть [MainShell].
  void _toast(String message, {bool isError = false}) {
    final shell = MainShell.maybeOf(context);
    if (shell != null) {
      shell.showToast(message, isError: isError);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  Future<void> _openPasswordSecurity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('Войдите в аккаунт', isError: true);
      return;
    }
    if (user.isAnonymous) {
      _toast(
        'Вы вошли анонимно. Пароль не используется — зарегистрируйтесь с почтой '
        'на экране входа, чтобы можно было сбрасывать пароль.',
        isError: true,
      );
      return;
    }
    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      _toast('У аккаунта нет почты для сброса', isError: true);
      return;
    }
    final providers = user.providerData.map((p) => p.providerId).toSet();
    final hasEmailPassword = providers.contains('password');
    if (!hasEmailPassword) {
      if (providers.contains('google.com')) {
        _toast(
          'Вход через Google: пароль в Zhasau не хранится. '
          'Безопасность аккаунта — в настройках Google.',
        );
      } else {
        _toast('Сброс пароля для этого способа входа недоступен из приложения.');
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сброс пароля'),
        content: Text(
          'Отправить письмо со ссылкой для нового пароля на адрес\n$email?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _toast('Письмо отправлено. Проверьте почту (и папку «Спам»).');
    } catch (e) {
      if (!mounted) return;
      _toast('Не удалось отправить письмо: $e', isError: true);
    }
  }

  Future<void> _openSupport() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 20),
              Text(
                'Помощь',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '• Проверьте интернет и что вы вошли в аккаунт.\n'
                '• Уведомления: разрешите их для Zhasau в настройках телефона.\n'
                '• Пароль от почты: раздел «Пароль и безопасность».\n'
                '• Загрузка фото: в Firebase должен быть включён Storage.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: _kSupportEmail),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  _toast('Адрес скопирован: $_kSupportEmail');
                },
                icon: const Icon(Icons.copy_rounded, size: 20),
                label: const Text('Скопировать e-mail поддержки'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri(
                    scheme: 'mailto',
                    path: _kSupportEmail,
                    queryParameters: const {
                      'subject': 'Zhasau — вопрос',
                    },
                  );
                  try {
                    final launched = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!ctx.mounted) return;
                    if (!launched) {
                      await Clipboard.setData(
                    const ClipboardData(text: _kSupportEmail),
                  );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      _toast('Почта не открылась — адрес скопирован', isError: true);
                      return;
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  } catch (_) {
                    if (!ctx.mounted) return;
                    await Clipboard.setData(
                    const ClipboardData(text: _kSupportEmail),
                  );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    _toast('Адрес поддержки скопирован в буфер');
                  }
                },
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Написать в поддержку'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    bool darkMode = AppColors.isDarkMode.value;
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.bgMain,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderDark),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Настройки',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Для баланса центрирования
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Секция Аккаунт
                    _sectionTitle('АККАУНТ'),
                    _settingsCard([
                      _settingsItem(
                        icon: Icons.person_rounded,
                        color: AppColors.blue,
                        title: 'Профиль',
                        subtitle: [
                          AppStore.instance.userProfile.name,
                          if (AppStore.instance.userProfile.email !=
                                  null &&
                              AppStore.instance.userProfile.email!.isNotEmpty)
                            AppStore.instance.userProfile.email!,
                        ].join('\n'),
                        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          );
                        },
                      ),
                      _divider(),
                      _settingsItem(
                        icon: Icons.lock_rounded,
                        color: AppColors.warning,
                        title: 'Пароль и безопасность',
                        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        onTap: _openPasswordSecurity,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Секция Приложение
                    _sectionTitle('ПРИЛОЖЕНИЕ'),
                    _settingsCard([
                      _settingsSwitch(
                        icon: Icons.notifications_active_rounded,
                        color: AppColors.primary,
                        title: 'Уведомления',
                        value: _notificationsEnabled,
                        onChanged: (v) => setState(() => _notificationsEnabled = v),
                      ),
                      _divider(),
                      _settingsSwitch(
                        icon: Icons.volume_up_rounded,
                        color: AppColors.success,
                        title: 'Звуки достижения',
                        value: _soundEnabled,
                        onChanged: (v) => setState(() => _soundEnabled = v),
                      ),
                      _divider(),
                      _settingsSwitch(
                        icon: Icons.dark_mode_rounded,
                        color: AppColors.textDark,
                        title: 'Темная тема',
                        value: darkMode,
                        onChanged: (v) {
                          AppColors.toggleTheme(v);
                        },
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Секция Google Calendar
                    _sectionTitle('ИНТЕГРАЦИИ'),
                    ValueListenableBuilder<bool>(
                      valueListenable: GoogleCalendarService.instance.isSyncEnabled,
                      builder: (context, syncEnabled, _) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: GoogleCalendarService.instance.accountEmail,
                          builder: (context, email, _) {
                            return _settingsCard([
                              _settingsSwitch(
                                icon: Icons.calendar_month_rounded,
                                color: AppColors.blue,
                                title: 'Google Calendar',
                                value: syncEnabled,
                                onChanged: (v) async {
                                  if (v) {
                                    final ok = await GoogleCalendarService.instance.signIn();
                                    if (!context.mounted) return;
                                    if (ok) {
                                      _toast('Google Calendar подключен!');
                                    } else {
                                      _toast('Не удалось подключить', isError: true);
                                    }
                                  } else {
                                    await GoogleCalendarService.instance.signOut();
                                    if (!context.mounted) return;
                                    _toast('Google Calendar отключен');
                                  }
                                  setState(() {});
                                },
                              ),
                              if (syncEnabled && email != null) ...[
                                _divider(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.blueLight,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(Icons.email_outlined, color: AppColors.blue, size: 20),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Аккаунт',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              email,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textDark,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _divider(),
                                ValueListenableBuilder<bool>(
                                  valueListenable: GoogleCalendarService.instance.isSyncing,
                                  builder: (context, syncing, _) {
                                    return InkWell(
                                      onTap: syncing ? null : () => _syncAll(),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppColors.successLight,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: syncing
                                                  ? SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: AppColors.success,
                                                      ),
                                                    )
                                                  : Icon(Icons.sync_rounded, color: AppColors.success, size: 20),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                syncing ? 'Синхронизация...' : 'Синхронизировать всё',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ]);
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Секция Прочее
                    _sectionTitle('ПРОЧЕЕ'),
                    _settingsCard([
                      _settingsItem(
                        icon: Icons.help_outline_rounded,
                        color: AppColors.textLight,
                        title: 'Поддержка и помощь',
                        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        onTap: _openSupport,
                      ),
                      _divider(),
                      _settingsItem(
                        icon: Icons.info_outline_rounded,
                        color: AppColors.textLight,
                        title: 'О приложении',
                        trailing: Text('Версия 1.0.0',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onTap: () => _toast('Zhasau App v1.0.0'),
                      ),
                    ]),

                    const SizedBox(height: 40),

                    // Кнопка выхода
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          await PushNotificationBridge.beforeSignOut();
                          await _authService.signOut();
                          await _localAuthService.signOut();
                          await AppStore.instance.resetSession();
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => const SplashScreen(),
                              transitionsBuilder: (_, anim, __, child) =>
                                  FadeTransition(opacity: anim, child: child),
                            ),
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.red, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text('Выйти из аккаунта',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red,
                          ),
                        ),
                      ),
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

  Future<void> _syncAll() async {
    final gcal = GoogleCalendarService.instance;
    gcal.isSyncing.value = true;

    try {
      final habits = await _habitService.getAllHabitsOnce();
      for (final habit in habits) {
        final eventId = await gcal.syncHabitToCalendar(habit);
        if (eventId != null &&
            eventId.isNotEmpty &&
            eventId != habit.calendarEventId &&
            habit.id != null &&
            habit.id!.isNotEmpty) {
          await _habitService.updateHabit(
            habit.copyWith(calendarEventId: eventId),
          );
        }
      }

      final store = AppStore.instance;
      for (final goal in store.goals) {
        for (final task in store.tasks.where((t) => t.goalId == goal.id)) {
          final eventId = await gcal.syncGoalTaskToCalendar(task, goal);
          if (eventId != null &&
              eventId.isNotEmpty &&
              eventId != task.calendarEventId) {
            await store.updateTask(task.copyWith(calendarEventId: eventId));
          }
        }
      }

      final goals = AppStore.instance.goals;
      for (final goal in goals) {
        final eventId = await gcal.syncGoalToCalendar(goal);
        if (eventId != null &&
            eventId.isNotEmpty &&
            eventId != goal.calendarEventId) {
          await AppStore.instance
              .updateGoal(goal.copyWith(calendarEventId: eventId));
        }
      }
      if (mounted) {
        _toast('Синхронизация завершена!');
      }
    } catch (e) {
      if (mounted) {
        _toast('Ошибка синхронизации', isError: true);
      }
    } finally {
      gcal.isSyncing.value = false;
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 10),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _settingsItem({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _settingsSwitch({
    required IconData icon,
    required Color color,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.borderDark,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border,
      indent: 52, // Отступ слева, чтобы линия начиналась после иконки
    );
  }
}
