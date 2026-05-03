import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/admin_service.dart';

/// Карточка пользователя для админа (только чтение).
class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({super.key, required this.item});

  final AdminUserListItem item;

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final AdminService _admin = AdminService();
  Map<String, dynamic>? _doc;
  AdminUserSubcounts? _counts;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await _admin.fetchUserDocument(widget.item.id);
      final counts = await _admin.fetchSubcounts(widget.item.id);
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _counts = counts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.item;
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: Text(
          u.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Ошибка: $_error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.red),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _card(
                        title: 'Идентификатор',
                        child: SelectableText(
                          u.id,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _card(
                        title: 'Профиль',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _kv('Имя', u.name),
                            if (u.email != null) _kv('Почта', u.email!),
                            _kv('Уровень', '${u.level}'),
                            _kv('XP', '${u.xp}'),
                            _kv('Монеты', '${u.coins}'),
                            _kv('Задач выполнено', '${u.completedTasks}'),
                            _kv('Стрик', '${u.streak} дн.'),
                          ],
                        ),
                      ),
                      if (_counts != null) ...[
                        const SizedBox(height: 12),
                        _card(
                          title: 'Подколлекции (оценка)',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _kv('Цели', '${_counts!.goals}'),
                              _kv('Задачи целей', '${_counts!.tasks}'),
                              _kv('Привычки', '${_counts!.habits}'),
                              _kv('Уведомления', '${_counts!.notifications}'),
                              _kv('Покупки магазина',
                                  '${_counts!.shopPurchases}'),
                              _kv('Награды магазина',
                                  '${_counts!.shopRewards}'),
                            ],
                          ),
                        ),
                      ],
                      if (_doc != null) ...[
                        const SizedBox(height: 12),
                        _card(
                          title: 'Доп. поля',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildExtraLines(_doc!),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Изменение данных других пользователей из приложения недоступно.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildExtraLines(Map<String, dynamic> doc) {
    const hideKeys = {
      'fcmToken',
      'weeklyActivity',
      'weeklyXp',
      'weeklyCoins',
      'unlockedAchievements',
      'shopHiddenBuiltinIds',
    };
    final lines = <Widget>[];
    for (final e in doc.entries) {
      if (hideKeys.contains(e.key)) continue;
      final v = e.value;
      if (v == null) continue;
      final text = '$v';
      if (text.isEmpty) continue;
      lines.add(_kv(e.key, text));
    }
    return lines;
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(v, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
