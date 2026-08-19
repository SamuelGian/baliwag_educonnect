import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/scholarship.dart';
import '../models/application.dart';
import '../models/announcement.dart';
import '../services/ocr_service.dart';
import '../services/text_match.dart';
import 'scholarship_repository.dart';
import 'application_repository.dart';
import 'announcement_repository.dart';

/// Firestore-backed app state, scoped to the signed-in user. Subscribes to
/// live Firestore streams so Create/Update/Delete performed anywhere (by an
/// admin, or by the OCR verification pipeline) reflect instantly across
/// every screen without manual refreshing.
class AppState extends ChangeNotifier {
  AppUser user;

  final _scholarshipRepo = ScholarshipRepository();
  final _applicationRepo = ApplicationRepository();
  final _announcementRepo = AnnouncementRepository();
  final _ocrService = OcrService();

  late final StreamSubscription _scholarshipsSub;
  late final StreamSubscription _announcementsSub;
  late final StreamSubscription _applicationsSub;

  AppState({required this.user}) {
    _scholarshipsSub = _scholarshipRepo.watchAll().listen((data) {
      scholarships = data;
      notifyListeners();
    });
    _announcementsSub = _announcementRepo.watchAll().listen((data) {
      announcements = data;
      notifyListeners();
    });
    final applicationStream = user.role == UserRole.admin
        ? _applicationRepo.watchAll()
        : _applicationRepo.watchForStudent(user.uid);
    _applicationsSub = applicationStream.listen((data) {
      applications = data;
      notifyListeners();
    });
  }

  String get studentName => user.fullName;
  String get studentNumber => user.studentNumber;
  String get course => user.course;

