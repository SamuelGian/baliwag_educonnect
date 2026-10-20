import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme_context.dart';
import '../theme/theme_controller.dart';
import 'logout_confirm_dialog.dart';

/// Shared "Account" section rows — used by both the student's Profile
/// Settings screen and the admin's Settings screen, so logging out and
/// toggling dark mode look and behave identically for both roles.
class DarkModeRow extends StatelessWidget {
  const DarkModeRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return Row(
      children: [
        Icon(
          theme.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          size: 18,
          color: context.appColors.textSecondary,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Dark mode',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
          ),
        ),
        Switch(
          value: theme.isDarkMode,
          onChanged: (_) => theme.toggleDarkMode(),
        ),
      ],
    );
  }
}

class LogoutRow extends StatelessWidget {
  const LogoutRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.logout_rounded, size: 18, color: context.scheme.error),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Log out of this account',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: context.scheme.error,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () => confirmSignOut(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.scheme.error,
            side: BorderSide(color: context.scheme.error),
          ),
          child: const Text('Log Out'),
        ),
      ],
    );
  }
}
