import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../theme/app_colors.dart';
import '../screens/student_dashboard_screen.dart';
import '../screens/scholarship_application_screen.dart';
import '../screens/application_tracker_screen.dart';
import '../screens/admin_dashboard_screen.dart';

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
    label: 'Admin',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings_rounded,
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
    AdminDashboardScreen(),
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
        color: AppColors.surface,
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
    final app = context.watch<AppState>();
    return IconButton(
      tooltip: app.isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(
        app.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: AppColors.textMuted,
      ),
      onPressed: () => context.read<AppState>().toggleDarkMode(),
    );
  }
}

class _RailDarkModeToggle extends StatelessWidget {
  const _RailDarkModeToggle();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = app.isDarkMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: AppColors.neutralBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.read<AppState>().toggleDarkMode(),
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
      color: AppColors.surface,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.neutralBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    child: const Text(
                      'SB',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Samuel Batac',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
        color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
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
                    color: selected ? AppColors.primary : AppColors.textSecondary,
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
