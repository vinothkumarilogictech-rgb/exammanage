import 'package:flutter/material.dart';

/// ============================================================
/// BRAND COLOR SYSTEM — iLOGIC TECH
/// Derived from the brand mark: deep blue → violet → magenta.
/// ============================================================
class AppColors {
  
  static const brandBlue = Color(0xFF2A17C9);
  static const primary = Color(0xFF6C1FB0); 
  static const primaryLight = Color(0xFF9A22C7); 
  static const magenta = Color(0xFFE0189E); 
  static const primaryDark = Color(0xFF3D0F8C); 

  static const List<Color> brandGradient = [brandBlue, primary, magenta];
  static const List<Color> brandGradientSoft = [primaryLight, magenta];

  static const surface = Color(0xFFF5F0FC); 
  static const surfaceAlt = Color(0xFFFCF7FF);
  static const tint = Color(0xFFEDE9FE); 
  static const tintStrong = Color(0xFFF2E6FB); 

  /// Soft brand-tinted fill for search boxes, selectors, and filter bars
  /// that sit directly on the app's light background — colorful instead
  /// of plain white/gray, but still light enough to read as a form field.
  static Color searchFill = tint.withOpacity(.55);
  static Color searchBorder = primary.withOpacity(.14);

  static const green = Color(0xFF15803D);
  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFD97706); // warning / pending
  static const red = Color(0xFFDC2626); // danger / failed

  static const textDark = Color(0xFF1F1533);
  static const textMuted = Color(0xFF6B6280);
}


LinearGradient brandLinearGradient({
  AlignmentGeometry begin = Alignment.topLeft,
  AlignmentGeometry end = Alignment.bottomRight,
}) =>
    LinearGradient(begin: begin, end: end, colors: AppColors.brandGradient);

class AppBarStyle {
  static const double height = 72;
  // Flat/square app bar — no rounded bottom corners, used consistently
  // across every screen's top bar.
  static const shape = RoundedRectangleBorder();
  static const titleStyle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 21,
    letterSpacing: 0.2,
    color: Colors.white,
  );

  /// Standard decoration for a gradient app-bar flexibleSpace, used
  /// consistently across every screen's colorful top bar.
  static BoxDecoration gradientDecoration({double radius = 0}) => BoxDecoration(
        gradient: brandLinearGradient(),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(.33),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        borderRadius: radius > 0
            ? BorderRadius.vertical(bottom: Radius.circular(radius))
            : null,
      );
}

/// A drop-in gradient AppBar so every screen shares the exact same
/// colorful top nav treatment without repeating the gradient code.
PreferredSizeWidget gradientAppBar({
  required String title,
  List<Widget>? actions,
  Widget? leading,
  double height = AppBarStyle.height,
}) {
  return AppBar(
    elevation: 0,
    toolbarHeight: height,
    shape: AppBarStyle.shape,
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    leading: leading,
    flexibleSpace: Container(decoration: AppBarStyle.gradientDecoration()),
    title: Text(title, style: AppBarStyle.titleStyle),
    actions: actions,
  );
}

ThemeData appTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(centerTitle: false),

    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surfaceAlt,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.tint, width: 1),
      ),
    ),

    // Mild, colorful text fields / search boxes app-wide
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.tint.withOpacity(.45),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500),
      prefixIconColor: AppColors.primary,
      suffixIconColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.tint),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.tint),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.6),
      ),
    ),

    // Colorful, gradient-friendly buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
      elevation: 2,
    ),

    // Colorful bottom navigation
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceAlt,
      indicatorColor: AppColors.tint,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: AppColors.primary.withOpacity(.18),
      labelTextStyle: MaterialStateProperty.resolveWith((states) {
        final selected = states.contains(MaterialState.selected);
        return TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? AppColors.primary : AppColors.textMuted,
        );
      }),
      iconTheme: MaterialStateProperty.resolveWith((states) {
        final selected = states.contains(MaterialState.selected);
        return IconThemeData(color: selected ? AppColors.primary : AppColors.textMuted);
      }),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.tint,
      labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),
  );
}
