import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get current => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: AppColors.isDarkMode.value ? Brightness.dark : Brightness.light,
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.bgWhite,
          onSurface: AppColors.textDark,
        ),
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
      );
}
