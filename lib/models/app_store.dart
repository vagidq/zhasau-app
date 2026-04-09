import 'package:flutter/foundation.dart';
import '../models/goal_model.dart';
import '../models/task_model.dart';
import '../models/user_profile.dart';
import '../services/user_service.dart';

class AppStore extends ChangeNotifier {
  static final AppStore instance = AppStore._internal();

  AppStore._internal();

  final UserService _userService = UserService();

  final List<GoalModel> _goals = [];
  final List<TaskModel> _tasks = [];
  late UserProfile _userProfile;

  List<GoalModel> get goals => List.unmodifiable(_goals);
  List<TaskModel> get tasks => List.unmodifiable(_tasks);
  UserProfile get userProfile => _userProfile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasProfile = false;
  bool get hasProfile => _hasProfile;

  Future<void> loadUserData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // User profile (XP/level/coins/streak)
      _userService.getUserProfile().listen((data) {
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

        _userProfile = UserProfile(
          id: _userService.userId,
          name: (data['name'] as String?) ?? 'Пользователь',
          level: (data['level'] as num?)?.toInt() ?? 1,
          xp: (data['xp'] as num?)?.toInt() ?? 0,
          coins: (data['coins'] as num?)?.toInt() ?? 0,
          completedTasks: (data['completedTasks'] as num?)?.toInt() ?? 0,
          streak: (data['streak'] as num?)?.toInt() ?? 0,
          lastTaskCompletedDate: data['lastTaskCompletedDate'] != null
              ? DateTime.tryParse(data['lastTaskCompletedDate'] as String)
              : null,
          weeklyActivity: weeklyActivity,
        );
        _hasProfile = true;
        notifyListeners();
      });

      // Listen to changes
      _userService.getGoals().listen((goals) {
        _goals.clear();
        _goals.addAll(goals);
        notifyListeners();
      });

      _userService.getTasks().listen((tasks) {
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
    _goals.removeAt(goalIndex);
    _tasks.removeWhere((t) => t.goalId == goalId);
    notifyListeners();

    try {
      await _userService.deleteGoal(goalId);
    } catch (e) {
      _goals.insert(goalIndex, goal);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addTask(TaskModel task) async {
    _tasks.add(task);
    notifyListeners();

    try {
      await _userService.addTask(task);
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
      // Task just completed - give rewards
      if (updatedTask.isXp && updatedTask.reward > 0) {
        _userProfile.addXp(updatedTask.reward.toInt());
      } else if (!updatedTask.isXp && updatedTask.reward > 0) {
        _userProfile.addCoins(updatedTask.reward.toInt());
      }
      _userProfile.updateStreak();
      _persistUserProfile();
    } else if (wasCompleted && !isNowCompleted) {
      // Task just uncompleted - remove rewards
      if (updatedTask.isXp && updatedTask.reward > 0) {
        _userProfile.xp = (_userProfile.xp - updatedTask.reward).toInt();
        if (_userProfile.xp < 0) _userProfile.xp = 0;
        _userProfile.level = _userProfile.calculateLevel(_userProfile.xp);
      } else if (!updatedTask.isXp && updatedTask.reward > 0) {
        _userProfile.coins = (_userProfile.coins - updatedTask.reward).toInt();
        if (_userProfile.coins < 0) _userProfile.coins = 0;
      }
      _persistUserProfile();
    }

    _tasks[index] = updatedTask;
    notifyListeners();

    try {
      await _userService.updateTask(updatedTask);
    } catch (e) {
      _tasks[index] = oldTask;
      notifyListeners();
      rethrow;
    }
  }

  /// Complete a task, award rewards, and remove it from active list.
  Future<void> completeAndRemoveTask(TaskModel task) async {
    // Guard: if already completed, just delete from list (idempotent-ish)
    if (!task.completed) {
      if (task.isXp && task.reward > 0) {
        _userProfile.addXp(task.reward.toInt());
      } else if (!task.isXp && task.reward > 0) {
        _userProfile.addCoins(task.reward.toInt());
      }
      _userProfile.incrementCompletedTasks();
      _userProfile.updateStreak();
      _persistUserProfile();
    }

    await deleteTask(task.id);
  }

  Future<void> deleteTask(String taskId) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex];
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
    print('DEBUG: refreshUI called, notifying listeners');
    notifyListeners();
  }

  Future<void> completeHabitTask({int xpReward = 10}) async {
    _userProfile.addXp(xpReward);
    _userProfile.incrementCompletedTasks();
    _userProfile.updateStreak();
    _userProfile.incrementWeeklyActivity();
    await _persistUserProfile();
    notifyListeners();
  }

  Future<void> _persistUserProfile() async {
    try {
      await _userService.updateUserProfile({
        'name': _userProfile.name,
        'level': _userProfile.level,
        'xp': _userProfile.xp,
        'coins': _userProfile.coins,
        'completedTasks': _userProfile.completedTasks,
        'streak': _userProfile.streak,
        'lastTaskCompletedDate': _userProfile.lastTaskCompletedDate?.toIso8601String(),
        'weeklyActivity': _userProfile.weeklyActivity,
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
      name: 'Дамир',
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