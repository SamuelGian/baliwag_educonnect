import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// Read/update access to `users/{uid}` docs beyond a single signed-in
/// profile (see AuthService.profileStream for that) — specifically, the
/// Admin Dashboard's "Providers" tab, which needs to see every provider
/// account regardless of whose session is open.
class UserRepository {
  final _col = FirebaseFirestore.instance.collection('users');

  /// All provider accounts (Admin Dashboard's "Providers" tab), newest
  /// first isn't tracked (no createdAt field yet) so this just sorts by
  /// organization name for a stable, scannable list.
  Stream<List<AppUser>> watchProviders() {
    return _col.where('role', isEqualTo: UserRole.provider.name).snapshots().map(
          (snap) => snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => a.organizationName.compareTo(b.organizationName)),
        );
  }

  Future<void> setProviderStatus(String uid, ProviderStatus status) {
    return _col.doc(uid).update({'providerStatus': status.name});
  }
}
