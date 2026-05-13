import 'dart:math' as math;

/// Утилиты для генерации читаемых ID документов в Firestore.
///
/// Имена коллекций (`tasks`, `goals`, `habits`, `notifications`) задаются на
/// уровне Firestore структуры, а вот ID документов раньше были автогенерируемые
/// шифры. Теперь генерируем человекочитаемые ID на основе заголовка:
/// `task-utrennyaya-probezhka-7f3a`, `goal-sport-1b9c` и т.п.

const Map<String, String> _cyrillicToLatin = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd',
  'е': 'e', 'ё': 'yo', 'ж': 'zh', 'з': 'z', 'и': 'i',
  'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n',
  'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't',
  'у': 'u', 'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch',
  'ш': 'sh', 'щ': 'sch', 'ъ': '', 'ы': 'y', 'ь': '',
  'э': 'e', 'ю': 'yu', 'я': 'ya',
};

String _transliterate(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    final mapped = _cyrillicToLatin[ch];
    if (mapped != null) {
      buffer.write(mapped);
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

/// Преобразует строку в slug: транслит кириллицы, нижний регистр,
/// замена не‑буквенно‑цифровых символов на `-`, обрезка до [maxLen].
String slugify(String input, {int maxLen = 40}) {
  final translit = _transliterate(input);
  final replaced = translit.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final trimmed = replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  if (trimmed.length <= maxLen) return trimmed;
  return trimmed.substring(0, maxLen).replaceAll(RegExp(r'-+$'), '');
}

final math.Random _rng = math.Random();

/// Короткий случайный суффикс из hex (по умолчанию 6 символов).
String shortSuffix({int length = 6}) {
  const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
  return List<String>.generate(
    length,
    (_) => chars[_rng.nextInt(chars.length)],
  ).join();
}

/// Сборка читаемого ID: `prefix-slug-suffix`.
///
/// Если slug пустой (например, заголовок состоит только из эмодзи) —
/// используется только префикс и суффикс: `prefix-suffix`.
String makeReadableId(String prefix, String title, {int maxSlug = 40}) {
  final slug = slugify(title, maxLen: maxSlug);
  final suffix = shortSuffix();
  if (slug.isEmpty) return '$prefix-$suffix';
  return '$prefix-$slug-$suffix';
}
