import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/application.dart';

/// CRUD access to the `applications` Firestore collection.
class ApplicationRepository {
  final _col = FirebaseFirestore.instance.collection('applications');

  /// All applications (Admin Dashboard).
  Stream<List<ScholarshipApplication>> watchAll() {
    return _col.snapshots().map(
          (snap) =>
              snap.docs.map((d) => ScholarshipApplication.fromMap(d.id, d.data())).toList()
                ..sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted)),
        );
  }

  /// Only the signed-in student's own applications (Application Tracker).
  Stream<List<ScholarshipApplication>> watchForStudent(String studentUid) {
    return _col.where('studentUid', isEqualTo: studentUid).snapshots().map(
          (snap) =>
              snap.docs.map((d) => ScholarshipApplication.fromMap(d.id, d.data())).toList()
                ..sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted)),
        );
  }

  Future<String> create(ScholarshipApplication draft) async {
    final ref = _col.doc();
    await ref.set(draft.toMap());
    return ref.id;
  }

  Future<void> updateStatus(String id, ApplicationStatus status) {
    return _col.doc(id).update({'status': status.name});
  }

  Future<void> updateDocuments(String id, List<DocumentItem> documents) {
    return _col.doc(id).update({'documents': documents.map((d) => d.toMap()).toList()});
  }

  Future<void> addMessage(String id, AdminMessage message, List<AdminMessage> existing) {
    return _col.doc(id).update({
      'messages': [...existing, message].map((m) => m.toMap()).toList(),
    });
  }
}
