import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/app_user.dart';
import '../screens/auth/login_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'admin_shell.dart';
import 'app_shell.dart';

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
            return ChangeNotifierProvider<AppState>(
              key: ValueKey(profile.uid),
              create: (_) => AppState(user: profile),
              child: profile.role == UserRole.admin
                  ? const AdminShell()
                  : const AppShell(),
            );
          },
        );
      },
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
    context.read<AuthService>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return const _SplashLoader(
      message: "Couldn't load your account profile. Signing you out…",
    );
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
                  colors: AppColors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
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
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
