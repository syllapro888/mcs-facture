import 'package:flutter/material.dart';

/// Mêmes couleurs que MCS Facture.
class AppColors {
  static const dark = Color(0xFF0B2A5B);
  static const light = Color(0xFF3FA9F5);
  static const yellow = Color(0xFFF7B500);
  static const background = Color(0xFFF4F7FB);
  static const green = Color(0xFF2E9E5B);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.dark,
        primary: AppColors.dark,
        secondary: AppColors.light,
        tertiary: AppColors.yellow,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
