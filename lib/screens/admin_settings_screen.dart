import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/app_user.dart';
import '../theme/app_theme_context.dart';
import '../theme/breakpoints.dart';
import '../widgets/account_settings_rows.dart';
import '../widgets/glass_panel.dart';

/// Admin's (and Provider's — see ProviderShell) counterpart to the
/// student's Profile Settings screen — no editable applicant fields (an
/// admin/provider account has none), just an identity header and the same
/// shared Account controls (dark mode, log out) so every non-student role
/// reaches them the same way instead of the mobile nav bar carrying
/// role-specific icons.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= kDesktopBreakpoint;
    final isProvider = app.user.role == UserRole.provider;
    final name = isProvider && app.user.organizationName.isNotEmpty
        ? app.user.organizationName
        : app.user.fullName;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join()
        .toUpperCase();

    return SafeArea(
      child: SingleChildScrollView(
        // Extra bottom clearance on narrow screens only, so the Account
        // section (dark mode / Log Out) can scroll clear of the floating
        // GlassNavBar instead of ending up hidden under it.
        padding: EdgeInsets.fromLTRB(
          wide ? 32 : 18,
          24,
          wide ? 32 : 18,
          wide ? 24 : 120,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your account details and app preferences.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),

                // --- Identity header -------------------------------------
                GlassPanel(
                  padding: const EdgeInsets.all(22),
                  strong: true,
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: context.appColors.heroGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.scheme.primary.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials.isEmpty ? '?' : initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty
                                  ? (isProvider ? 'Provider' : 'Admin')
                                  : name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              app.user.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: context.scheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isProvider ? 'PROVIDER' : 'ADMIN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: context.scheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // --- Account: dark mode + sign out ------------------------
                GlassPanel(
                  padding: const EdgeInsets.all(22),
                  strong: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            size: 16,
                            color: context.scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Account',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.appColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const DarkModeRow(),
                      const SizedBox(height: 10),
                      Divider(color: context.appColors.border),
                      const SizedBox(height: 10),
                      const LogoutRow(),
                    ],
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
