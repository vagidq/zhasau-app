import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Сводка строки в списке пользователей (админка).
class AdminUserListItem {
  final String id;
  final String name;
  final String? email;
  final String? photoUrl;
  final int level;
  final int xp;
  final int coins;
  final int completedTasks;
  final int streak;

  const AdminUserListItem({
    required this.id,
    required this.name,
    this.email,
    this.photoUrl,
    required this.level,
    required this.xp,
    required this.coins,
    required this.completedTasks,
    required this.streak,
  });

  static AdminUserListItem fromDoc(String id, Map<String, dynamic> data) {
    return AdminUserListItem(
      id: id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Без имени',
      email: (data['email'] as String?)?.trim().isEmpty == true
          ? null
          : data['email'] as String?,
      photoUrl: (data['photoUrl'] as String?)?.trim().isEmpty == true
          ? null
          : (data['photoUrl'] as String?)?.trim(),
      level: (data['level'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      completedTasks: (data['completedTasks'] as num?)?.toInt() ?? 0,
      streak: (data['streak'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Доступ к данным для встроенной админ-панели (чтение по правилам Firestore).
class AdminService {
  AdminService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Реагирует на смену аккаунта (email / аноним / Google), а не только на первый снимок.
  Stream<bool> watchIsAdmin() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null || user.uid.isEmpty) {
        return Stream<bool>.value(false);
      }
      return _db
          .collection('admins')
          .doc(user.uid)
          .snapshots()
          .map((s) => s.exists);
    });
  }

  Stream<List<AdminUserListItem>> watchUserDirectory() {
    return _db.collection('users').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => AdminUserListItem.fromDoc(d.id, d.data()))
          .toList(growable: false);
      list.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return list;
    });
  }

  Future<Map<String, dynamic>?> fetchUserDocument(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data();
  }

  Future<AdminUserSubcounts> fetchSubcounts(String userId) async {
    final base = _db.collection('users').doc(userId);
    try {
      final goals = (await base.collection('goals').count().get()).count ?? 0;
      final tasks = (await base.collection('tasks').count().get()).count ?? 0;
      final habits = (await base.collection('habits').count().get()).count ?? 0;
      final notifications =
          (await base.collection('notifications').count().get()).count ?? 0;
      final shopPurchases =
          (await base.collection('shopPurchases').count().get()).count ?? 0;
      final shopRewards =
          (await base.collection('shopRewards').count().get()).count ?? 0;
      return AdminUserSubcounts(
        goals: goals,
        tasks: tasks,
        habits: habits,
        notifications: notifications,
        shopPurchases: shopPurchases,
        shopRewards: shopRewards,
      );
    } catch (_) {
      final goals =
          (await base.collection('goals').limit(2000).get()).docs.length;
      final tasks =
          (await base.collection('tasks').limit(2000).get()).docs.length;
      final habits =
          (await base.collection('habits').limit(2000).get()).docs.length;
      final notifications =
          (await base.collection('notifications').limit(500).get()).docs.length;
      final shopPurchases =
          (await base.collection('shopPurchases').limit(500).get()).docs.length;
      final shopRewards =
          (await base.collection('shopRewards').limit(500).get()).docs.length;
      return AdminUserSubcounts(
        goals: goals,
        tasks: tasks,
        habits: habits,
        notifications: notifications,
        shopPurchases: shopPurchases,
        shopRewards: shopRewards,
      );
    }
  }
}

class AdminUserSubcounts {
  final int goals;
  final int tasks;
  final int habits;
  final int notifications;
  final int shopPurchases;
  final int shopRewards;

  const AdminUserSubcounts({
    required this.goals,
    required this.tasks,
    required this.habits,
    required this.notifications,
    required this.shopPurchases,
    required this.shopRewards,
  });
}
