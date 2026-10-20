import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../config/secrets.dart';
import '../models/app_user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Wraps Firebase Auth + the `users/{uid}` Firestore profile doc (which
/// carries the app-level role used to route between the Student and Admin
/// shells, and which Firestore security rules also read for authorization).
class AuthService {
  final _auth = fb.FirebaseAuth.instance;
  final _users = FirebaseFirestore.instance.collection('users');

  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();

  fb.User? get currentFirebaseUser => _auth.currentUser;

  Stream<AppUser?> profileStream(String uid) {
    return _users.doc(uid).snapshots().map(
          (doc) => doc.exists ? AppUser.fromMap(uid, doc.data()!) : null,
        );
  }

  Future<AppUser?> fetchProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(uid, doc.data()!);
  }

  Future<void> registerStudent({
    required String email,
    required String password,
    required String fullName,
    required String studentNumber,
    required String course,
  }) async {
    final cred = await _create(email, password);
    final user = cred.user!;
    await user.updateDisplayName(fullName);
    await _saveProfile(
      user.uid,
      AppUser(
        uid: user.uid,
        email: email.trim(),
        fullName: fullName.trim(),
        role: UserRole.student,
        studentNumber: studentNumber.trim(),
        course: course.trim(),
      ),
    );
  }

  Future<void> registerAdmin({
    required String email,
    required String password,
    required String fullName,
    required String accessCode,
  }) async {
    if (accessCode.trim() != adminAccessCode) {
      throw AuthException('Invalid admin access code.');
    }
    final cred = await _create(email, password);
    final user = cred.user!;
    await user.updateDisplayName(fullName);
    await _saveProfile(
      user.uid,
      AppUser(
        uid: user.uid,
        email: email.trim(),
        fullName: fullName.trim(),
        role: UserRole.admin,
      ),
    );
  }

  Future<void> registerProvider({
    required String email,
    required String password,
    required String organizationName,
    required String contactName,
  }) async {
    final cred = await _create(email, password);
    final user = cred.user!;
    await user.updateDisplayName(contactName);
    await _saveProfile(
      user.uid,
      AppUser(
        uid: user.uid,
        email: email.trim(),
        fullName: contactName.trim(),
        role: UserRole.provider,
        organizationName: organizationName.trim(),
        providerStatus: ProviderStatus.pending,
      ),
    );
  }

  Future<fb.UserCredential> _create(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  /// Writes the just-created user's `users/{uid}` profile doc, surfacing a
  /// specific [AuthException] on failure (e.g. a Firestore rules rejection)
  /// instead of letting a bare [FirebaseException] fall through to
  /// RegisterScreen's generic "Something went wrong" catch-all, which gave
  /// no clue *why* — the Auth account exists at this point regardless of
  /// whether this write succeeds (see AuthGate's `_OrphanedSession`, which
  /// handles exactly that half-finished state on next sign-in).
  Future<void> _saveProfile(String uid, AppUser profile) async {
    try {
      await _users.doc(uid).set(profile.toMap());
    } on FirebaseException catch (e) {
      throw AuthException(
        'Account created, but saving your profile failed '
        '(${e.code}: ${e.message}). Please try signing in — if that also '
        "fails, contact the app's admin.",
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _friendlyMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
