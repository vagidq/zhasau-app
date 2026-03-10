import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/habit_model.dart';

class HabitService {
  final CollectionReference<Map<String, dynamic>> _habitsRef =
      FirebaseFirestore.instance.collection('habits');

  Future<void> addHabit(HabitModel habit) async {
    await _habitsRef.add(habit.toMap());
  }

  Stream<List<HabitModel>> getHabits() {
    return _habitsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(HabitModel.fromFirestore).toList();
    });
  }

  Future<void> updateHabit(HabitModel habit) async {
    if (habit.id == null || habit.id!.isEmpty) return;
    await _habitsRef.doc(habit.id).update(habit.toMap());
  }

  Future<void> deleteHabit(String id) async {
    await _habitsRef.doc(id).delete();
  }
}
