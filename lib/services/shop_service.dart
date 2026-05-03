import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/shop_purchase.dart';
import '../models/shop_reward.dart';

class ShopInsufficientCoinsException implements Exception {
  @override
  String toString() => 'Недостаточно монет';
}

class ShopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _uidOrNull => FirebaseAuth.instance.currentUser?.uid;

  String _requireUid() {
    final uid = _uidOrNull;
    if (uid == null || uid.isEmpty) {
      throw StateError('Пользователь не авторизован');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _rewardsCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('shopRewards');

  CollectionReference<Map<String, dynamic>> _purchasesCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('shopPurchases');

  Stream<List<ShopReward>> watchCustomRewards() {
    final uid = _uidOrNull;
    if (uid == null) {
      return Stream<List<ShopReward>>.value(const []);
    }
    return _rewardsCol(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ShopReward.fromFirestore(d.id, d.data()))
            .toList(growable: false));
  }

  Stream<List<ShopPurchase>> watchPurchases({int limit = 80}) {
    final uid = _uidOrNull;
    if (uid == null) {
      return Stream<List<ShopPurchase>>.value(const []);
    }
    return _purchasesCol(uid)
        .orderBy('purchasedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ShopPurchase.fromDoc).toList());
  }

  /// Атомарно списывает монеты и пишет историю покупки.
  Future<void> purchaseReward({
    required String rewardId,
    required String title,
    required int price,
    required bool isBuiltin,
  }) async {
    if (price < 0) {
      throw ArgumentError.value(price, 'price');
    }
    final uid = _requireUid();
    final userRef = _firestore.collection('users').doc(uid);
    final purchaseRef = _purchasesCol(uid).doc();

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      if (!snap.exists) {
        throw StateError('Профиль не найден');
      }
      final coins = (snap.data()?['coins'] as num?)?.toInt() ?? 0;
      if (coins < price) {
        throw ShopInsufficientCoinsException();
      }
      transaction.update(userRef, {'coins': coins - price});
      transaction.set(purchaseRef, {
        'rewardId': rewardId,
        'title': title,
        'price': price,
        'isBuiltin': isBuiltin,
        'purchasedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> hideBuiltinReward(String builtinId) async {
    final uid = _requireUid();
    await _firestore.collection('users').doc(uid).set({
      'shopHiddenBuiltinIds': FieldValue.arrayUnion([builtinId]),
    }, SetOptions(merge: true));
  }

  Future<void> addCustomReward({
    required String title,
    required String description,
    required int price,
    String? imageUrl,
  }) async {
    final t = title.trim();
    if (t.isEmpty) {
      throw ArgumentError('Укажите название');
    }
    if (price < 1) {
      throw ArgumentError('Цена от 1 монеты');
    }
    final uid = _requireUid();
    await _rewardsCol(uid).add({
      'title': t,
      'description': description.trim(),
      'price': price,
      if (imageUrl != null && imageUrl.trim().isNotEmpty)
        'imageUrl': imageUrl.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCustomReward(String docId) async {
    final uid = _requireUid();
    await _rewardsCol(uid).doc(docId).delete();
  }
}
