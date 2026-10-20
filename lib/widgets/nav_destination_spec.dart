import 'package:flutter/material.dart';

/// One destination in a bottom nav bar or a wide-screen side rail. Shared
/// between the Student and Admin shells so both narrow- and wide-screen
/// navigation stay structurally identical.
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
