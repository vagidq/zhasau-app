import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Кеширует ID документа `users/{...}` для текущего Firebase‑пользователя.
///
/// Раньше доки лежали по `users/{authUid}` — в консоли Firebase ID выглядел как
/// шифр. После рефакторинга мы храним данные по `users/{user-name-...}` и
/// держим поле `uid: <authUid>` внутри документа.
///
/// Этот сервис делает один лёгкий поиск по `where('uid', isEqualTo: ...)` и
/// запоминает результат на сессию. Все остальные обращения берут готовый ID
/// из кеша.
class CurrentUserDoc {
  CurrentUserDoc._();

  /// Кеш в памяти; сбрасывается при выходе из аккаунта.
  static String? _cachedDocId;
  static String? _cachedAuthUid;

  /// Синхронный доступ к кешу: вернёт `null`, если резолвинг ещё не выполнен.
  /// Используется в местах, где нельзя `await`, как fallback используется `authUid`.
  static String? cachedDocId() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    if (_cachedAuthUid != uid) return null;
    return _cachedDocId;
  }

  /// Гарантирует, что для текущего пользователя резолвинг выполнен. Используется
  /// при старте приложения и при смене аккаунта.
  static Future<void> bootstrap() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      reset();
      return;
    }
    await docId();
  }

  /// Возвращает ID документа `users/{?}` для текущего пользователя.
  ///
  /// Никогда не бросает: если поиск не удался (например, нет сети) —
  /// возвращает auth `uid` как fallback, чтобы старый формат продолжал работать.
  static Future<String> docId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('No authenticated user');
    }

    if (_cachedAuthUid == uid && _cachedDocId != null) {
      return _cachedDocId!;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        _cachedAuthUid = uid;
        _cachedDocId = query.docs.first.id;
        return _cachedDocId!;
      }
    } catch (e) {
      debugPrint('CurrentUserDoc.docId resolution error: $e');
    }

    // Старый формат данных (миграция ещё не прошла).
    _cachedAuthUid = uid;
    _cachedDocId = uid;
    return _cachedDocId!;
  }

  /// Принудительно зафиксировать соответствие `authUid → docId` (используется
  /// в миграции и при создании нового профиля).
  static void rememberFor(String authUid, String docId) {
    _cachedAuthUid = authUid;
    _cachedDocId = docId;
  }

  /// Сбросить кеш — вызывать после logout / смены аккаунта.
  static void reset() {
    _cachedAuthUid = null;
    _cachedDocId = null;
  }
}
