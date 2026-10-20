import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_settings_screen.dart';
import '../theme/app_theme_context.dart';
import '../theme/breakpoints.dart';
import '../theme/theme_controller.dart';
import '../widgets/ambient_background.dart';
import 'glass_nav_bar.dart';
import 'logout_confirm_dialog.dart';
import 'nav_destination_spec.dart';

const _destinations = [
  NavDestinationSpec(
    label: 'Applications',
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check_rounded,
  ),
  NavDestinationSpec(
    label: 'Scholarships',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school_rounded,
  ),
  NavDestinationSpec(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  ),
];

/// Top-level shell for an approved Scholarship Provider account. A near
/// twin of [AdminShell] — same responsive side-rail/bottom-nav layout — but
/// scoped to just the two program-management tabs a provider needs
/// (Applications, Scholarships already filter themselves to the
/// signed-in provider's own data via AppState, see app_state.dart) plus
/// Settings. No Announcements tab: platform-wide communication stays an
/// Admin-only tool, not something any one provider should be able to blast
/// to every student.
class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _index = 0;
  bool _railCollapsed = false;
  bool _hoverReveal = false;

  static const _screens = [
    ApplicationsTab(),
    ScholarshipsTab(),
    AdminSettingsScreen(),
  ];

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final wide = width >= kDesktopBreakpoint;
    final railMini = wide && width < kFullSidebarMinWidth;
    final railWidth = railMini ? kMiniSidebarWidth : kSidebarWidth;

    final body = AmbientBackground(
      child: IndexedStack(index: _index, children: _screens),
    );

    if (wide) {
      return Scaffold(
        body: Stack(
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  width: _railCollapsed ? 0 : railWidth,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: railWidth,
                      maxWidth: railWidth,
                      child: _ProviderSideRail(
                        index: _index,
                        mini: railMini,
                        onSelect: _goTo,
                        onCollapse: () => setState(() => _railCollapsed = true),
                      ),
                    ),
                  ),
                ),
                if (!_railCollapsed)
                  VerticalDivider(width: 1, color: context.appColors.border),
                Expanded(child: body),
              ],
            ),
            if (_railCollapsed)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 64,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hoverReveal = true),
                  onExit: (_) => setState(() => _hoverReveal = false),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, top: 12),
                      child: AnimatedOpacity(
                        opacity: _hoverReveal ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: IgnorePointer(
                          ignoring: !_hoverReveal,
                          child: _RoundIconButton(
                            icon: Icons.menu_open_rounded,
                            tooltip: 'Show sidebar',
                            onTap: () => setState(() => _railCollapsed = false),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(
        children: [
          body,
          Positioned(
            left: 20,
            right: 20,
            bottom: 20 + bottomInset,
            child: GlassNavBar(
              index: _index,
              onSelect: _goTo,
              destinations: _destinations,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.scheme.surface,
          border: Border.all(color: context.appColors.border),
          boxShadow: [
            BoxShadow(
              color: context.appColors.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Icon(
                icon,
                size: 20,
                color: context.appColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailDarkModeToggle extends StatelessWidget {
  final bool mini;

  const _RailDarkModeToggle({required this.mini});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final isDark = theme.isDarkMode;
    final icon = Icon(
      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      size: 18,
      color: context.appColors.textMuted,
    );

    if (mini) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        child: Tooltip(
          message: isDark ? 'Light mode' : 'Dark mode',
          child: Material(
            color: context.appColors.neutralBg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: theme.toggleDarkMode,
              child: Padding(padding: const EdgeInsets.all(12), child: icon),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: context.appColors.neutralBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: theme.toggleDarkMode,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Text(
                  isDark ? 'Light mode' : 'Dark mode',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderSideRail extends StatelessWidget {
  final int index;
  final bool mini;
  final ValueChanged<int> onSelect;
  final VoidCallback onCollapse;

  const _ProviderSideRail({
    required this.index,
    required this.mini,
    required this.onSelect,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final orgName = context.watch<AppState>().user.organizationName;
    final logo = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.appColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: context.scheme.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.corporate_fare_rounded,
        color: Colors.white,
        size: 20,
      ),
    );

    final header = mini
        ? Column(
            children: [
              logo,
              const SizedBox(height: 10),
              Tooltip(
                message: 'Hide sidebar',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onCollapse,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.menu_open_rounded,
                      size: 16,
                      color: context.appColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          )
        : Row(
            children: [
              logo,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orgName.isEmpty ? 'Provider' : orgName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PROVIDER',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: context.scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Hide sidebar',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onCollapse,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.menu_open_rounded,
                      size: 18,
                      color: context.appColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          );

    return Container(
      width: mini ? kMiniSidebarWidth : kSidebarWidth,
      decoration: BoxDecoration(
        color: context.appColors.glassSurfaceStrong,
        boxShadow: [
          BoxShadow(
            color: context.appColors.cardShadow,
            blurRadius: 24,
            offset: const Offset(6, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: mini ? 10 : 22),
            child: header,
          ),
          const SizedBox(height: 32),
          for (int i = 0; i < _destinations.length; i++)
            _RailItem(
              key: ValueKey('provider-nav-${_destinations[i].label}'),
              spec: _destinations[i],
              selected: i == index,
              mini: mini,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          _RailDarkModeToggle(mini: mini),
          _RailAccountCard(mini: mini),
        ],
      ),
    );
  }
}

class _RailAccountCard extends StatelessWidget {
  final bool mini;

  const _RailAccountCard({required this.mini});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = app.user.fullName;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join()
        .toUpperCase();
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: context.scheme.primary,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (mini) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
        child: Column(
          children: [
            Tooltip(message: name, child: avatar),
            const SizedBox(height: 8),
            IconButton(
              tooltip: 'Log out',
              icon: Icon(
                Icons.logout_rounded,
                size: 18,
                color: context.appColors.textMuted,
              ),
              onPressed: () => confirmSignOut(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.glassSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appColors.glassBorder),
        ),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Log out',
              icon: Icon(
                Icons.logout_rounded,
                size: 18,
                color: context.appColors.textMuted,
              ),
              onPressed: () => confirmSignOut(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final NavDestinationSpec spec;
  final bool selected;
  final bool mini;
  final VoidCallback onTap;

  const _RailItem({
    super.key,
    required this.spec,
    required this.selected,
    required this.mini,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? spec.selectedIcon : spec.icon,
      size: 20,
      color: selected ? context.scheme.primary : context.appColors.textMuted,
    );
    final labelStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: selected
          ? context.scheme.primary
          : context.appColors.textSecondary,
    );

    final button = Material(
      color: selected
          ? context.scheme.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: mini
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: icon),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        spec.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mini ? 10 : 14, vertical: 4),
      child: mini ? Tooltip(message: spec.label, child: button) : button,
    );
  }
}
