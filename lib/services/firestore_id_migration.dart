import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/firestore_ids.dart';
import 'current_user_doc.dart';

/// Одноразовая миграция: переименовать документы Firestore из автогенерируемых
/// "шифров" в человекочитаемые ID (`habit-...`, `task-...`, `goal-...`,
/// `notif-...`).
///
/// Запускается автоматически при первом входе пользователя после релиза. Флаг
/// сохраняется в `SharedPreferences` отдельно для каждого Firebase uid, чтобы
/// не повторять переименование.
class FirestoreIdMigration {
  FirestoreIdMigration._();

  static final FirestoreIdMigration instance = FirestoreIdMigration._();

  // v2: переименование самого `users/{uid}` стало возможным после обновления
  // Firestore rules (в v1 правила запрещали запись по пути ≠ auth.uid и доку
  // оставался под старым именем).
  static const _kPrefsPrefix = 'firestore_id_migration_v2_done_';
  static const _legacyHabitsName = 'habit';
  static const _legacyTasksName = 'task';
  static const _legacyGoalsName = 'goal';
  static const _legacyNotifsName = 'notif';

  bool _running = false;

  /// Безопасно запустить миграцию для текущего пользователя. Не бросает.
  Future<void> runIfNeeded(String firebaseUid) async {
    if (firebaseUid.isEmpty || _running) return;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kPrefsPrefix$firebaseUid';
      if (prefs.getBool(key) ?? false) {
        // Кеш `CurrentUserDoc` мог быть сброшен после рестарта приложения —
        // прогреем его, чтобы все сервисы сразу видели читаемый docId.
        await CurrentUserDoc.bootstrap();
        return;
      }

      final newDocRef = await _migrateUserRootDoc(firebaseUid);

      await _migrateGoalsAndTasks(newDocRef);
      await _migrateSimpleCollection(
        newDocRef.collection('habits'),
        prefix: _legacyHabitsName,
      );
      await _migrateSimpleCollection(
        newDocRef.collection('notifications'),
        prefix: _legacyNotifsName,
      );

      await prefs.setBool(key, true);
      debugPrint('FirestoreIdMigration: завершено для uid=$firebaseUid');
    } catch (e, st) {
      debugPrint('FirestoreIdMigration error: $e\n$st');
    } finally {
      _running = false;
    }
  }

  /// Переименовать сам документ `users/{authUid}` в `users/{user-...}` со всеми
  /// subcollections и вернуть ссылку на новое местоположение. Идемпотентно: если
  /// данные уже лежат под читаемым ID — просто возвращает их.
  Future<DocumentReference<Map<String, dynamic>>> _migrateUserRootDoc(
    String firebaseUid,
  ) async {
    final users = FirebaseFirestore.instance.collection('users');

    // 1. Если уже есть документ с `uid == firebaseUid` и читаемым ID — возьмём его.
    try {
      final existing = await users
          .where('uid', isEqualTo: firebaseUid)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        final docId = existing.docs.first.id;
        CurrentUserDoc.rememberFor(firebaseUid, docId);
        if (docId != firebaseUid) return users.doc(docId);
        // Если каким-то образом по `uid` нашли документ с ID == auth uid,
        // продолжаем миграцию ниже.
      }
    } catch (e) {
      debugPrint('FirestoreIdMigration: where(uid) error: $e');
    }

    final oldRef = users.doc(firebaseUid);
    final oldSnap = await oldRef.get();
    if (!oldSnap.exists) {
      // Нет данных — ничего переносить не надо. Возвращаем (пустой) auth uid doc.
      CurrentUserDoc.rememberFor(firebaseUid, firebaseUid);
      return oldRef;
    }

    final data = Map<String, dynamic>.from(oldSnap.data() ?? <String, dynamic>{});
    data['uid'] = firebaseUid;
    final name = (data['name'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    final source = (name != null && name.isNotEmpty)
        ? name
        : (email != null && email.isNotEmpty ? email : 'user');
    final newId = makeReadableId('user', source);
    final newRef = users.doc(newId);

    await newRef.set(data);

    // 2. Перенести все известные subcollections.
    const subcollections = <String>[
      'goals',
      'tasks',
      'habits',
      'notifications',
      'shopRewards',
      'shopPurchases',
    ];
    for (final sub in subcollections) {
      try {
        final snap = await oldRef.collection(sub).get();
        for (final d in snap.docs) {
          await newRef.collection(sub).doc(d.id).set(d.data());
          await d.reference.delete();
        }
      } catch (e) {
        debugPrint('FirestoreIdMigration: subcollection $sub error: $e');
      }
    }

    try {
      await oldRef.delete();
    } catch (e) {
      debugPrint('FirestoreIdMigration: delete old user doc error: $e');
    }

    CurrentUserDoc.rememberFor(firebaseUid, newId);
    debugPrint('FirestoreIdMigration: user moved $firebaseUid -> $newId');
    return newRef;
  }

  /// Документ с этим ID уже выглядит "по-новому" → переименовывать не нужно.
  bool _looksReadable(String id, String prefix) {
    return id.startsWith('$prefix-');
  }

  /// Переименовать документы коллекции, у которой нет внешних ссылок (habits, notifications).
  Future<void> _migrateSimpleCollection(
    CollectionReference<Map<String, dynamic>> coll, {
    required String prefix,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await coll.get();
    for (final doc in snap.docs) {
      final oldId = doc.id;
      if (_looksReadable(oldId, prefix)) continue;
      final data = doc.data();
      final title = (data['title'] as String?)?.trim();
      final fallback = (data['type'] as String?)?.trim();
      final source = (title != null && title.isNotEmpty)
          ? title
          : (fallback != null && fallback.isNotEmpty ? fallback : 'item');
      final newId = makeReadableId(prefix, source);

      try {
        await coll.doc(newId).set(data);
        await coll.doc(oldId).delete();
        debugPrint('Migrated $prefix: $oldId -> $newId');
      } catch (e) {
        debugPrint('Migrate $prefix $oldId failed: $e');
      }
    }
  }

  /// Goals + Tasks связаны через `tasks.goalId == goals.id`, поэтому их нужно
  /// переписать согласованно: сперва строим маппинг старых → новых ID, затем
  /// записываем заново.
  Future<void> _migrateGoalsAndTasks(
    DocumentReference<Map<String, dynamic>> root,
  ) async {
    final goalsRef = root.collection('goals');
    final tasksRef = root.collection('tasks');

    final goalsSnap = await goalsRef.get();
    final Map<String, String> goalIdMap = <String, String>{}; // old -> new
    final Map<String, Map<String, dynamic>> newGoalsData =
        <String, Map<String, dynamic>>{};

    for (final goalDoc in goalsSnap.docs) {
      final oldId = goalDoc.id;
      final data = Map<String, dynamic>.from(goalDoc.data());
      if (_looksReadable(oldId, _legacyGoalsName)) {
        goalIdMap[oldId] = oldId;
        continue;
      }
      final title = (data['title'] as String?)?.trim();
      final newId = makeReadableId(
        _legacyGoalsName,
        title != null && title.isNotEmpty ? title : 'goal',
      );
      goalIdMap[oldId] = newId;
      data['id'] = newId;
      newGoalsData[newId] = data;
    }

    final tasksSnap = await tasksRef.get();
    final Map<String, Map<String, dynamic>> newTasksData =
        <String, Map<String, dynamic>>{};
    final List<String> tasksToDelete = <String>[];

    for (final taskDoc in tasksSnap.docs) {
      final oldId = taskDoc.id;
      final data = Map<String, dynamic>.from(taskDoc.data());

      final oldGoalId = data['goalId'] as String?;
      if (oldGoalId != null && goalIdMap.containsKey(oldGoalId)) {
        data['goalId'] = goalIdMap[oldGoalId];
      }

      if (_looksReadable(oldId, _legacyTasksName)) {
        // Если у задачи поменялся goalId, всё равно надо записать обновление.
        if (oldGoalId != null && goalIdMap[oldGoalId] != oldGoalId) {
          newTasksData[oldId] = data;
        }
        continue;
      }
      final title = (data['title'] as String?)?.trim();
      final newId = makeReadableId(
        _legacyTasksName,
        title != null && title.isNotEmpty ? title : 'task',
      );
      data['id'] = newId;
      newTasksData[newId] = data;
      tasksToDelete.add(oldId);
    }

    // Сначала пишем новые цели и задачи, потом удаляем старые — так FK всегда валидны.
    for (final entry in newGoalsData.entries) {
      try {
        await goalsRef.doc(entry.key).set(entry.value);
      } catch (e) {
        debugPrint('Migrate goal ${entry.key} write failed: $e');
      }
    }
    for (final entry in newTasksData.entries) {
      try {
        await tasksRef.doc(entry.key).set(entry.value);
      } catch (e) {
        debugPrint('Migrate task ${entry.key} write failed: $e');
      }
    }

    for (final oldGoalId in goalIdMap.keys) {
      if (goalIdMap[oldGoalId] == oldGoalId) continue;
      try {
        await goalsRef.doc(oldGoalId).delete();
      } catch (e) {
        debugPrint('Delete old goal $oldGoalId failed: $e');
      }
    }
    for (final oldTaskId in tasksToDelete) {
      try {
        await tasksRef.doc(oldTaskId).delete();
      } catch (e) {
        debugPrint('Delete old task $oldTaskId failed: $e');
      }
    }
  }
}
