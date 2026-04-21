import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/goal_model.dart';
import '../models/task_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get userId {
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
        switch (data['color'] as String?) {
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
      'priority': task.priority,
      'xpReward': task.xpReward,
      'completed': task.completed,
    });
  }

  Future<void> updateTask(TaskModel task) async {
    await _tasksCollection.doc(task.id).update({
      'title': task.title,
      'subtitle': task.subtitle,
      'reward': task.reward,
      'xpReward': task.xpReward,
      'isXp': task.isXp,
      'tagText': task.tag?.text,
      'tagType': task.tag?.type.toString().split('.').last,
      'priority': task.priority,
      'completed': task.completed,
    });
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
          final typeStr = (data['tagType'] as String).replaceFirst('TagType.', '');
          switch (typeStr) {
            case 'high':
              tagType = TagType.high;
              break;
            case 'medium':
              tagType = TagType.medium;
              break;
            case 'low':
              tagType = TagType.low;
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

        return TaskModel(
          id: data['id'] ?? doc.id,
          title: data['title'] ?? '',
          subtitle: data['subtitle'] ?? '',
          goalId: data['goalId'],
          reward: (data['reward'] as num?) ?? 0,
          xpReward: (data['xpReward'] as num?)?.toInt() ?? 0,
          isXp: data['isXp'] ?? true,
          tag: tag,
          priority: (data['priority'] as num?)?.toInt() ?? 1,
          completed: data['completed'] ?? false,
        );
      }).toList();
    });
  }

  // User profile
  Future<void> initializeUserProfile(String name) async {
    await _firestore.collection('users').doc(userId).set({
      'name': name,
      'level': 1,
      'xp': 0,
      'xpMax': 1000,
      'coins': 0,
      'completedTasks': 0,
      'streak': 0,
      'lastTaskCompletedDate': null,
    });
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
}