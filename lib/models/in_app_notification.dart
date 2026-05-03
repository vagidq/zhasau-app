import 'package:cloud_firestore/cloud_firestore.dart';

/// Тип внутриигрового уведомления (значение в Firestore `type`).
class InAppNotificationTypes {
  InAppNotificationTypes._();

  static const achievement = 'achievement';
}

class InAppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;
  final String? achievementId;

  const InAppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.achievementId,
  });

  factory InAppNotification.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    DateTime? created;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      created = raw.toDate();
    }
    return InAppNotification(
      id: doc.id,
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: created,
      achievementId: data['achievementId'] as String?,
    );
  }
}
