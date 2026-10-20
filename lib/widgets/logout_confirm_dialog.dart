import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme_context.dart';

/// Shows a themed confirmation dialog before actually signing the user
/// out — logging out is easy to trigger by accident (a misclick on a
/// compact icon button, e.g. in the mini sidebar or a settings row), and
/// there's no undo once it happens. Shared by every logout entry point
/// (student/admin side rails, mini rails, Profile/Admin Settings) so the
/// confirmation looks and behaves identically everywhere.
Future<void> confirmSignOut(BuildContext context) async {
  final authService = context.read<AuthService>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: dialogContext.scheme.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: dialogContext.scheme.error,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Log out?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: dialogContext.appColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You'll need to sign in again to continue.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: dialogContext.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: dialogContext.scheme.error,
                    ),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Log Out'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (confirmed == true) {
    await authService.signOut();
  }
}
