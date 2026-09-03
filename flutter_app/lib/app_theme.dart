import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFFF5A36);
  static const primaryDark = Color(0xFFE64A2E);
  static const primaryLight = Color(0xFFFF8A5C);
  static const green = Color(0xFF15803D);
  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFD97706);
  static const red = Color(0xFFDC2626);
}

class AppBarStyle {
  static const double height = 72;
  static const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
  );
  static const titleStyle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 21,
    letterSpacing: 0.2,
    color: Colors.white,
  );
}

ThemeData appTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
    ),
    scaffoldBackgroundColor: const Color(0xFFFFF7F4),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    ),
  );
}
