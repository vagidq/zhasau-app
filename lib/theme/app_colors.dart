import 'package:flutter/material.dart';

class AppColors {
  static final ValueNotifier<bool> isDarkMode = ValueNotifier(false);

  static Color primary = const Color(0xFF9333EA);
  static Color primaryLight = const Color(0xFFF3E8FF);
  static Color primaryDark = const Color(0xFF7E22CE);

  static Color bgMain = const Color(0xFFF7F7F9);
  static Color bgWhite = const Color(0xFFFFFFFF);

  static Color textDark = const Color(0xFF111827);
  static Color textMuted = const Color(0xFF6B7280);
  static Color textLight = const Color(0xFF9CA3AF);

  static Color border = const Color(0xFFF3F4F6);
  static Color borderDark = const Color(0xFFE5E7EB);

  static Color success = const Color(0xFF10B981);
  static Color successLight = const Color(0xFFD1FAE5);

  static Color warning = const Color(0xFFF59E0B);
  static Color warningLight = const Color(0xFFFEF3C7);

  static Color blue = const Color(0xFF3B82F6);
  static Color blueLight = const Color(0xFFDBEAFE);

  static Color yellow = const Color(0xFFFBBF24);
  static Color red = const Color(0xFFEF4444);
  static Color redLight = const Color(0xFFFEE2E2);

  static void toggleTheme(bool dark) {
    // Сначала обновляем все цвета, потом уведомляем слушателей
    if (dark) {
      primary = const Color(0xFFA855F7);
      primaryLight = const Color(0xFF4C1D95);
      primaryDark = const Color(0xFFD8B4FE);
      bgMain = const Color(0xFF0F172A);
      bgWhite = const Color(0xFF1E293B);
      textDark = const Color(0xFFF8FAFC);
      textMuted = const Color(0xFF94A3B8);
      textLight = const Color(0xFF64748B);
      border = const Color(0xFF334155);
      borderDark = const Color(0xFF475569);
      success = const Color(0xFF34D399);
      successLight = const Color(0xFF064E3B);
      warning = const Color(0xFFFBBF24);
      warningLight = const Color(0xFF78350F);
      blue = const Color(0xFF60A5FA);
      blueLight = const Color(0xFF1E3A8A);
      yellow = const Color(0xFFFCD34D);
      red = const Color(0xFFF87171);
      redLight = const Color(0xFF7F1D1D);
    } else {
      primary = const Color(0xFF9333EA);
      primaryLight = const Color(0xFFF3E8FF);
      primaryDark = const Color(0xFF7E22CE);
      bgMain = const Color(0xFFF7F7F9);
      bgWhite = const Color(0xFFFFFFFF);
      textDark = const Color(0xFF111827);
      textMuted = const Color(0xFF6B7280);
      textLight = const Color(0xFF9CA3AF);
      border = const Color(0xFFF3F4F6);
      borderDark = const Color(0xFFE5E7EB);
      success = const Color(0xFF10B981);
      successLight = const Color(0xFFD1FAE5);
      warning = const Color(0xFFF59E0B);
      warningLight = const Color(0xFFFEF3C7);
      blue = const Color(0xFF3B82F6);
      blueLight = const Color(0xFFDBEAFE);
      yellow = const Color(0xFFFBBF24);
      red = const Color(0xFFEF4444);
      redLight = const Color(0xFFFEE2E2);
    }
    // Уведомляем слушателей ПОСЛЕ того, как все цвета обновлены
    isDarkMode.value = dark;
  }
}
