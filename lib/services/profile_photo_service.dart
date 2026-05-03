import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Загрузка фото профиля в Firebase Storage (`users/{uid}/profile_*.jpg`).
class ProfilePhotoService {
  ProfilePhotoService._();
  static final ProfilePhotoService instance = ProfilePhotoService._();

  static String _contentTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
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
    final ref = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(user.uid)
        .child('profile_${DateTime.now().millisecondsSinceEpoch}.$ext');

    try {
      await ref.putData(
        bytes,
        SettableMetadata(contentType: _contentTypeForName(file.name)),
      );
      return ref.getDownloadURL();
    } catch (e, st) {
      debugPrint('Profile photo upload: $e\n$st');
      rethrow;
    }
  }
}
