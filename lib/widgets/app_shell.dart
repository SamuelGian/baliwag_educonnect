import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../theme/app_theme_context.dart';
import '../theme/breakpoints.dart';
import '../theme/theme_controller.dart';
import '../screens/student_dashboard_screen.dart';
import '../screens/scholarship_application_screen.dart';
import '../screens/application_tracker_screen.dart';
import '../screens/profile_settings_screen.dart';
import 'glass_nav_bar.dart';
import 'logout_confirm_dialog.dart';
import 'nav_destination_spec.dart';

const _destinations = [
  NavDestinationSpec(
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
  ),
  NavDestinationSpec(
    label: 'Apply',
    icon: Icons.edit_document,
    selectedIcon: Icons.assignment_rounded,
  ),
  NavDestinationSpec(
    label: 'Tracker',
    icon: Icons.timeline_outlined,
    selectedIcon: Icons.timeline_rounded,
  ),
  NavDestinationSpec(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _railCollapsed = false;
  bool _hoverReveal = false;

  static const _screens = [
    StudentDashboardScreen(),
    ScholarshipApplicationScreen(),
    ApplicationTrackerScreen(),
    ProfileSettingsScreen(),
  ];

  void goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final wide = width >= kDesktopBreakpoint;
    // See the matching comment in AdminShell: a full 240px labeled rail
    // between 600-840px total width leaves too little room for content,
    // which was squeezing card text down to ellipsis.
    final railMini = wide && width < kFullSidebarMinWidth;
    final railWidth = railMini ? kMiniSidebarWidth : kSidebarWidth;

    final body = IndexedStack(index: _index, children: _screens);

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
                      child: _SideRail(
                        index: _index,
                        mini: railMini,
                        onSelect: goTo,
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

    // The nav bar floats over the page in a Stack (not
    // Scaffold.bottomNavigationBar) so its frosted-glass blur has real,
    // scrolling content behind it to blur — a docked bottomNavigationBar
    // would just sit on the bare Scaffold background. `body` fills the full
    // Stack, unpadded — each screen paints its own AmbientBackground, and
    // padding this outer wrapper would shrink that background short of the
    // real screen edge, exposing the Scaffold's own (visibly navy, in dark
    // mode) background in the gap behind the bar instead of page content.
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
              onSelect: goTo,
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

class _SideRail extends StatelessWidget {
  final int index;
  final bool mini;
  final ValueChanged<int> onSelect;
  final VoidCallback onCollapse;

  const _SideRail({
    required this.index,
    required this.mini,
    required this.onSelect,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
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
      child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
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
                child: Text(
                  'Baliwag\nEduConnect',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: context.appColors.textPrimary,
                  ),
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
              key: ValueKey('nav-${_destinations[i].label}'),
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
    final initials = app.studentName
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
            Tooltip(message: app.studentName, child: avatar),
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
                app.studentName,
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
