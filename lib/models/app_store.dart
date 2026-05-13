import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../achievements/achievement_catalog.dart';
import '../models/goal_model.dart';
import '../models/in_app_notification.dart';
import '../models/task_model.dart';
import '../models/user_profile.dart';
import '../services/current_user_doc.dart';
import '../services/google_calendar_service.dart';
import '../services/user_service.dart';

String _resolvedProfileName(Map<String, dynamic> data) {
  final fromFs = (data['name'] as String?)?.trim();
  if (fromFs != null && fromFs.isNotEmpty) return fromFs;
  final fromAuth = FirebaseAuth.instance.currentUser?.displayName?.trim();
  if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;
  return 'Пользователь';
}

class AppStore extends ChangeNotifier {
  static final AppStore instance = AppStore._internal();

  AppStore._internal();

  final UserService _userService = UserService();

  final List<GoalModel> _goals = [];
  final List<TaskModel> _tasks = [];
  /// Safe default until Firestore emits or [initializeEmptyProfile] runs.
  UserProfile _userProfile = UserProfile(
    id: '',
    name: 'Пользователь',
    email: null,
    bio: '',
    photoUrl: null,
    level: 1,
    xp: 0,
    coins: 0,
    completedTasks: 0,
    streak: 0,
    shopHiddenBuiltinIds: const [],
    weeklyChartWeekMonday: UserProfile.mondayKeyFor(DateTime.now()),
  );

  List<GoalModel> get goals => List.unmodifiable(_goals);
  List<TaskModel> get tasks => List.unmodifiable(_tasks);
  UserProfile get userProfile => _userProfile;

  List<InAppNotification> _notifications = const [];
  List<InAppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationCount =>
      _notifications.where((n) => !n.read).length;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasProfile = false;
  bool get hasProfile => _hasProfile;

  StreamSubscription<dynamic>? _userProfileSub;
  StreamSubscription<dynamic>? _goalsSub;
  StreamSubscription<dynamic>? _tasksSub;
  StreamSubscription<List<InAppNotification>>? _notificationsSub;

  /// Сброс кэша и отписка от Firestore при выходе или перед сменой аккаунта.
  Future<void> resetSession() async {
    await _userProfileSub?.cancel();
    await _goalsSub?.cancel();
    await _tasksSub?.cancel();
    await _notificationsSub?.cancel();
    _userProfileSub = null;
    _goalsSub = null;
    _tasksSub = null;
    _notificationsSub = null;

    _goals.clear();
    _tasks.clear();
    _notifications = const [];
    _hasProfile = false;
    _userProfile = UserProfile(
      id: '',
      name: 'Пользователь',
      email: null,
      bio: '',
      photoUrl: null,
      level: 1,
      xp: 0,
      coins: 0,
      completedTasks: 0,
      streak: 0,
      shopHiddenBuiltinIds: const [],
      weeklyChartWeekMonday: UserProfile.mondayKeyFor(DateTime.now()),
    );
    notifyListeners();
  }

