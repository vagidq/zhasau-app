import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../data/mock_data.dart';
import 'main_shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Локальные состояния для свитчеров
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;

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
                        subtitle: MockData.user.name,
                        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        onTap: () => MainShell.of(context).showToast('Настройки профиля'),
                      ),
                      _divider(),
                      _settingsItem(
                        icon: Icons.lock_rounded,
                        color: AppColors.warning,
                        title: 'Пароль и безопасность',
                        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        onTap: () => MainShell.of(context).showToast('Безопасность'),
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

                    // Секция Прочее
                    _sectionTitle('ПРОЧЕЕ'),
                    _settingsCard([
                      _settingsItem(
                        icon: Icons.help_outline_rounded,
                        color: AppColors.textLight,
                        title: 'Поддержка и помощь',
                        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        onTap: () => MainShell.of(context).showToast('Раздел поддержки'),
                      ),
                      _divider(),
                      _settingsItem(
                        icon: Icons.info_outline_rounded,
                        color: AppColors.textLight,
                        title: 'О приложении',
                        trailing: Text('Версия 1.0.0',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onTap: () => MainShell.of(context).showToast('Zhasau App v1.0.0'),
                      ),
                    ]),

                    const SizedBox(height: 40),

                    // Кнопка выхода
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          MainShell.of(context).showToast('Вы вышли из аккаунта');
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
                color: color.withOpacity(0.15),
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
              color: color.withOpacity(0.15),
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
