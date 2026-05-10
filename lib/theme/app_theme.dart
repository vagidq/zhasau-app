import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get current {
    final dark = AppColors.isDarkMode.value;
    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.blue,
      onSecondary: Colors.white,
      surface: AppColors.bgWhite,
      onSurface: AppColors.textDark,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.borderDark,
      error: AppColors.red,
      onError: Colors.white,
    );

    final baseText = TextStyle(
      color: AppColors.textDark,
      fontFamily: 'Inter',
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgMain,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textDark),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: TextStyle(color: AppColors.textLight, fontSize: 15),
      ),
      textTheme: TextTheme(
        displayLarge: baseText,
        displayMedium: baseText,
        displaySmall: baseText,
        headlineLarge: baseText,
        headlineMedium: baseText,
        headlineSmall: baseText,
        titleLarge: baseText.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: baseText.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: baseText.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseText.copyWith(fontSize: 16),
        bodyMedium: baseText.copyWith(fontSize: 14),
        bodySmall: baseText.copyWith(
          fontSize: 12,
          color: AppColors.textMuted,
        ),
        labelLarge: baseText.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
