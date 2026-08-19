import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement.dart';

/// CRUD access to the `announcements` Firestore collection. Admins post and
/// manage announcements here; students read them on the dashboard.
class AnnouncementRepository {
  final _col = FirebaseFirestore.instance.collection('announcements');

  Stream<List<Announcement>> watchAll() {
    return _col.snapshots().map(
          (snap) => snap.docs.map((d) => Announcement.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => b.date.compareTo(a.date)),
        );
  }

  Future<String> create(Announcement draft) async {
    final ref = _col.doc();
    await ref.set(draft.toMap());
    return ref.id;
  }

  Future<void> update(Announcement announcement) {
    return _col.doc(announcement.id).update(announcement.toMap());
  }

  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }
}
