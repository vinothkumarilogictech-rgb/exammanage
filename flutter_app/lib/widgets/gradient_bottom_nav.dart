import 'package:flutter/material.dart';
import '../app_theme.dart';

/// ============================================================
/// GRADIENT BOTTOM NAVIGATION BAR — iLOGIC TECH
/// ============================================================

class GradientNavDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const GradientNavDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

class GradientBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<GradientNavDestination> destinations;
  final double height;
  final double radius;

  const GradientBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.height = 72,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: brandLinearGradient(),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(radius),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(.33),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(radius),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          minimum: const EdgeInsets.only(
            top: 2,
          ),
          child: Row(
            children: List.generate(
              destinations.length,
              (i) {
                final d = destinations[i];
                final selected = i == selectedIndex;

                return Expanded(
                  child: _NavItem(
                    destination: d,
                    selected: selected,
                    onTap: () => onDestinationSelected(i),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final GradientNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = selected
        ? (destination.selectedIcon ?? destination.icon)
        : destination.icon;

    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,

        // Reduced vertical margin/padding to prevent overflow.
        margin: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 4,
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 3,
        ),

        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 23,
              color: selected
                  ? Colors.white
                  : Colors.white.withOpacity(.65),
            ),

            const SizedBox(height: 1),

            Flexible(
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.0,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : Colors.white.withOpacity(.65),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}