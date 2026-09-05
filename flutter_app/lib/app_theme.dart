import 'package:flutter/material.dart';

/// ============================================================
/// BRAND COLOR SYSTEM — iLOGIC TECH
/// Derived from the brand mark: deep blue → violet → magenta.
/// ============================================================
class AppColors {
  // Core brand identity (blue -> purple -> magenta, matches the logo)
  static const brandBlue = Color(0xFF2A17C9);
  static const primary = Color(0xFF6C1FB0); // primary purple — buttons, active states, icons
  static const primaryLight = Color(0xFF9A22C7); // bright purple-magenta — secondary bars, FAB
  static const magenta = Color(0xFFE0189E); // accent magenta/pink — gradient end, highlights
  static const primaryDark = Color(0xFF3D0F8C); // deep indigo — darkest gradient stop

  // Full 3-stop brand gradient used across nav bars / headers / buttons
  static const List<Color> brandGradient = [brandBlue, primary, magenta];
  static const List<Color> brandGradientSoft = [primaryLight, magenta];

  // Light, mild tints for backgrounds, cards, inputs (never loud)
  static const surface = Color(0xFFF7F5FD); // app-wide light lavender background
  static const surfaceAlt = Color(0xFFFFFFFF);
  static const tint = Color(0xFFEDE9FE); // light purple tint — borders, chips, indicators
  static const tintStrong = Color(0xFFF0E3FA); // slightly richer tint — icon backgrounds

  // Semantic / status colors (kept distinct from brand so meaning stays clear)
  static const green = Color(0xFF15803D);
  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFD97706); // warning / pending
  static const red = Color(0xFFDC2626); // danger / failed

  static const textDark = Color(0xFF1F1533);
  static const textMuted = Color(0xFF6B6280);
}

/// Reusable linear gradient for app bars, buttons, and highlight surfaces.
LinearGradient brandLinearGradient({
  AlignmentGeometry begin = Alignment.topLeft,
  AlignmentGeometry end = Alignment.bottomRight,
}) =>
    LinearGradient(begin: begin, end: end, colors: AppColors.brandGradient);

class AppBarStyle {
  static const double height = 72;
  static const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
  );
  static const titleStyle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 21,
    letterSpacing: 0.2,
    color: Colors.white,
  );

  /// Standard decoration for a gradient app-bar flexibleSpace, used
  /// consistently across every screen's colorful top bar.
  static BoxDecoration gradientDecoration({double radius = 24}) => BoxDecoration(
        gradient: brandLinearGradient(),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(.33),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
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
      color: Colors.white,
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
      backgroundColor: Colors.white,
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
