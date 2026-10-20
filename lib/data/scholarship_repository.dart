import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/scholarship.dart';

/// CRUD access to the `scholarships` Firestore collection. This is the
/// primary Create/Read/Update/Delete entity for the app: administrators
/// manage scholarship programs here, students only read from it.
class ScholarshipRepository {
  final _col = FirebaseFirestore.instance.collection('scholarships');

  /// Read (live): every screen showing scholarships subscribes to this
  /// stream so Create/Update/Delete performed by an admin show up instantly.
  Stream<List<Scholarship>> watchAll() {
    return _col.snapshots().map(
          (snap) => snap.docs.map((d) => Scholarship.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => a.deadline.compareTo(b.deadline)),
        );
  }

  /// Only the signed-in provider's own programs (Provider dashboard).
  Stream<List<Scholarship>> watchForProvider(String providerUid) {
    return _col.where('providerUid', isEqualTo: providerUid).snapshots().map(
          (snap) => snap.docs.map((d) => Scholarship.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => a.deadline.compareTo(b.deadline)),
        );
  }

  /// Create.
  Future<String> create(Scholarship draft) async {
    final ref = _col.doc();
    await ref.set(draft.toMap());
    return ref.id;
  }

  /// Update.
  Future<void> update(Scholarship scholarship) {
    return _col.doc(scholarship.id).update(scholarship.toMap());
  }

  /// Delete.
  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }

  Future<void> adjustSlotsFilled(String id, int delta) {
    return _col.doc(id).update({'slotsFilled': FieldValue.increment(delta)});
  }
}
