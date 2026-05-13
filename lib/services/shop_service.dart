import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/shop_purchase.dart';
import '../models/shop_reward.dart';
import 'current_user_doc.dart';

class ShopInsufficientCoinsException implements Exception {
  @override
  String toString() => 'Недостаточно монет';
}

class ShopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Auth uid, если есть.
  String? get _uidOrNull => FirebaseAuth.instance.currentUser?.uid;

  String _requireUid() {
    final uid = _uidOrNull;
    if (uid == null || uid.isEmpty) {
      throw StateError('Пользователь не авторизован');
    }
    return uid;
  }

  /// ID документа пользователя в Firestore (читаемый, после миграции).
  String? get _docIdOrNull {
    final uid = _uidOrNull;
    if (uid == null || uid.isEmpty) return null;
    return CurrentUserDoc.cachedDocId() ?? uid;
  }

  String _requireDocId() {
    final id = _docIdOrNull;
    if (id == null) throw StateError('Пользователь не авторизован');
    return id;
  }

  CollectionReference<Map<String, dynamic>> _rewardsCol(String docId) =>
      _firestore.collection('users').doc(docId).collection('shopRewards');

  CollectionReference<Map<String, dynamic>> _purchasesCol(String docId) =>
      _firestore.collection('users').doc(docId).collection('shopPurchases');

  Stream<List<ShopReward>> watchCustomRewards() {
    final docId = _docIdOrNull;
    if (docId == null) {
      return Stream<List<ShopReward>>.value(const []);
    }
    return _rewardsCol(docId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ShopReward.fromFirestore(d.id, d.data()))
            .toList(growable: false));
  }

  Stream<List<ShopPurchase>> watchPurchases({int limit = 80}) {
    final docId = _docIdOrNull;
    if (docId == null) {
      return Stream<List<ShopPurchase>>.value(const []);
    }
    return _purchasesCol(docId)
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
    _requireUid();
    final docId = _requireDocId();
    final userRef = _firestore.collection('users').doc(docId);
    final purchaseRef = _purchasesCol(docId).doc();

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
    _requireUid();
    final docId = _requireDocId();
    await _firestore.collection('users').doc(docId).set({
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
    _requireUid();
    final userDocId = _requireDocId();
    await _rewardsCol(userDocId).add({
      'title': t,
      'description': description.trim(),
      'price': price,
      if (imageUrl != null && imageUrl.trim().isNotEmpty)
        'imageUrl': imageUrl.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCustomReward(String docId) async {
    _requireUid();
    final userDocId = _requireDocId();
    await _rewardsCol(userDocId).doc(docId).delete();
  }
}
