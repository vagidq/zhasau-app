import 'package:cloud_firestore/cloud_firestore.dart';

class HabitModel {
  final String? id;
  final String title;
  final bool completed;
  final DateTime createdAt;

  const HabitModel({
    this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
  });

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

    return HabitModel(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      completed: data['completed'] == true,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'completed': completed,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  HabitModel copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? createdAt,
  }) {
    return HabitModel(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
