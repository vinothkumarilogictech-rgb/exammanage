import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFE85D04);
 static const primaryLight = Color(0xFFFF7A18);
  static const green = Color(0xFF15803D);
  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFFF7A18);
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
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: const Color(0xFFFFFBF7),
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFFE1CC)),),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFFE1CC)),),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF7A18), width: 1.5),),
    ),
  );
}
