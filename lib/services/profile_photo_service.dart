import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Загрузка фото профиля в Firebase Storage (`users/{uid}/profile_*.jpg`).
class ProfilePhotoService {
  ProfilePhotoService._();
  static final ProfilePhotoService instance = ProfilePhotoService._();

  /// Явно привязываемся к бакету из [Firebase.initializeApp], иначе на части
  /// конфигов эмулятор/клиент цепляется не к тому endpoint и падает resumable upload.
  FirebaseStorage get _storage {
    final app = Firebase.app();
    final bucket = app.options.storageBucket;
    if (bucket != null && bucket.isNotEmpty) {
      return FirebaseStorage.instanceFor(app: app, bucket: bucket);
    }
    return FirebaseStorage.instanceFor(app: app);
  }

  static String _contentTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<String> _putAndGetUrl({
    required Reference ref,
    required Uint8List bytes,
    required String fileLabel,
  }) async {
    final metadata = SettableMetadata(
      contentType: _contentTypeForName(fileLabel),
    );
    try {
      final snapshot = await ref.putData(
        bytes,
        metadata,
      );
      final url = await snapshot.ref.getDownloadURL();
      if (url.isEmpty) {
        throw StateError('Пустой URL после загрузки');
      }
      return url;
    } on FirebaseException catch (e, st) {
      debugPrint(
        'Storage [${ref.fullPath}]: code=${e.code} message=${e.message}\n$st',
      );
      final code = e.code;
      if (code == 'object-not-found' ||
          code == 'unauthorized' ||
          code == 'storage/unauthorized' ||
          code == 'permission-denied') {
        throw StateError(
          'Firebase Storage недоступен или закрыт правилами. '
          'В консоли Firebase: Build → Storage — нажми «Начать», выбери регион. '
          'Затем Rules — разреши доступ к users/{uid}/ (см. storage.rules в проекте) '
          'и опубликуй правила. Без этого загрузка фото не работает.',
        );
      }
      rethrow;
    }
  }

  Future<String> uploadProfileImage(XFile file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Войдите в аккаунт, чтобы загрузить фото');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw ArgumentError('Пустой файл');
    }
    if (bytes.length > 8 * 1024 * 1024) {
      throw ArgumentError('Файл слишком большой (макс. 8 МБ)');
    }
    final ext = () {
      final n = file.name.toLowerCase();
      if (n.endsWith('.png')) return 'png';
      if (n.endsWith('.webp')) return 'webp';
      if (n.endsWith('.gif')) return 'gif';
      return 'jpg';
    }();
    final ref = _storage
        .ref()
        .child('users')
        .child(user.uid)
        .child('profile_${DateTime.now().millisecondsSinceEpoch}.$ext');

    try {
      return await _putAndGetUrl(
        ref: ref,
        bytes: bytes,
        fileLabel: file.name,
      );
    } catch (e, st) {
      debugPrint('Profile photo upload: $e\n$st');
      rethrow;
    }
  }

  /// Картинка для своей награды в магазине: `users/{uid}/shop_reward_*`.
  Future<String> uploadShopRewardImage(XFile file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Войдите в аккаунт, чтобы загрузить фото');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw ArgumentError('Пустой файл');
    }
    if (bytes.length > 8 * 1024 * 1024) {
      throw ArgumentError('Файл слишком большой (макс. 8 МБ)');
    }
    final ext = () {
      final n = file.name.toLowerCase();
      if (n.endsWith('.png')) return 'png';
      if (n.endsWith('.webp')) return 'webp';
      if (n.endsWith('.gif')) return 'gif';
      return 'jpg';
    }();
    final ref = _storage
        .ref()
        .child('users')
        .child(user.uid)
        .child('shop_reward_${DateTime.now().millisecondsSinceEpoch}.$ext');

    try {
      return await _putAndGetUrl(
        ref: ref,
        bytes: bytes,
        fileLabel: file.name,
      );
    } catch (e, st) {
      debugPrint('Shop reward photo upload: $e\n$st');
      rethrow;
    }
  }
}
