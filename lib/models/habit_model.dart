import 'package:cloud_firestore/cloud_firestore.dart';

class HabitModel {
  final String? id;
  final String title;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isQuickTask;
  final int xpReward;
  /// Coins granted when the habit is completed (see [AppStore.completeHabitTask]).
  final int coinReward;
  final DateTime? deadline;
  final String? calendarEventId;
  /// Заметка к задаче (экран создания «Описание»).
  final String notes;

  const HabitModel({
    this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
    this.completedAt,
    this.isQuickTask = false,
    this.xpReward = 10,
    this.coinReward = 0,
    this.deadline,
    this.calendarEventId,
    this.notes = '',
  });

  /// True if this is a quick task whose deadline has passed without completion.
  bool get isExpired =>
      !completed &&
      deadline != null &&
      DateTime.now().isAfter(deadline!);

  factory HabitModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtRaw = data['createdAt'];

    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else {
      createdAt = DateTime.now();
    }

    final completedAtRaw = data['completedAt'];
    DateTime? completedAt;
    if (completedAtRaw is Timestamp) {
      completedAt = completedAtRaw.toDate();
    }

    final deadlineRaw = data['deadline'];
    DateTime? deadline;
    if (deadlineRaw is Timestamp) {
      deadline = deadlineRaw.toDate();
    }

    return HabitModel(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      completed: data['completed'] == true,
      createdAt: createdAt,
      completedAt: completedAt,
      isQuickTask: data['isQuickTask'] == true,
      xpReward: (data['xpReward'] as num?)?.toInt() ?? 10,
      coinReward: (data['coinReward'] as num?)?.toInt() ?? 0,
      deadline: deadline,
      calendarEventId: data['calendarEventId'] as String?,
      notes: (data['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'completed': completed,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'isQuickTask': isQuickTask,
      'xpReward': xpReward,
      'coinReward': coinReward,
      if (deadline != null) 'deadline': Timestamp.fromDate(deadline!),
      if (calendarEventId != null) 'calendarEventId': calendarEventId,
      if (notes.isNotEmpty) 'notes': notes,
    };
  }

  HabitModel copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? isQuickTask,
    int? xpReward,
    int? coinReward,
    DateTime? deadline,
    String? calendarEventId,
    String? notes,
  }) {
    return HabitModel(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      isQuickTask: isQuickTask ?? this.isQuickTask,
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
      deadline: deadline ?? this.deadline,
      calendarEventId: calendarEventId ?? this.calendarEventId,
      notes: notes ?? this.notes,
    );
  }
}
