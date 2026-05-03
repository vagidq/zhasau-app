import 'package:flutter/material.dart';
import '../models/app_store.dart';
import '../models/in_app_notification.dart';
import '../theme/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static String _formatTime(DateTime? t) {
    if (t == null) return 'сейчас';
    final now = DateTime.now();
    final d = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return 'Сегодня, $h:$m';
    }
    if (d == today.subtract(const Duration(days: 1))) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return 'Вчера, $h:$m';
    }
    return '${t.day.toString().padLeft(2, '0')}.'
        '${t.month.toString().padLeft(2, '0')}.'
        '${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final list = AppStore.instance.notifications;
        return Scaffold(
          backgroundColor: AppColors.bgMain,
          appBar: AppBar(
            backgroundColor: AppColors.bgWhite,
            elevation: 0,
            foregroundColor: AppColors.textDark,
            title: const Text(
              'Уведомления',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            actions: [
              if (AppStore.instance.unreadNotificationCount > 0)
                TextButton(
                  onPressed: () =>
                      AppStore.instance.markAllInAppNotificationsRead(),
                  child: Text(
                    'Прочитать все',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          body: list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 56,
                          color: AppColors.textLight.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Пока пусто',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Здесь появятся награды и другие события.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final n = list[i];
                    final isAch =
                        n.type == InAppNotificationTypes.achievement;
                    return Material(
                      color: AppColors.bgWhite,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (!n.read) {
                            AppStore.instance.markInAppNotificationRead(n.id);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isAch
                                      ? AppColors.warningLight
                                      : AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isAch
                                      ? Icons.emoji_events_rounded
                                      : Icons.info_outline_rounded,
                                  color: isAch
                                      ? AppColors.warning
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: n.read
                                                  ? AppColors.textLight
                                                  : AppColors.textDark,
                                            ),
                                          ),
                                        ),
                                        if (!n.read)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      n.body,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatTime(n.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textLight
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
