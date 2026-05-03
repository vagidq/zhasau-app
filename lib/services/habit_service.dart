import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/habit_model.dart';

/// Привычки и быстрые задачи хранятся под `users/{uid}/habits`, чтобы не смешивать аккаунты.
/// Раньше использовалась корневая коллекция `habits` — все пользователи видели одни данные.
class HabitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? _habitsRefOrNull() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('habits');
  }

  CollectionReference<Map<String, dynamic>> _habitsRefRequire() {
    final ref = _habitsRefOrNull();
    if (ref == null) {
      throw StateError('User not authenticated');
    }
    return ref;
  }

  /// Returns [habit] with [HabitModel.id] set to the new Firestore document id.
  Future<HabitModel> addHabit(HabitModel habit) async {
    final doc = await _habitsRefRequire().add(habit.toMap());
    return habit.copyWith(id: doc.id);
  }

  Stream<List<HabitModel>> getHabits() {
    final ref = _habitsRefOrNull();
    if (ref == null) {
      return Stream<List<HabitModel>>.value(const <HabitModel>[]);
    }
    return ref
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(HabitModel.fromFirestore).toList();
    });
  }

  /// One-shot read (e.g. bulk calendar sync without subscribing to the stream).
  Future<List<HabitModel>> getAllHabitsOnce() async {
    final ref = _habitsRefOrNull();
    if (ref == null) return const <HabitModel>[];
    final snapshot =
        await ref.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map(HabitModel.fromFirestore).toList();
  }

  Future<void> updateHabit(HabitModel habit) async {
    if (habit.id == null || habit.id!.isEmpty) return;
    await _habitsRefRequire().doc(habit.id).update(habit.toMap());
  }

  Future<void> deleteHabit(String id) async {
    await _habitsRefRequire().doc(id).delete();
  }
}