  Future<void> loadUserData() async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.isNotEmpty) {
      try {
        await CurrentUserDoc.docId();
      } catch (e, st) {
        debugPrint('CurrentUserDoc.docId: $e\n$st');
      }
    }

    await _userProfileSub?.cancel();
    await _goalsSub?.cancel();
    await _tasksSub?.cancel();
    await _notificationsSub?.cancel();
    _userProfileSub = null;
    _goalsSub = null;
    _tasksSub = null;
    _notificationsSub = null;

    _goals.clear();
    _tasks.clear();
    _notifications = const [];

    _isLoading = true;
    notifyListeners();

    try {
      // User profile (XP/level/coins/streak)
      _userProfileSub = _userService.getUserProfile().listen((data) {
        if (data == null) {
          if (!_hasProfile) {
            initializeEmptyProfile();
            final dn = FirebaseAuth.instance.currentUser?.displayName?.trim();
            if (dn != null && dn.isNotEmpty) {
              _userProfile.name = dn;
            }
            final em = FirebaseAuth.instance.currentUser?.email?.trim();
            if (em != null && em.isNotEmpty) {
              _userProfile.email = em;
            }
            notifyListeners();
          }
          return;
        }

        final rawActivity = data['weeklyActivity'];
        final weeklyActivity = rawActivity is List
            ? List<int>.from(rawActivity.map((e) => (e as num?)?.toInt() ?? 0))
            : List<int>.filled(7, 0);

        final rawXp = data['weeklyXp'];
        final weeklyXp = rawXp is List
            ? List<int>.from(rawXp.map((e) => (e as num?)?.toInt() ?? 0))
            : List<int>.filled(7, 0);

        final rawCoins = data['weeklyCoins'];
        final weeklyCoins = rawCoins is List
            ? List<int>.from(rawCoins.map((e) => (e as num?)?.toInt() ?? 0))
            : List<int>.filled(7, 0);

        _userProfile = UserProfile(
          id: _userService.userId,
          name: _resolvedProfileName(data),
          email: data['email'] as String?,
          bio: (data['bio'] as String?) ?? '',
          photoUrl: data['photoUrl'] as String?,
          level: (data['level'] as num?)?.toInt() ?? 1,
          xp: (data['xp'] as num?)?.toInt() ?? 0,
          coins: (data['coins'] as num?)?.toInt() ?? 0,
          completedTasks: (data['completedTasks'] as num?)?.toInt() ?? 0,
          streak: (data['streak'] as num?)?.toInt() ?? 0,
          lastTaskCompletedDate: data['lastTaskCompletedDate'] != null
              ? DateTime.tryParse(data['lastTaskCompletedDate'] as String)
              : null,
          weeklyActivity: weeklyActivity,
          weeklyXp: weeklyXp,
          weeklyCoins: weeklyCoins,
          weeklyChartWeekMonday: data['weeklyChartWeekMonday'] as String?,
          unlockedAchievements: _parseStringIdList(data['unlockedAchievements']),
          shopHiddenBuiltinIds:
              _parseStringIdList(data['shopHiddenBuiltinIds']),
          highPriorityCompletions:
              (data['highPriorityCompletions'] as num?)?.toInt() ?? 0,
          completionsBeforeNine:
              (data['completionsBeforeNine'] as num?)?.toInt() ?? 0,
        );
        final weeklyRolled = _userProfile.ensureWeeklyBucketsForCurrentWeek();
        _hasProfile = true;
        final newAchievements = _mergeNewAchievements();
        if (newAchievements.isNotEmpty) {
          unawaited(_persistAndAchievementNotifications(newAchievements));
        }
        if (weeklyRolled) {
          unawaited(_persistUserProfile());
        }
        notifyListeners();
      });

      _notificationsSub =
          _userService.watchInAppNotifications().listen((list) {
        _notifications = list;
        notifyListeners();
      }, onError: (e, st) {
        debugPrint('Notifications stream: $e\n$st');
      });

      _goalsSub = _userService.getGoals().listen((goals) {
        _goals.clear();
        _goals.addAll(goals);
        notifyListeners();
      });

      _tasksSub = _userService.getTasks().listen((tasks) {
        _tasks.clear();
        _tasks.addAll(tasks);
        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
      // Fallback so UI can render
      if (!_hasProfile) {
        initializeEmptyProfile();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<TaskModel> getTasksForGoal(String goalId) {
    return _tasks.where((t) => t.goalId == goalId).toList();
  }

  int goalProgressPercent(String goalId) {
    final goalTasks = getTasksForGoal(goalId);
    if (goalTasks.isEmpty) {
      final gIdx = _goals.indexWhere((g) => g.id == goalId);
      if (gIdx != -1 && _goals[gIdx].completionBonusGranted) {
        return 100;
      }
      return 0;
    }
    final completedTasks = goalTasks.where((t) => t.completed).length;
    return ((completedTasks / goalTasks.length) * 100).round();
  }

  int tasksLeft(String goalId) {
    final goalTasks = getTasksForGoal(goalId);
    return goalTasks.where((t) => !t.completed).length;
  }

  /// За отдельную задачу цели награда не выдаётся (награда только за полное выполнение цели).
  int xpRewardForGoalTask(TaskModel task) {
    final gid = task.goalId;
    if (gid == null || gid.isEmpty) return task.reward.toInt();
    return 0;
  }

  Future<void> recalculateGoalTaskRewards(String goalId) async {
    final tasks = getTasksForGoal(goalId);
    for (final t in tasks) {
      if (t.reward == 0) continue;
      await updateTask(t.copyWith(reward: 0));
    }
  }

  Future<void> _revokeGoalCompletionBonusIfGoalHadBonus(String goalId) async {
    final gIdx = _goals.indexWhere((g) => g.id == goalId);
    if (gIdx == -1) return;
    final meta = _goals[gIdx];
    if (!meta.completionBonusGranted) return;
    final bXp = meta.xpCompletionBonus;
    final bCoins = meta.coinsCompletionBonus;
    if (bXp <= 0 && bCoins <= 0) return;
    _userProfile.xp = (_userProfile.xp - bXp);
    _userProfile.coins = (_userProfile.coins - bCoins);
    if (_userProfile.xp < 0) _userProfile.xp = 0;
    if (_userProfile.coins < 0) _userProfile.coins = 0;
    _userProfile.level = _userProfile.calculateLevel(_userProfile.xp);
    final cleared = meta.copyWith(completionBonusGranted: false);
    _goals[gIdx] = cleared;
    notifyListeners();
    try {
      await _userService.updateGoal(cleared);
      await _persistUserProfile();
      await _userService.deleteInAppNotificationsWithGoalId(goalId);
    } catch (e, st) {
      debugPrint('revoke goal bonus: $e\n$st');
    }
  }

  Future<void> _grantGoalCompletionBonusIfAllDone(
    String goalId,
    TaskModel updatedTask,
  ) async {
    final tasksInGoal = getTasksForGoal(goalId);
    if (tasksInGoal.isEmpty) return;
    final allDone = tasksInGoal.every(
      (t) => t.id == updatedTask.id ? updatedTask.completed : t.completed,
    );
    if (!allDone) return;

    final gIdx = _goals.indexWhere((g) => g.id == goalId);
    if (gIdx == -1) return;
    final meta = _goals[gIdx];
    if (meta.completionBonusGranted) return;
    final bonusXp = meta.xpCompletionBonus;
    final bonusCoins = meta.coinsCompletionBonus;
    if (bonusXp <= 0 && bonusCoins <= 0) return;
    final title = meta.title;
    if (bonusXp > 0) _userProfile.addXp(bonusXp);
    if (bonusCoins > 0) _userProfile.addCoins(bonusCoins);
    _userProfile.incrementWeeklyActivity(xp: bonusXp, coins: bonusCoins);
    final newAchievements = _mergeNewAchievements();

    final marked = meta.copyWith(completionBonusGranted: true);
    _goals[gIdx] = marked;
    notifyListeners();

    try {
      await _userService.updateGoal(marked);
      await _persistAndAchievementNotifications(newAchievements);
      await _userService.addInAppNotification(
        type: InAppNotificationTypes.goalBonus,
        title: 'Цель достигнута!',
        body: '«$title»: бонус +$bonusXp XP и +$bonusCoins монет за выполнение всех задач.',
        goalId: goalId,
      );
    } catch (e, st) {
      debugPrint('grant goal bonus: $e\n$st');
    }
  }

  Future<void> addGoal(GoalModel goal) async {
    _goals.add(goal);
    notifyListeners();

    try {
      await _userService.addGoal(goal);
    } catch (e) {
      _goals.remove(goal);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateGoal(GoalModel updatedGoal) async {
    final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
    if (index == -1) return;

    final oldGoal = _goals[index];
    _goals[index] = updatedGoal;
    notifyListeners();

    try {
      await _userService.updateGoal(updatedGoal);
    } catch (e) {
      _goals[index] = oldGoal;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteGoal(String goalId) async {
    final goalIndex = _goals.indexWhere((g) => g.id == goalId);
    if (goalIndex == -1) return;

    final goal = _goals[goalIndex];
    final tasksForGoal =
        _tasks.where((t) => t.goalId == goalId).toList(growable: false);

    await _deleteCalendarEventIfAny(goal.calendarEventId);
    for (final t in tasksForGoal) {
      await _deleteCalendarEventIfAny(t.calendarEventId);
    }

    _goals.removeAt(goalIndex);
    _tasks.removeWhere((t) => t.goalId == goalId);
    notifyListeners();

    try {
      await _userService.deleteGoal(goalId);
    } catch (e) {
      _goals.insert(goalIndex, goal);
      _tasks.addAll(tasksForGoal);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _deleteCalendarEventIfAny(String? eventId) async {
    if (eventId == null || eventId.isEmpty) return;
    try {
      await GoogleCalendarService.instance.deleteStoredCalendarEventIds(eventId);
    } catch (_) {}
  }

  Future<void> addTask(TaskModel task, {bool rebalanceGoalRewards = true}) async {
    if (task.goalId != null && task.goalId!.isNotEmpty) {
      await _revokeGoalCompletionBonusIfGoalHadBonus(task.goalId!);
    }
    _tasks.add(task);
    notifyListeners();

    try {
      await _userService.addTask(task);
      if (task.goalId != null && task.goalId!.isNotEmpty) {
        _scheduleGoalTaskCalendarSync(task.id);
        if (rebalanceGoalRewards) {
          await recalculateGoalTaskRewards(task.goalId!);
        }
      }
    } catch (e) {
      _tasks.remove(task);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTask(TaskModel updatedTask) async {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index == -1) return;

    final oldTask = _tasks[index];
    final wasCompleted = oldTask.completed;
    final isNowCompleted = updatedTask.completed;

    var taskForStore = updatedTask;

    if (!wasCompleted && isNowCompleted) {
      final completionTime = DateTime.now();
      int gainedXp = 0;
      int gainedCoins = 0;

      final isGoalTask =
          updatedTask.goalId != null && updatedTask.goalId!.isNotEmpty;
      if (isGoalTask && updatedTask.reward != 0) {
        taskForStore = updatedTask.copyWith(reward: 0);
      }

      if (!isGoalTask && !taskForStore.isXp && taskForStore.reward > 0) {
        gainedCoins += taskForStore.reward.toInt();
        _userProfile.addCoins(taskForStore.reward.toInt());
      }
      if (!isGoalTask && taskForStore.isXp && taskForStore.reward > 0) {
        gainedXp += taskForStore.reward.toInt();
        _userProfile.addXp(taskForStore.reward.toInt());
      }
      _userProfile.incrementCompletedTasks();
      _userProfile.updateStreak();
      _userProfile.incrementWeeklyActivity(xp: gainedXp, coins: gainedCoins);
      _bumpCompletionStatsForAchievements(
        task: updatedTask,
        at: completionTime,
      );
      final newAchievements = _mergeNewAchievements();
      notifyListeners();
      unawaited(_persistAndAchievementNotifications(newAchievements));
      taskForStore = taskForStore.copyWith(
        completedAt: completionTime,
        dismissedFromHome: false,
      );
    } else if (wasCompleted && !isNowCompleted) {
      if (oldTask.goalId != null && oldTask.goalId!.isNotEmpty) {
        await _revokeGoalCompletionBonusIfGoalHadBonus(oldTask.goalId!);
      }
      final isGoalTask = oldTask.goalId != null && oldTask.goalId!.isNotEmpty;
      if (!isGoalTask && !oldTask.isXp && oldTask.reward > 0) {
        _userProfile.coins = (_userProfile.coins - oldTask.reward).toInt();
        if (_userProfile.coins < 0) _userProfile.coins = 0;
      }
      if (!isGoalTask && oldTask.isXp && oldTask.reward > 0) {
        _userProfile.xp = (_userProfile.xp - oldTask.reward).toInt();
        if (_userProfile.xp < 0) _userProfile.xp = 0;
      }
      if (oldTask.tag?.type == TagType.high &&
          _userProfile.highPriorityCompletions > 0) {
        _userProfile.highPriorityCompletions -= 1;
      }
      _userProfile.level = _userProfile.calculateLevel(_userProfile.xp);
      if (_userProfile.completedTasks > 0) _userProfile.completedTasks -= 1;
      final xpRev = (!isGoalTask && oldTask.isXp) ? oldTask.reward.toInt() : 0;
      final coinRev = (!isGoalTask && !oldTask.isXp) ? oldTask.reward.toInt() : 0;
      if (xpRev > 0 || coinRev > 0) {
        _userProfile.decrementWeeklyActivity(xp: xpRev, coins: coinRev);
      }
      final ca = oldTask.completedAt;
      if (ca != null &&
          ca.hour < 9 &&
          _userProfile.completionsBeforeNine > 0) {
        _userProfile.completionsBeforeNine -= 1;
      }
      notifyListeners();
      _persistUserProfile();
      taskForStore = updatedTask.copyWith(
        clearCompletedAt: true,
        dismissedFromHome: false,
      );
    }

    _tasks[index] = taskForStore;
    notifyListeners();

    try {
      await _userService.updateTask(taskForStore);
      if (taskForStore.goalId != null && taskForStore.goalId!.isNotEmpty) {
        _scheduleGoalTaskCalendarSync(taskForStore.id);
      }
    } catch (e) {
      _tasks[index] = oldTask;
      notifyListeners();
      rethrow;
    }

    // Бонус за цель — только после успешной записи задачи в Firestore, чтобы
    // локальный список задач и сервер не расходились с расчётом «все выполнены».
    if (!wasCompleted &&
        isNowCompleted &&
        taskForStore.goalId != null &&
        taskForStore.goalId!.isNotEmpty) {
      try {
        await _grantGoalCompletionBonusIfAllDone(
          taskForStore.goalId!,
          taskForStore,
        );
      } catch (e, st) {
        debugPrint('grant goal completion bonus: $e\n$st');
      }
    }
  }

  /// Не блокировать UI ожиданием Calendar API (часто висит на эмуляторе).
  void _scheduleGoalTaskCalendarSync(String taskId) {
    if (!GoogleCalendarService.instance.isSyncEnabled.value) return;
    Future.microtask(() async {
      try {
        await _syncGoalTaskCalendar(taskId)
            .timeout(const Duration(seconds: 25));
      } catch (e, st) {
        debugPrint('Goal task calendar sync: $e\n$st');
      }
    });
  }

  Future<void> _syncGoalTaskCalendar(String taskId) async {
    if (!GoogleCalendarService.instance.isSyncEnabled.value) return;

    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    final gid = task.goalId;
    if (gid == null || gid.isEmpty) return;

    final goalIndex = _goals.indexWhere((g) => g.id == gid);
    if (goalIndex == -1) return;

    final goal = _goals[goalIndex];
    final eventId =
        await GoogleCalendarService.instance.syncGoalTaskToCalendar(task, goal);

    if (eventId != null &&
        eventId.isNotEmpty &&
        eventId != task.calendarEventId) {
      await _mergeCalendarEventId(taskId, eventId);
    }
  }

  Future<void> _mergeCalendarEventId(String taskId, String eventId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.calendarEventId == eventId) return;

    final merged = task.copyWith(calendarEventId: eventId);
    _tasks[index] = merged;
    notifyListeners();

    try {
      await _userService.updateTask(merged);
    } catch (e) {
      _tasks[index] = task;
      notifyListeners();
      rethrow;
    }
  }

  /// Complete a task, award rewards, and remove it from active list.
  Future<void> completeAndRemoveTask(TaskModel task) async {
    // Guard: if already completed, just delete from list (idempotent-ish)
    if (!task.completed) {
      int gainedXp = 0;
      int gainedCoins = 0;
      if (task.isXp && task.reward > 0) {
        gainedXp += task.reward.toInt();
        _userProfile.addXp(task.reward.toInt());
      } else if (!task.isXp && task.reward > 0) {
        gainedCoins += task.reward.toInt();
        _userProfile.addCoins(task.reward.toInt());
      }
      _userProfile.incrementCompletedTasks();
      _userProfile.updateStreak();
      _userProfile.incrementWeeklyActivity(xp: gainedXp, coins: gainedCoins);
      final completionTime = DateTime.now();
      _bumpCompletionStatsForAchievements(task: task, at: completionTime);
      final newAchievements = _mergeNewAchievements();
      notifyListeners(); // update UI (coins/XP) immediately
      unawaited(_persistAndAchievementNotifications(newAchievements));
    }

    await deleteTask(task.id);
  }

  Future<void> deleteTask(String taskId) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex];
    final gid = task.goalId;
    if (gid != null && gid.isNotEmpty && task.completed) {
      return;
    }

    // Бонус за цель отзываем только если после удаления ещё есть невыполненные задачи.
    if (gid != null && gid.isNotEmpty) {
      final remaining =
          getTasksForGoal(gid).where((t) => t.id != taskId).toList();
      final shouldRevokeCompletionBonus = remaining.isNotEmpty &&
          !remaining.every((t) => t.completed);
      if (shouldRevokeCompletionBonus) {
        await _revokeGoalCompletionBonusIfGoalHadBonus(gid);
      }
    }

    await _deleteCalendarEventIfAny(task.calendarEventId);

    _tasks.removeAt(taskIndex);
    notifyListeners();

    try {
      await _userService.deleteTask(taskId);
      if (gid != null && gid.isNotEmpty) {
        await recalculateGoalTaskRewards(gid);
      }
    } catch (e) {
      _tasks.insert(taskIndex, task);
      notifyListeners();
      rethrow;
    }
  }

  /// Убрать выполненную задачу цели с главного экрана (документ в Firestore остаётся).
  Future<void> dismissGoalTaskFromHome(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = _tasks[index];
    final gid = task.goalId;
    if (gid == null || gid.isEmpty || !task.completed || task.dismissedFromHome) {
      return;
    }

    final updated = task.copyWith(dismissedFromHome: true);
    _tasks[index] = updated;
    notifyListeners();

    try {
      await _userService.updateTask(updated);
    } catch (e) {
      _tasks[index] = task;
      notifyListeners();
      rethrow;
    }
  }

  // Update UI when profile changes (for habit rewards, etc.)
  void refreshUI() {
    notifyListeners();
  }

  Future<void> completeHabitTask({
    int xpReward = 10,
    int coinReward = 0,
    DateTime? statsAt,
  }) async {
    final when = statsAt ?? DateTime.now();
    _userProfile.addXp(xpReward);
    if (coinReward > 0) {
      _userProfile.addCoins(coinReward);
    }
    _userProfile.incrementCompletedTasks();
    _userProfile.updateStreak();
    _userProfile.incrementWeeklyActivity(xp: xpReward, coins: coinReward);
    _bumpCompletionStatsForAchievements(task: null, at: when);
    final newAchievements = _mergeNewAchievements();
    await _persistAndAchievementNotifications(newAchievements);
    notifyListeners();
  }

  /// Снятие отметки с привычки после того, как награда уже начислена ([completeHabitTask] / подтверждение с SnackBar).
  Future<void> revertHabitCompletionRewards({
    required int xpReward,
    required int coinReward,
    DateTime? completionRecordedAt,
  }) async {
    if (xpReward > 0) {
      _userProfile.xp = (_userProfile.xp - xpReward);
      if (_userProfile.xp < 0) _userProfile.xp = 0;
    }
    if (coinReward > 0) {
      _userProfile.coins = (_userProfile.coins - coinReward);
      if (_userProfile.coins < 0) _userProfile.coins = 0;
    }
    _userProfile.level = _userProfile.calculateLevel(_userProfile.xp);
    if (_userProfile.completedTasks > 0) {
      _userProfile.completedTasks -= 1;
    }
    if (completionRecordedAt != null &&
        completionRecordedAt.hour < 9 &&
        _userProfile.completionsBeforeNine > 0) {
      _userProfile.completionsBeforeNine -= 1;
    }
    _userProfile.decrementWeeklyActivity(xp: xpReward, coins: coinReward);
    await _persistUserProfile();
    notifyListeners();
  }

  List<String> _parseStringIdList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _bumpCompletionStatsForAchievements({TaskModel? task, DateTime? at}) {
    final when = at ?? DateTime.now();
    if (when.hour < 9) {
      _userProfile.completionsBeforeNine += 1;
    }
    if (task != null && task.tag?.type == TagType.high) {
      _userProfile.highPriorityCompletions += 1;
    }
  }

  List<String> _mergeNewAchievements() {
    final newIds = newlyUnlockedAchievementIds(_userProfile);
    if (newIds.isEmpty) return [];
    final merged = <String>{
      ..._userProfile.unlockedAchievements,
      ...newIds,
    }.toList()
      ..sort();
    _userProfile.unlockedAchievements = merged;
    return newIds;
  }

  Future<void> _persistAndAchievementNotifications(
    List<String> newAchievementIds,
  ) async {
    try {
      await _persistUserProfile();
      if (newAchievementIds.isEmpty) return;
      await _recordAchievementNotifications(newAchievementIds);
    } catch (e, st) {
      debugPrint('persist/achievement notify: $e\n$st');
    }
  }

  Future<void> _recordAchievementNotifications(
    List<String> achievementIds,
  ) async {
    if (achievementIds.isEmpty) return;
    try {
      for (final id in achievementIds) {
        AchievementItem? item;
        for (final a in kAchievementCatalog) {
          if (a.id == id) {
            item = a;
            break;
          }
        }
        if (item == null) continue;
        final label = item.label.replaceAll('\n', ' ');
        await _userService.addInAppNotification(
          type: InAppNotificationTypes.achievement,
          title: 'Новое достижение',
          body: '«$label». ${item.description}',
          achievementId: id,
        );
      }
    } catch (e, st) {
      debugPrint('Achievement notification: $e\n$st');
    }
  }

  Future<void> markInAppNotificationRead(String notificationId) async {
    try {
      await _userService.markInAppNotificationRead(notificationId);
    } catch (e) {
      debugPrint('markInAppNotificationRead: $e');
    }
  }

  Future<void> markAllInAppNotificationsRead() async {
    try {
      await _userService.markAllInAppNotificationsRead();
    } catch (e) {
      debugPrint('markAllInAppNotificationsRead: $e');
    }
  }

  Future<void> _persistUserProfile() async {
    try {
      await _userService.updateUserProfile({
        'name': _userProfile.name,
        if (_userProfile.email != null && _userProfile.email!.isNotEmpty)
          'email': _userProfile.email,
        'bio': _userProfile.bio,
        'photoUrl': _nonEmptyStringOrNull(_userProfile.photoUrl),
        'level': _userProfile.level,
        'xp': _userProfile.xp,
        'coins': _userProfile.coins,
        'completedTasks': _userProfile.completedTasks,
        'streak': _userProfile.streak,
        'lastTaskCompletedDate': _userProfile.lastTaskCompletedDate?.toIso8601String(),
        'weeklyActivity': _userProfile.weeklyActivity,
        'weeklyXp': _userProfile.weeklyXp,
        'weeklyCoins': _userProfile.weeklyCoins,
        'weeklyChartWeekMonday': _userProfile.weeklyChartWeekMonday,
        'unlockedAchievements': _userProfile.unlockedAchievements,
        'shopHiddenBuiltinIds': _userProfile.shopHiddenBuiltinIds,
        'highPriorityCompletions': _userProfile.highPriorityCompletions,
        'completionsBeforeNine': _userProfile.completionsBeforeNine,
      });
    } catch (e) {
      debugPrint('Error persisting user profile: $e');
    }
  }

  /// Имя, «о себе» и фото (URL) — сохраняются в Firestore.
  Future<void> saveProfileDisplay({
    required String name,
    required String bio,
    String? photoUrl,
  }) async {
    final n = name.trim();
    if (n.isEmpty) {
      throw ArgumentError('Имя не может быть пустым');
    }
    var b = bio.trim();
    if (b.length > 280) b = b.substring(0, 280);
    final trimmedName = n.length > 80 ? n.substring(0, 80) : n;
    String? p = photoUrl?.trim();
    if (p != null && p.isEmpty) p = null;
    _userProfile.name = trimmedName;
    _userProfile.bio = b;
    _userProfile.photoUrl = p;
    notifyListeners();
    await _persistUserProfile();
  }

  static String? _nonEmptyStringOrNull(String? s) {
    final t = s?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  // Method to initialize with mock data for testing
  void initializeMockData() {
    _goals.clear();
    _tasks.clear();
    
    // Initialize user profile with zero values
    _userProfile = UserProfile(
      id: 'demo_user',
      name: 'Дамир',
      email: null,
      bio: '',
      photoUrl: null,
      level: 1,
      xp: 0,
      coins: 0,
      completedTasks: 0,
      streak: 0,
      shopHiddenBuiltinIds: const [],
      weeklyChartWeekMonday: UserProfile.mondayKeyFor(DateTime.now()),
    );
    
    // Create multiple goals for demo/testing
    _goals.addAll([
      GoalModel(
        id: 'g1',
        title: 'Спорт',
        subtitle: 'Марафон 2024',
        badge: 'до 12 дек',
        iconName: 'fitness',
        color: GoalColor.warning,
        progress: 0,
        tasksLeft: 3,
      ),
      GoalModel(
        id: 'g2',
        title: 'Учёба',
        subtitle: 'Английский B2',
        badge: 'до 20 авг',
        iconName: 'book',
        color: GoalColor.blue,
        progress: 0,
        tasksLeft: 2,
      ),
      GoalModel(
        id: 'g3',
        title: 'Карьера',
        subtitle: 'Senior Designer',
        badge: 'до 30 сен',
        iconName: 'work',
        color: GoalColor.success,
        progress: 0,
        tasksLeft: 1,
      ),
    ]);
    
    _tasks.addAll([
      // Tasks for goal 1 (Спорт)
      TaskModel(
        id: 't1',
        title: 'Пробежка 5км',
        subtitle: 'Утро • Спорт',
        goalId: 'g1',
        reward: 20,
        isXp: true,
        completed: false,
      ),
      TaskModel(
        id: 't2',
        title: 'Утренняя зарядка',
        subtitle: 'Утро • Спорт',
        goalId: 'g1',
        reward: 5,
        isXp: false,
        completed: false,
      ),
      TaskModel(
        id: 't3',
        title: 'Купить кроссовки',
        subtitle: 'Разово',
        goalId: 'g1',
        reward: 0,
        isXp: false,
        completed: false,
      ),
      // Tasks for goal 2 (Учёба)
      TaskModel(
        id: 't4',
        title: 'Урок английского',
        subtitle: '14:00 • Учёба',
        goalId: 'g2',
        reward: 50,
        isXp: true,
        completed: false,
      ),
      TaskModel(
        id: 't5',
        title: 'Написать эссе',
        subtitle: '1 час • Учёба',
        goalId: 'g2',
        reward: 30,
        isXp: true,
        completed: false,
      ),
      // Tasks for goal 3 (Карьера)
      TaskModel(
        id: 't6',
        title: 'Завершить дизайн проекта',
        subtitle: 'Срочно',
        goalId: 'g3',
        reward: 100,
        isXp: true,
        completed: false,
      ),
    ]);
    
    notifyListeners();
  }

  // Initialize with empty profile for new users
  void initializeEmptyProfile() {
    _goals.clear();
    _tasks.clear();
    
    // Initialize user profile with zero values
    _userProfile = UserProfile(
      id: 'demo_user',
      name: 'Пользователь',
      email: null,
      bio: '',
      photoUrl: null,
      level: 1,
      xp: 0,
      coins: 0,
      completedTasks: 0,
      streak: 0,
      shopHiddenBuiltinIds: const [],
      weeklyChartWeekMonday: UserProfile.mondayKeyFor(DateTime.now()),
    );
    _hasProfile = true;
    
    notifyListeners();
  }
}