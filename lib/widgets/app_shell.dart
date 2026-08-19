import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../screens/student_dashboard_screen.dart';
import '../screens/scholarship_application_screen.dart';
import '../screens/application_tracker_screen.dart';
import '../screens/profile_settings_screen.dart';

class NavDestinationSpec {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const NavDestinationSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

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
    final wide = width >= 900;

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
                  width: _railCollapsed ? 0 : 240,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: 240,
                      maxWidth: 240,
                      child: _SideRail(
                        index: _index,
                        onSelect: goTo,
                        onCollapse: () => setState(() => _railCollapsed = true),
                      ),
                    ),
                  ),
                ),
                if (!_railCollapsed)
                  VerticalDivider(width: 1, color: AppColors.border),
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

    return Scaffold(
      body: body,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.glassSurfaceStrong,
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 80,
            child: Row(
              children: [
                Expanded(
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: goTo,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    labelBehavior: width < 380
                        ? NavigationDestinationLabelBehavior.onlyShowSelected
                        : NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: [
                      for (final d in _destinations)
                        NavigationDestination(
                          key: ValueKey('nav-${d.label}'),
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: VerticalDivider(width: 1, color: AppColors.border),
                ),
                const _BottomBarDarkModeToggle(),
                const _BottomBarLogoutButton(),
              ],
            ),
          ),
        ),
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
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
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
              child: Icon(icon, size: 20, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarDarkModeToggle extends StatelessWidget {
  const _BottomBarDarkModeToggle();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return IconButton(
      tooltip: theme.isDarkMode
          ? 'Switch to light mode'
          : 'Switch to dark mode',
      icon: Icon(
        theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: AppColors.textMuted,
      ),
      onPressed: theme.toggleDarkMode,
    );
  }
}

class _BottomBarLogoutButton extends StatelessWidget {
  const _BottomBarLogoutButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Log out',
      icon: Icon(Icons.logout_rounded, color: AppColors.textMuted),
      onPressed: () => context.read<AuthService>().signOut(),
    );
  }
}

class _RailDarkModeToggle extends StatelessWidget {
  const _RailDarkModeToggle();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final isDark = theme.isDarkMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: AppColors.neutralBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: theme.toggleDarkMode,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Text(
                  isDark ? 'Light mode' : 'Dark mode',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
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
  final ValueChanged<int> onSelect;
  final VoidCallback onCollapse;

  const _SideRail({
    required this.index,
    required this.onSelect,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.glassSurfaceStrong,
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
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
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.heroGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Baliwag\nEduConnect',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: AppColors.textPrimary,
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
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          for (int i = 0; i < _destinations.length; i++)
            _RailItem(
              key: ValueKey('nav-${_destinations[i].label}'),
              spec: _destinations[i],
              selected: i == index,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          const _RailDarkModeToggle(),
          const _RailAccountCard(),
        ],
      ),
    );
  }
}

class _RailAccountCard extends StatelessWidget {
  const _RailAccountCard();

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
                color: AppColors.textMuted,
              ),
              onPressed: () => context.read<AuthService>().signOut(),
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
  final VoidCallback onTap;

  const _RailItem({
    super.key,
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? spec.selectedIcon : spec.icon,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Text(
                  spec.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
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
