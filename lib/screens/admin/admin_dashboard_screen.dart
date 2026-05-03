import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';
import '../../services/admin_service.dart';
import 'admin_user_detail_screen.dart';

/// Встроенная панель администратора: каталог пользователей Firestore `users`.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _admin = AdminService();
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: const Text(
          'Админ-панель',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Поиск по имени или почте',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.bgWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.borderDark),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<AdminUserListItem>>(
        stream: _admin.watchUserDirectory(),
        builder: (context, snap) {
          if (snap.hasError) {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '—';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить список.\n'
                  'Проверьте правила Firestore и документ admins/$uid.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.red, height: 1.35),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final filtered = _query.isEmpty
              ? all
              : all.where((u) {
                  final q = _query;
                  return u.name.toLowerCase().contains(q) ||
                      (u.email?.toLowerCase().contains(q) ?? false) ||
                      u.id.toLowerCase().contains(q);
                }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                _query.isEmpty ? 'Нет пользователей' : 'Никого не найдено',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final u = filtered[i];
              return Material(
                color: AppColors.bgWhite,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminUserDetailScreen(item: u),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        UserAvatar(
                          displayName: u.name,
                          photoUrl: u.photoUrl,
                          radius: 22,
                          fallbackToAuthPhoto: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (u.email != null) u.email!,
                                  'Ур. ${u.level} · ${u.xp} XP · ${u.coins} мон.',
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
