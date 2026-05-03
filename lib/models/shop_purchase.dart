import 'package:cloud_firestore/cloud_firestore.dart';

class ShopPurchase {
  final String id;
  final String rewardId;
  final String title;
  final int price;
  final bool isBuiltin;
  final DateTime? purchasedAt;

  ShopPurchase({
    required this.id,
    required this.rewardId,
    required this.title,
    required this.price,
    required this.isBuiltin,
    required this.purchasedAt,
  });

  factory ShopPurchase.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final ts = data['purchasedAt'];
    DateTime? at;
    if (ts is Timestamp) {
      at = ts.toDate();
    }
    return ShopPurchase(
      id: doc.id,
      rewardId: (data['rewardId'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      isBuiltin: data['isBuiltin'] == true,
      purchasedAt: at,
    );
  }
}
