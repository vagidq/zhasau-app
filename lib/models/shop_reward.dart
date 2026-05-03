/// Награда в магазине (встроенная или пользовательская из Firestore).
class ShopReward {
  final String id;
  final String title;
  final String description;
  final int price;
  /// URL картинки; для своих наград может быть пустым.
  final String? imageUrl;
  final bool isBuiltin;

  const ShopReward({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.imageUrl,
    this.isBuiltin = false,
  });

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  factory ShopReward.fromFirestore(String docId, Map<String, dynamic> data) {
    final desc = (data['description'] as String?) ??
        (data['desc'] as String?) ??
        '';
    return ShopReward(
      id: docId,
      title: (data['title'] as String?) ?? '',
      description: desc,
      price: (data['price'] as num?)?.toInt() ?? 0,
      imageUrl: data['imageUrl'] as String?,
      isBuiltin: false,
    );
  }
}
