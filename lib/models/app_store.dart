import 'dart:async';

import 'package:flutter/foundation.dart';
import '../achievements/achievement_catalog.dart';
import '../models/goal_model.dart';
import '../models/task_model.dart';
import '../models/user_profile.dart';
import '../services/google_calendar_service.dart';
import '../services/user_service.dart';

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
    level: 1,
    xp: 0,
    coins: 0,
    completedTasks: 0,
    streak: 0,
  );

  List<GoalModel> get goals => List.unmodifiable(_goals);
  List<TaskModel> get tasks => List.unmodifiable(_tasks);
  UserProfile get userProfile => _userProfile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasProfile = false;
  bool get hasProfile => _hasProfile;

  StreamSubscription<dynamic>? _userProfileSub;
  StreamSubscription<dynamic>? _goalsSub;
  StreamSubscription<dynamic>? _tasksSub;

  /// Сброс кэша и отписка от Firestore при выходе или перед сменой аккаунта.
  Future<void> resetSession() async {
    await _userProfileSub?.cancel();
    await _goalsSub?.cancel();
    await _tasksSub?.cancel();
    _userProfileSub = null;
    _goalsSub = null;
    _tasksSub = null;

    _goals.clear();
    _tasks.clear();
    _hasProfile = false;
    _userProfile = UserProfile(
      id: '',
      name: 'Пользователь',
      email: null,
      level: 1,
      xp: 0,
      coins: 0,
      completedTasks: 0,
      streak: 0,
    );
    notifyListeners();
  }

  Future<void> loadUserData() async {
    await _userProfileSub?.cancel();
    await _goalsSub?.cancel();
    await _tasksSub?.cancel();
    _userProfileSub = null;
    _goalsSub = null;
    _tasksSub = null;

    _goals.clear();
    _tasks.clear();

    _isLoading = true;
    notifyListeners();

    try {
      // User profile (XP/level/coins/streak)
      _userProfileSub = _userService.getUserProfile().listen((data) {
        if (data == null) {
          // If user doc doesn't exist yet, keep existing profile or init empty
          if (!_hasProfile) {
            initializeEmptyProfile();
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
          name: (data['name'] as String?) ?? 'Пользователь',
          email: data['email'] as String?,
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
          unlockedAchievements: _parseStringIdList(data['unlockedAchievements']),
          highPriorityCompletions:
              (data['highPriorityCompletions'] as num?)?.toInt() ?? 0,
          completionsBeforeNine:
              (data['completionsBeforeNine'] as num?)?.toInt() ?? 0,
        );
        _hasProfile = true;
        if (_mergeNewAchievements()) {
          unawaited(_persistUserProfile());
        }
        notifyListeners();
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
    if (goalTasks.isEmpty) return 0;
    final completedTasks = goalTasks.where((t) => t.completed).length;
    return ((completedTasks / goalTasks.length) * 100).round();
  }

  int tasksLeft(String goalId) {
    final goalTasks = getTasksForGoal(goalId);
    return goalTasks.where((t) => !t.completed).length;
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
      await GoogleCalendarService.instance.deleteEvent(eventId);
    } catch (_) {}
  }

  Future<void> addTask(TaskModel task) async {
    _tasks.add(task);
    notifyListeners();

    try {
      await _userService.addTask(task);
      if (task.goalId != null && task.goalId!.isNotEmpty) {
        _scheduleGoalTaskCalendarSync(task.id);
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

    // Handle rewards when task is marked as completed
    if (!wasCompleted && isNowCompleted) {
      int gainedXp = 0;
      int gainedCoins = 0;

      // Coins reward
      if (!updatedTask.isXp && updatedTask.reward > 0) {
        gainedCoins += updatedTask.reward.toInt();
        _userProfile.addCoins(updatedTask.reward.toInt());
      }
      if (updatedTask.isXp && updatedTask.reward > 0) {
        gainedXp += updatedTask.reward.toInt();
        _userProfile.addXp(updatedTask.reward.toInt());
      }
      _userProfile.incrementCompletedTasks();
      _userProfile.updateStreak();
      _userProfile.incrementWeeklyActivity(xp: gainedXp, coins: gainedCoins);
      _bumpCompletionStatsForAchievements(task: updatedTask);
      _mergeNewAchievements();
      notifyListeners();
      _persistUserProfile();
    } else if (wasCompleted && !isNowCompleted) {
      // Remove rewards
      if (!updatedTask.isXp && updatedTask.reward > 0) {
        _userProfile.coins = (_userProfile.coins - updatedTask.reward).toInt();
        if (_userProfile.coins < 0) _userProfile.coins = 0;
      }
      if (updatedTask.isXp && updatedTask.reward > 0) {
        _userProfile.xp = (_userProfile.xp - updatedTask.reward).toInt();
        if (_userProfile.xp < 0) _userProfile.xp = 0;
      }
      if (oldTask.tag?.type == TagType.high &&
          _userProfile.highPriorityCompletions > 0) {
        _userProfile.highPriorityCompletions -= 1;
      }
      _userProfile.level = _userProfile.calculateLevel(_userProfile.xp);
      if (_userProfile.completedTasks > 0) _userProfile.completedTasks -= 1;
      notifyListeners();
      _persistUserProfile();
    }

    _tasks[index] = updatedTask;
    notifyListeners();

    try {
      await _userService.updateTask(updatedTask);
      if (updatedTask.goalId != null && updatedTask.goalId!.isNotEmpty) {
        _scheduleGoalTaskCalendarSync(updatedTask.id);
      }
    } catch (e) {
      _tasks[index] = oldTask;
      notifyListeners();
      rethrow;
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
      _bumpCompletionStatsForAchievements(task: task);
      _mergeNewAchievements();
      notifyListeners(); // update UI (coins/XP) immediately
      _persistUserProfile();
    }

    await deleteTask(task.id);
  }

  Future<void> deleteTask(String taskId) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex];

    await _deleteCalendarEventIfAny(task.calendarEventId);

    _tasks.removeAt(taskIndex);
    notifyListeners();

    try {
      await _userService.deleteTask(taskId);
    } catch (e) {
      _tasks.insert(taskIndex, task);
      notifyListeners();
      rethrow;
    }
  }

  // Update UI when profile changes (for habit rewards, etc.)
  void refreshUI() {
    notifyListeners();
  }

  Future<void> completeHabitTask({int xpReward = 10, int coinReward = 0}) async {
    _userProfile.addXp(xpReward);
    if (coinReward > 0) {
      _userProfile.addCoins(coinReward);
    }
    _userProfile.incrementCompletedTasks();
    _userProfile.updateStreak();
    _userProfile.incrementWeeklyActivity(xp: xpReward, coins: coinReward);
    _bumpCompletionStatsForAchievements(task: null);
    _mergeNewAchievements();
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

  void _bumpCompletionStatsForAchievements({TaskModel? task}) {
    final now = DateTime.now();
    if (now.hour < 9) {
      _userProfile.completionsBeforeNine += 1;
    }
    if (task != null && task.tag?.type == TagType.high) {
      _userProfile.highPriorityCompletions += 1;
    }
  }

  bool _mergeNewAchievements() {
    final newIds = newlyUnlockedAchievementIds(_userProfile);
    if (newIds.isEmpty) return false;
    final merged = <String>{
      ..._userProfile.unlockedAchievements,
      ...newIds,
    }.toList()
      ..sort();
    _userProfile.unlockedAchievements = merged;
    return true;
  }

  Future<void> _persistUserProfile() async {
    try {
      await _userService.updateUserProfile({
        'name': _userProfile.name,
        if (_userProfile.email != null && _userProfile.email!.isNotEmpty)
          'email': _userProfile.email,
        'level': _userProfile.level,
        'xp': _userProfile.xp,
        'coins': _userProfile.coins,
        'completedTasks': _userProfile.completedTasks,
        'streak': _userProfile.streak,
        'lastTaskCompletedDate': _userProfile.lastTaskCompletedDate?.toIso8601String(),
        'weeklyActivity': _userProfile.weeklyActivity,
        'weeklyXp': _userProfile.weeklyXp,
        'weeklyCoins': _userProfile.weeklyCoins,
        'unlockedAchievements': _userProfile.unlockedAchievements,
        'highPriorityCompletions': _userProfile.highPriorityCompletions,
        'completionsBeforeNine': _userProfile.completionsBeforeNine,
      });
    } catch (e) {
      debugPrint('Error persisting user profile: $e');
    }
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
      level: 1,
      xp: 0,
      coins: 0,
      completedTasks: 0,
      streak: 0,
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
      level: 1,
      xp: 0,
      coins: 0,
      completedTasks: 0,
      streak: 0,
    );
    _hasProfile = true;
    
    notifyListeners();
  }
}