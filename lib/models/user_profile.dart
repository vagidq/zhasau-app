import 'package:flutter/foundation.dart';

class UserProfile {
  final String id;
  String name;
  /// Почта из Firestore / регистрации (не путать с Google Calendar).
  String? email;
  int level;
  int xp;
  final int xpPerLevel = 1000; // XP needed to level up
  int coins;
  int completedTasks;
  int streak; // Days in a row of completing tasks
  DateTime? lastTaskCompletedDate;
  // Tasks completed per weekday: index 0=Mon, 1=Tue, ..., 6=Sun
  List<int> weeklyActivity;

  UserProfile({
    required this.id,
    required this.name,
    this.email,
    this.level = 1,
    this.xp = 0,
    this.coins = 0,
    this.completedTasks = 0,
    this.streak = 0,
    this.lastTaskCompletedDate,
    List<int>? weeklyActivity,
  }) : weeklyActivity = weeklyActivity ?? List.filled(7, 0);

  // Calculate current level based on XP
  int calculateLevel(int totalXp) {
    return (totalXp ~/ xpPerLevel) + 1;
  }

  // Get XP progress to next level (0-100%)
  int getXpProgressPercent() {
    final xpInCurrentLevel = xp % xpPerLevel;
    return ((xpInCurrentLevel / xpPerLevel) * 100).toInt();
  }

  // Add XP and auto-level up
  void addXp(int amount) {
    debugPrint('DEBUG: addXp called with amount=$amount, xp before=$xp');
    xp += amount;
    level = calculateLevel(xp);
    debugPrint('DEBUG: addXp done, xp after=$xp, level=$level');
  }

  // Add coins
  void addCoins(int amount) {
    coins += amount;
  }

  // Update streak when task is completed
  void updateStreak() {
    final today = DateTime.now();
    final isToday = lastTaskCompletedDate != null &&
        lastTaskCompletedDate!.year == today.year &&
        lastTaskCompletedDate!.month == today.month &&
        lastTaskCompletedDate!.day == today.day;

    if (!isToday) {
      final isYesterday = lastTaskCompletedDate != null &&
          lastTaskCompletedDate!.year == today.year &&
          lastTaskCompletedDate!.month == today.month &&
          lastTaskCompletedDate!.day == today.day - 1;

      if (isYesterday) {
        streak += 1;
      } else {
        streak = 1;
      }
    }

    lastTaskCompletedDate = today;
  }

  void incrementCompletedTasks() {
    completedTasks += 1;
  }

  // Increment today's weekday slot (Mon=0 .. Sun=6)
  void incrementWeeklyActivity() {
    final todayIndex = DateTime.now().weekday - 1;
    weeklyActivity[todayIndex] += 1;
  }

  // Get XP needed for next level
  int getXpForNextLevel() {
    return xpPerLevel - (xp % xpPerLevel);
  }

  // Create copy with updates
  UserProfile copyWith({
    String? name,
    String? email,
    int? level,
    int? xp,
    int? coins,
    int? completedTasks,
    int? streak,
    DateTime? lastTaskCompletedDate,
    List<int>? weeklyActivity,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      completedTasks: completedTasks ?? this.completedTasks,
      streak: streak ?? this.streak,
      lastTaskCompletedDate: lastTaskCompletedDate ?? this.lastTaskCompletedDate,
      weeklyActivity: weeklyActivity ?? List.of(this.weeklyActivity),
    );
  }
}
