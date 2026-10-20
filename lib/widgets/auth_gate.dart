import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/app_user.dart';
import '../screens/auth/login_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme_context.dart';
import 'admin_shell.dart';
import 'app_shell.dart';
import 'provider_shell.dart';

/// Routes between the Login screen, the Student shell, and the Admin shell
/// based on live Firebase Auth state + the signed-in user's Firestore role.
/// A fresh [AppState] (with its own Firestore subscriptions) is created for
/// each signed-in session and torn down automatically on logout.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return StreamBuilder<fb.User?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashLoader();
        }
        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return const LoginScreen();
        }
        return StreamBuilder<AppUser?>(
          stream: auth.profileStream(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashLoader();
            }
            final profile = profileSnapshot.data;
            if (profile == null) {
              // Signed in with Firebase Auth but no matching users/{uid}
              // Firestore doc (e.g. registration's profile write failed
              // partway, or the doc was deleted). There's nothing for this
              // session to route to — sign out and drop back to Login
              // instead of hanging on a spinner forever.
              return _OrphanedSession(firebaseUid: firebaseUser.uid);
            }
            if (profile.role == UserRole.provider &&
                profile.providerStatus != ProviderStatus.approved) {
              return _ProviderGateScreen(profile: profile);
            }
            return ChangeNotifierProvider<AppState>(
              key: ValueKey(profile.uid),
              create: (_) => AppState(user: profile),
              child: switch (profile.role) {
                UserRole.admin => const AdminShell(),
                UserRole.provider => const ProviderShell(),
                UserRole.student => const AppShell(),
              },
            );
          },
        );
      },
    );
  }
}

/// Shown instead of [ProviderShell] while a Provider account is awaiting
/// (or was denied) Admin approval — see the "Providers" tab on the Admin
/// Dashboard. A provider's AppState/Firestore subscriptions never start
/// until they're actually approved, so there's nothing for this screen to
/// watch beyond the auth state it already has via [AuthGate]'s own
/// `profileStream`, which will rebuild this away automatically the moment
/// Admin approves.
class _ProviderGateScreen extends StatelessWidget {
  final AppUser profile;

  const _ProviderGateScreen({required this.profile});

  @override
  Widget build(BuildContext context) {
    final rejected = profile.providerStatus == ProviderStatus.rejected;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                rejected ? Icons.block_rounded : Icons.hourglass_top_rounded,
                size: 48,
                color: rejected
                    ? context.scheme.error
                    : context.appColors.textSecondary,
              ),
              const SizedBox(height: 20),
              Text(
                rejected ? 'Application not approved' : 'Waiting for approval',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                rejected
                    ? 'Your "${profile.organizationName}" provider account was '
                        'not approved. Contact the Baliwag EduConnect admin for '
                        'more information.'
                    : 'Your "${profile.organizationName}" provider account is '
                        'waiting for admin approval. You\'ll be able to sign in '
                        'once it\'s approved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.read<AuthService>().signOut(),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrphanedSession extends StatefulWidget {
  final String firebaseUid;

  const _OrphanedSession({required this.firebaseUid});

  @override
  State<_OrphanedSession> createState() => _OrphanedSessionState();
}

class _OrphanedSessionState extends State<_OrphanedSession> {
  @override
  void initState() {
    super.initState();
    _delayedSignOut();
  }

  /// A brand-new account's `users/{uid}` doc can take a moment to land:
  /// Firebase Auth's sign-in event (which is what gets this whole
  /// StreamBuilder tree to rebuild in the first place) fires as soon as
  /// the account is created, but registration only writes the Firestore
  /// profile doc *after* that — so there's a real window where AuthGate
  /// sees "signed in, no profile yet" and lands here before that write has
  /// actually landed. Previously this signed out immediately, which could
  /// lose that race and boot a freshly-registered user straight back to
  /// Login. Give it a few seconds instead: if the doc shows up in that
  /// window, AuthGate's own `profileStream` StreamBuilder swaps this
  /// screen away on its own (same as any other profile change) and this
  /// widget gets disposed before the timer below ever fires — only sign
  /// out if still mounted after the grace period, i.e. genuinely orphaned.
  Future<void> _delayedSignOut() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    await context.read<AuthService>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return const _SplashLoader(message: 'Setting up your account…');
  }
}

class _SplashLoader extends StatelessWidget {
  final String? message;

  const _SplashLoader({this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: context.appColors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(strokeWidth: 2.4),
            if (message != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
