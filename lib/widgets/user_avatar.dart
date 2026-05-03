import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Аватар: [photoUrl], иначе Google Auth, иначе инициалы из [displayName].
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.previewBytes,
    this.radius = 24,
    /// Для списков «чужих» пользователей задать [false], иначе при пустом [photoUrl]
    /// подставится фото текущего [FirebaseAuth] аккаунта.
    this.fallbackToAuthPhoto = true,
  });

  final String displayName;
  final String? photoUrl;
  final Uint8List? previewBytes;
  final double radius;
  final bool fallbackToAuthPhoto;

  String? _effectiveUrl() {
    final p = photoUrl?.trim();
    if (p != null && p.isNotEmpty) return p;
    if (!fallbackToAuthPhoto) return null;
    final a = FirebaseAuth.instance.currentUser?.photoURL;
    if (a != null && a.isNotEmpty) return a;
    return null;
  }

  String _initials() {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts[0];
      if (s.isEmpty) return '?';
      return s.substring(0, 1).toUpperCase();
    }
    final a = parts[0];
    final b = parts[1];
    if (a.isEmpty && b.isEmpty) return '?';
    if (a.isEmpty) return b.substring(0, 1).toUpperCase();
    if (b.isEmpty) return a.substring(0, 1).toUpperCase();
    return '${a[0]}${b[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = _effectiveUrl();
    final d = radius * 2;
    if (previewBytes != null && previewBytes!.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          previewBytes!,
          width: d,
          height: d,
          fit: BoxFit.cover,
        ),
      );
    }
    if (url != null) {
      return ClipOval(
        child: Image.network(
          url,
          width: d,
          height: d,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsAvatar(),
        ),
      );
    }
    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        _initials(),
        style: TextStyle(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
