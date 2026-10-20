import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme_context.dart';
import '../theme/theme_controller.dart';
import 'nav_destination_spec.dart';

/// A floating, frosted-glass bottom navigation bar — detached from the
/// screen edges (placed via a [Stack] + [Positioned] by the caller, not as
/// a [Scaffold.bottomNavigationBar]) so real content is visible, blurred,
/// underneath it as the page scrolls. Only the selected destination expands
/// into a filled accent pill; everything else stays a plain icon.
///
/// Usage (in a narrow-screen [Scaffold]):
/// ```dart
/// Scaffold(
///   body: Stack(
///     children: [
///       Padding(padding: const EdgeInsets.only(bottom: 90), child: page),
///       Positioned(
///         left: 20,
///         right: 20,
///         bottom: 20,
///         child: GlassNavBar(
///           index: _index,
///           onSelect: (i) => setState(() => _index = i),
///           destinations: _destinations,
///         ),
///       ),
///     ],
///   ),
/// )
/// ```
class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<NavDestinationSpec> destinations;

  const GlassNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeController>().isDarkMode;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        // The blur is what makes this "glass" — without it, the
        // semi-transparent Container below would just look like a plain
        // translucent bar with whatever happens to be behind it showing
        // through sharply.
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: isDark
                ? Colors.black.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.35),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: context.appColors.cardShadow,
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          // Each destination gets an equal-width flex slot rather than
          // free-form `spaceEvenly` sizing: this bar now hosts up to 5
          // destinations (Admin's "Providers" tab added alongside the
          // existing 4), and a plain Row sized to its children's natural
          // width could overflow on a narrow phone once the pills'
          // combined width exceeds the screen. Dividing the available
          // width evenly guarantees it never overflows, for any number of
          // destinations, while still centering each icon/pill in its slot
          // the same way `spaceEvenly` visually did.
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: Center(
                    child: _GlassNavItem(
                      key: ValueKey('glass-nav-${destinations[i].label}'),
                      spec: destinations[i],
                      selected: i == index,
                      onTap: () => onSelect(i),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  final NavDestinationSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _GlassNavItem({
    super.key,
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeController>().isDarkMode;
    final inactiveColor = isDark
        ? Colors.white70
        : context.appColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 16 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: selected
                ? LinearGradient(
                    colors: context.appColors.heroGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? spec.selectedIcon : spec.icon,
                size: 22,
                color: selected ? Colors.white : inactiveColor,
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            spec.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        )
                      : const SizedBox(width: 0, height: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
