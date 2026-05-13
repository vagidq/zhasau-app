import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/goal_model.dart';
import '../models/goal_xp_rules.dart';
import '../models/in_app_notification.dart';
import '../models/task_model.dart';
import '../models/user_profile.dart';
import '../utils/firestore_ids.dart';
import 'current_user_doc.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ID документа `users/{...}` для текущего пользователя.
  ///
  /// После миграции на читаемые ID возвращает читаемое имя (`user-damir-x4f9`),
  /// иначе — `auth uid` (старый формат). Кеш заполняется при старте приложения,
  /// см. `CurrentUserDoc.bootstrap()`.
  String get userId {
    final cached = CurrentUserDoc.cachedDocId();
    if (cached != null) return cached;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  // Goals
  CollectionReference get _goalsCollection =>
      _firestore.collection('users').doc(userId).collection('goals');

  Future<void> addGoal(GoalModel goal) async {
    await _goalsCollection.doc(goal.id).set({
      'id': goal.id,
      'title': goal.title,
      'subtitle': goal.subtitle,
      'badge': goal.badge,
      'iconName': goal.iconName,
      'color': goal.color.toString().split('.').last,
      'progress': goal.progress,
      'tasksLeft': goal.tasksLeft,
      'deadline': goal.deadline?.toIso8601String(),
      'startDate': goal.startDate.toIso8601String(),
      if (goal.calendarEventId != null) 'calendarEventId': goal.calendarEventId,
      'xpTaskPool': goal.xpTaskPool,
      'xpCompletionBonus': goal.xpCompletionBonus,
      'coinsCompletionBonus': goal.coinsCompletionBonus,
      'completionBonusGranted': goal.completionBonusGranted,
    });
  }

  Future<void> updateGoal(GoalModel goal) async {
    await _goalsCollection.doc(goal.id).update({
      'title': goal.title,
      'subtitle': goal.subtitle,
      'badge': goal.badge,
      'iconName': goal.iconName,
      'color': goal.color.toString().split('.').last,
      'progress': goal.progress,
      'tasksLeft': goal.tasksLeft,
      'deadline': goal.deadline?.toIso8601String(),
      'startDate': goal.startDate.toIso8601String(),
      'calendarEventId': goal.calendarEventId,
      'xpTaskPool': goal.xpTaskPool,
      'xpCompletionBonus': goal.xpCompletionBonus,
      'coinsCompletionBonus': goal.coinsCompletionBonus,
      'completionBonusGranted': goal.completionBonusGranted,
    });
  }

  Future<void> deleteGoal(String goalId) async {
    await _goalsCollection.doc(goalId).delete();
    // Also delete tasks for this goal
    final tasks = await _tasksCollection.where('goalId', isEqualTo: goalId).get();
    for (var doc in tasks.docs) {
      await doc.reference.delete();
    }
  }

  Stream<List<GoalModel>> getGoals() {
    return _goalsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        GoalColor color;
        switch ((data['color'] as String?)?.toLowerCase()) {
          case 'warning':
            color = GoalColor.warning;
            break;
          case 'success':
            color = GoalColor.success;
            break;
          default:
            color = GoalColor.blue;
        }

        return GoalModel(
          id: data['id'] ?? doc.id,
          title: data['title'] ?? '',
          subtitle: data['subtitle'] ?? '',
          badge: data['badge'] ?? '',
          iconName: data['iconName'] ?? 'fitness',
          color: color,
          progress: (data['progress'] as num?)?.toInt() ?? 0,
          tasksLeft: (data['tasksLeft'] as num?)?.toInt() ?? 0,
          deadline: data['deadline'] != null ? DateTime.parse(data['deadline']) : null,
          startDate: data['startDate'] != null ? DateTime.parse(data['startDate']) : null,
          calendarEventId: data['calendarEventId'] as String?,
          xpTaskPool: (data['xpTaskPool'] as num?)?.toInt() ??
              GoalXpRules.defaultTaskPool,
          xpCompletionBonus:
              (data['xpCompletionBonus'] as num?)?.toInt() ??
                  GoalXpRules.defaultCompletionBonus,
          coinsCompletionBonus:
              (data['coinsCompletionBonus'] as num?)?.toInt() ?? 0,
          completionBonusGranted:
              data['completionBonusGranted'] as bool? ?? false,
        );
      }).toList();
    });
  }

  // Tasks
  CollectionReference get _tasksCollection =>
      _firestore.collection('users').doc(userId).collection('tasks');

  Future<void> addTask(TaskModel task) async {
    await _tasksCollection.doc(task.id).set({
      'id': task.id,
      'goalId': task.goalId,
      'title': task.title,
      'subtitle': task.subtitle,
      'reward': task.reward,
      'isXp': task.isXp,
      'tagText': task.tag?.text,
      'tagType': task.tag?.type.toString().split('.').last,
      'completed': task.completed,
      if (task.scheduledAt != null)
        'scheduledAt': task.scheduledAt!.toIso8601String(),
      if (task.calendarEventId != null) 'calendarEventId': task.calendarEventId,
      if (task.completedAt != null)
        'completedAt': Timestamp.fromDate(task.completedAt!),
    });
  }

  Future<void> updateTask(TaskModel task) async {
    final patch = <String, dynamic>{
      'title': task.title,
      'subtitle': task.subtitle,
      'reward': task.reward,
      'isXp': task.isXp,
      'tagText': task.tag?.text,
      'tagType': task.tag?.type.toString().split('.').last,
      'completed': task.completed,
    };
    if (task.scheduledAt != null) {
      patch['scheduledAt'] = task.scheduledAt!.toIso8601String();
    }
    if (task.calendarEventId != null) {
      patch['calendarEventId'] = task.calendarEventId;
    }
    if (task.completedAt != null) {
      patch['completedAt'] = Timestamp.fromDate(task.completedAt!);
    } else {
      patch['completedAt'] = FieldValue.delete();
    }
    await _tasksCollection.doc(task.id).update(patch);
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
  }

  Stream<List<TaskModel>> getTasks() {
    return _tasksCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        TagType? tagType;
        if (data['tagType'] != null) {
          switch (data['tagType'] as String) {
            case 'high':
              tagType = TagType.high;
              break;
            case 'medium':
              tagType = TagType.medium;
              break;
            case 'repeat':
              tagType = TagType.repeat;
              break;
          }
        }

        TaskTag? tag;
        if (data['tagText'] != null && tagType != null) {
          tag = TaskTag(text: data['tagText'], type: tagType);
        }

        DateTime? scheduledAt;
        final scheduledRaw = data['scheduledAt'];
        if (scheduledRaw is String) {
          scheduledAt = DateTime.tryParse(scheduledRaw);
        } else if (scheduledRaw is Timestamp) {
          scheduledAt = scheduledRaw.toDate();
        }

        DateTime? completedAt;
        final completedRaw = data['completedAt'];
        if (completedRaw is Timestamp) {
          completedAt = completedRaw.toDate();
        } else if (completedRaw is String) {
          completedAt = DateTime.tryParse(completedRaw);
        }

        return TaskModel(
          id: data['id'] ?? doc.id,
          title: data['title'] ?? '',
          subtitle: data['subtitle'] ?? '',
          goalId: data['goalId'],
          scheduledAt: scheduledAt,
          calendarEventId: data['calendarEventId'] as String?,
          reward: (data['reward'] as num?) ?? 0,
          isXp: data['isXp'] ?? true,
          tag: tag,
          completed: data['completed'] ?? false,
          completedAt: completedAt,
        );
      }).toList();
    });
  }

  // User profile
  Future<void> initializeUserProfile(String name, {String? email}) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (authUid.isEmpty) {
      throw Exception('User not authenticated');
    }
    final docId = makeReadableId(
      'user',
      name.trim().isNotEmpty ? name : (email ?? 'user'),
    );
    await _firestore.collection('users').doc(docId).set({
      'uid': authUid,
      'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      'level': 1,
      'xp': 0,
      'xpMax': 1000,
      'coins': 0,
      'completedTasks': 0,
      'streak': 0,
      'lastTaskCompletedDate': null,
      'weeklyActivity': <int>[0, 0, 0, 0, 0, 0, 0],
      'weeklyXp': <int>[0, 0, 0, 0, 0, 0, 0],
      'weeklyCoins': <int>[0, 0, 0, 0, 0, 0, 0],
      'weeklyChartWeekMonday': UserProfile.mondayKeyFor(DateTime.now()),
      'unlockedAchievements': <String>[],
      'shopHiddenBuiltinIds': <String>[],
      'highPriorityCompletions': 0,
      'completionsBeforeNine': 0,
      'bio': '',
    });
    CurrentUserDoc.rememberFor(authUid, docId);
  }

  Stream<Map<String, dynamic>?> getUserProfile() {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      return doc.data();
    });
  }

  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    final ref = _firestore.collection('users').doc(userId);
    // Ensure doc exists (update fails if missing)
    await ref.set(updates, SetOptions(merge: true));
  }

  /// Текущий FCM-токен устройства (для серверных рассылок).
  Future<void> saveFcmTokenToProfile(String token) async {
    final t = token.trim();
    if (t.isEmpty) return;
    await _firestore.collection('users').doc(userId).set({
      'fcmToken': t,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearFcmTokenFromProfile() async {
    await _firestore.collection('users').doc(userId).set({
      'fcmToken': FieldValue.delete(),
      'fcmTokenUpdatedAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // In-app notifications (лента в приложении, не push ОС)
  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('users').doc(userId).collection('notifications');

  Stream<List<InAppNotification>> watchInAppNotifications({int limit = 80}) {
    return _notificationsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(InAppNotification.fromDoc).toList(growable: false));
  }

  Future<void> addInAppNotification({
    required String type,
    required String title,
    required String body,
    String? achievementId,
    String? goalId,
  }) async {
    final notifId = makeReadableId('notif', title.isNotEmpty ? title : type);
    await _notificationsCollection.doc(notifId).set({
      'type': type,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      if (achievementId != null && achievementId.isNotEmpty)
        'achievementId': achievementId,
      if (goalId != null && goalId.isNotEmpty) 'goalId': goalId,
    });
  }

  /// Удаляет уведомления, привязанные к цели (например «Цель достигнута!» при откате бонуса).
  Future<void> deleteInAppNotificationsWithGoalId(String goalId) async {
    if (goalId.isEmpty) return;
    try {
      final snap = await _notificationsCollection
          .where('goalId', isEqualTo: goalId)
          .limit(40)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (e, st) {
      debugPrint('deleteInAppNotificationsWithGoalId: $e\n$st');
    }
  }

  Future<void> markInAppNotificationRead(String notificationId) async {
    await _notificationsCollection.doc(notificationId).update({
      'read': true,
    });
  }

  Future<void> markAllInAppNotificationsRead() async {
    final batch = _firestore.batch();
    final snap =
        await _notificationsCollection.where('read', isEqualTo: false).get();
    for (final d in snap.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }
}