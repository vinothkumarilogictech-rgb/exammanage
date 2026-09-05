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
        color: Colors.white,
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
