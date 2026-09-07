import 'package:flutter/material.dart';
import '../app_theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.primary));
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 42, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ]),
        ),
      );
}

/// Colorful metric / stat card. Each card gets a soft gradient tint
/// background with a solid gradient icon chip, matching the brand
/// palette (blue -> purple -> magenta). Pass [colors] to give a card
/// its own accent (defaults to the brand gradient) so a row of metric
/// cards reads as a lively, distinct set rather than repeated tiles.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color>? colors;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = colors ?? AppColors.brandGradient;
    final accent = gradientColors.first;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(.16)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors.length > 1
                  ? gradientColors
                  : [gradientColors.first, gradientColors.first],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(.35), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Preset accent combos so different metric cards in the same row can
/// each carry a distinct, brand-consistent gradient.
class StatCardAccents {
  static const blue = [AppColors.brandBlue, Color(0xFF5A3FE0)];
  static const purple = [AppColors.primary, AppColors.primaryLight];
  static const magenta = [AppColors.primaryLight, AppColors.magenta];
  static const teal = [Color(0xFF0EA5A5), Color(0xFF14B8A6)];
}

/// A mild, colorful search field used across list screens — soft
/// lavender fill with a brand-purple icon and focus ring, matching the
/// rest of the UI instead of a plain white search bar.
class BrandSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  const BrandSearchField({
    super.key,
    this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tint.withOpacity(.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(.14)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
          suffixIcon: trailing,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
      ),
    );
  }
}

/// A varied, brand-consistent palette so each list card's leading avatar
/// gets a distinct color drawn from the entity's name, instead of every
/// row on a page (branches, employees, teams...) reusing the same flat
/// purple square.
class AvatarPalette {
  static const List<List<Color>> gradients = [
    [Color(0xFF2A17C9), Color(0xFF6C1FB0)], // blue -> purple
    [Color(0xFF0EA5A5), Color(0xFF14B8A6)], // teal
    [Color(0xFFD97706), Color(0xFFF59E0B)], // amber
    [Color(0xFFDC2626), Color(0xFFEF4444)], // red
    [Color(0xFF15803D), Color(0xFF22C55E)], // green
    [Color(0xFFE0189E), Color(0xFFEC4899)], // magenta
    [Color(0xFF2563EB), Color(0xFF60A5FA)], // blue
    [Color(0xFF7C3AED), Color(0xFFA78BFA)], // violet
  ];

  static List<Color> forSeed(String seed) {
    if (seed.isEmpty) return gradients.first;
    final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    return gradients[hash % gradients.length];
  }
}

/// Colorful rounded-square avatar used on list rows (branches, employees,
/// teams, etc). Picks a gradient from [AvatarPalette] keyed to [seed] (the
/// entity's name) so a whole list of cards reads as lively and distinct
/// rather than one repeated color, and lines up consistently with the
/// title/subtitle text next to it.
class EntityAvatar extends StatelessWidget {
  final String seed;
  final String? letter;
  final IconData? icon;
  final double size;

  const EntityAvatar({
    super.key,
    required this.seed,
    this.letter,
    this.icon,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AvatarPalette.forSeed(seed);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(size * .32),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: Colors.white, size: size * .46)
            : Text(
                letter ?? '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * .36,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

/// Soft, seed-based tint for a whole list-row card background (not just its
/// avatar), so a list of cards each reads as a distinct colorful block
/// instead of uniform white/lavender rows. Mirrors [AvatarPalette] so a
/// card's background always harmonizes with its own avatar color.
class CardTint {
  static Color fill(String seed, {double opacity = .16}) =>
      AvatarPalette.forSeed(seed).first.withOpacity(opacity);

  static Color border(String seed, {double opacity = .30}) =>
      AvatarPalette.forSeed(seed).first.withOpacity(opacity);

  /// Ready-to-use decoration for a colorful list-row card: tinted fill,
  /// tinted border, rounded corners. Pass the same [seed] used for that
  /// row's [EntityAvatar] so the whole card and its avatar match.
  static BoxDecoration decoration(String seed, {double radius = 20}) => BoxDecoration(
        color: fill(seed),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border(seed), width: 1.1),
      );
}
/// PopupMenuButton's `icon:` instead of a bare Icon so the edit/delete
/// menu reads as a deliberate, professional control instead of a plain
/// 3-dot glyph sitting on white.
class MenuTriggerIcon extends StatelessWidget {
  final Color color;
  final double size;
  const MenuTriggerIcon({super.key, this.color = AppColors.primary, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(Icons.more_vert_rounded, color: color, size: size * .56),
    );
  }
}