  /// Persists edits made in Profile Settings and refreshes the in-memory
  /// copy so the rest of the app (and the Apply form's auto-fill) sees the
  /// new values immediately, without needing to log out and back in.
  Future<void> updateProfile(AppUser updated) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updated.toMap());
    user = updated;
    notifyListeners();
  }

  List<Scholarship> scholarships = [];
  List<Announcement> announcements = [];
  List<ScholarshipApplication> applications = [];

  /// Already scoped to the signed-in student by the Firestore query above.
  List<ScholarshipApplication> get myApplications => applications;

  int get pendingCount => myApplications
      .where(
        (a) =>
            a.status == ApplicationStatus.submitted ||
            a.status == ApplicationStatus.documentVerification ||
            a.status == ApplicationStatus.underReview,
      )
      .length;

  int get approvedCount =>
      myApplications.where((a) => a.status == ApplicationStatus.approved).length;

  int countByStatus(ApplicationStatus status) =>
      applications.where((a) => a.status == status).length;

  double get totalDisbursed {
    double total = 0;
    for (final a in applications) {
      if (a.status != ApplicationStatus.approved) continue;
      final sch = scholarships.firstWhere(
        (s) => s.title == a.scholarshipTitle,
        orElse: () => scholarships.isEmpty
            ? Scholarship(
                id: '',
                title: '',
                provider: '',
                description: '',
                amount: 0,
                totalSlots: 0,
                slotsFilled: 0,
                deadline: DateTime.now(),
                category: ScholarshipCategory.academic,
                requirements: const [],
              )
            : scholarships.first,
      );
      total += sch.amount;
    }
    return total;
  }

  /// Create: submits a new application, then kicks off async document
  /// upload + OCR verification in the background.
  Future<void> submitApplication({
    required Scholarship scholarship,
    required String applicantFullName,
    required List<DocumentItem> documents,
  }) async {
    final draft = ScholarshipApplication(
      id: '',
      scholarshipTitle: scholarship.title,
      studentUid: user.uid,
      studentName: user.fullName,
      studentNumber: user.studentNumber,
      dateSubmitted: DateTime.now(),
      status: ApplicationStatus.submitted,
      documents: documents,
      messages: const [],
      applicantFullName: applicantFullName,
    );
    final id = await _applicationRepo.create(draft);
    unawaited(_verifyDocuments(id, documents, applicantFullName));
  }

  /// Runs each document through OCR directly from its in-memory bytes (no
  /// Firebase Storage involved — this project runs on the Spark/free plan,
  /// which doesn't include Storage) and fuzzy-matches the recognized text
  /// against the applicant's typed name — persisting a live status
  /// (verifying / matched / needs manual review) to Firestore after each
  /// document so the Tracker and Admin Dashboard update in place.
  Future<void> _verifyDocuments(
    String applicationId,
    List<DocumentItem> documents,
    String applicantFullName,
  ) async {
    for (final doc in documents) {
      if (!doc.uploaded || doc.bytes == null) continue;
      doc.matchStatus = DocMatchStatus.verifying;
      await _applicationRepo.updateDocuments(applicationId, documents);

      try {
        final text = await _ocrService.extractText(
          bytes: doc.bytes!,
          fileName: doc.fileName ?? 'document',
        );
        final result = matchNameAgainstText(applicantFullName, text);
        doc.matchStatus =
            result.matched ? DocMatchStatus.matched : DocMatchStatus.mismatch;
        doc.matchNote = result.matched
            ? 'Name matched (${(result.score * 100).round()}% of name tokens found).'
            : 'Name on document does not clearly match "$applicantFullName".';
      } on OcrException catch (e) {
        doc.matchStatus = DocMatchStatus.mismatch;
        doc.matchNote = e.message;
      } catch (_) {
        doc.matchStatus = DocMatchStatus.mismatch;
        doc.matchNote = 'Could not verify this document automatically. Flagged for manual review.';
      }
      await _applicationRepo.updateDocuments(applicationId, documents);
    }

    await _applicationRepo.updateStatus(applicationId, ApplicationStatus.documentVerification);
    await Future.delayed(const Duration(milliseconds: 500));
    await _applicationRepo.updateStatus(applicationId, ApplicationStatus.underReview);
  }

  Future<void> updateApplicationStatus(String id, ApplicationStatus status) {
    return _applicationRepo.updateStatus(id, status);
  }

  Future<void> sendAdminMessage(String applicationId, String message) {
    final app = applications.firstWhere((a) => a.id == applicationId);
    return _applicationRepo.addMessage(
      applicationId,
      AdminMessage(sender: user.fullName, message: message, date: DateTime.now()),
      app.messages,
    );
  }

  // --- Scholarship CRUD (Admin: "Manage Scholarships") ---------------------

  Future<void> createScholarship(Scholarship draft) => _scholarshipRepo.create(draft);
  Future<void> updateScholarship(Scholarship scholarship) =>
      _scholarshipRepo.update(scholarship);
  Future<void> deleteScholarship(String id) => _scholarshipRepo.delete(id);

  /// Populates a handful of realistic starter programs via the same
  /// [createScholarship] path the "Add Scholarship" form uses, so there's
  /// something to apply to right away without hand-typing five forms.
  Future<void> seedSampleScholarships() async {
    final now = DateTime.now();
    final samples = [
      Scholarship(
        id: '',
        title: 'Baliwag Merit Scholarship',
        provider: 'Municipal Government of Baliwag',
        description:
            'Full tuition support for academically outstanding residents of Baliwag pursuing a college degree.',
        amount: 20000,
        totalSlots: 60,
        slotsFilled: 41,
        deadline: now.add(const Duration(days: 12)),
        category: ScholarshipCategory.academic,
        requirements: const [
          'Form 137 / Certificate of Grades',
          'Certificate of Enrollment',
          'Barangay Certificate of Residency',
          'Income Tax Return / Certificate of Indigency',
        ],
      ),
      Scholarship(
        id: '',
        title: 'Educational Assistance Program',
        provider: 'City Scholarship Office',
        description:
            'Financial aid for students from low-income households to cover tuition and miscellaneous fees.',
        amount: 12000,
        totalSlots: 100,
        slotsFilled: 87,
        deadline: now.add(const Duration(days: 5)),
        category: ScholarshipCategory.financial,
        requirements: const [
          'Certificate of Indigency',
          'Certificate of Enrollment',
          'Valid ID of Parent/Guardian',
        ],
      ),
      Scholarship(
        id: '',
        title: 'Arts & Culture Grant',
        provider: 'Baliwag Cultural Affairs Office',
        description:
            'Support for students actively engaged in visual arts, theater, music, or literary arts.',
        amount: 8000,
        totalSlots: 20,
        slotsFilled: 6,
        deadline: now.add(const Duration(days: 25)),
        category: ScholarshipCategory.arts,
        requirements: const [
          'Portfolio of Work',
          'Certificate of Enrollment',
          'Recommendation Letter',
        ],
      ),
      Scholarship(
        id: '',
        title: 'Student-Athlete Support Grant',
        provider: 'Sports Development Council',
        description:
            'Assistance for varsity athletes representing the municipality in regional or national events.',
        amount: 10000,
        totalSlots: 30,
        slotsFilled: 30,
        deadline: now.add(const Duration(days: 2)),
        category: ScholarshipCategory.sports,
        requirements: const [
          'Certificate from Sports Coordinator',
          'Certificate of Enrollment',
        ],
      ),
      Scholarship(
        id: '',
        title: 'TechVoc Skills Scholarship',
        provider: 'TESDA Provincial Office',
        description:
            'Grant for students enrolled in technical-vocational programs aligned with local industry needs.',
        amount: 9000,
        totalSlots: 40,
        slotsFilled: 18,
        deadline: now.add(const Duration(days: 30)),
        category: ScholarshipCategory.technical,
        requirements: const [
          'Certificate of Enrollment',
          'Certificate of Good Moral Character',
        ],
      ),
    ];
    for (final s in samples) {
      await _scholarshipRepo.create(s);
    }
  }

  // --- Announcement CRUD (Admin) -------------------------------------------

  Future<void> createAnnouncement(Announcement draft) => _announcementRepo.create(draft);
  Future<void> updateAnnouncement(Announcement announcement) =>
      _announcementRepo.update(announcement);
  Future<void> deleteAnnouncement(String id) => _announcementRepo.delete(id);

  @override
  void dispose() {
    _scholarshipsSub.cancel();
    _announcementsSub.cancel();
    _applicationsSub.cancel();
    super.dispose();
  }
}
