import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/scholarship.dart';
import '../models/application.dart';
import '../models/announcement.dart';
import '../services/document_validation_service.dart';
import '../services/ocr_service.dart';
import '../services/supabase_storage_service.dart';
import '../services/text_match.dart';
import 'scholarship_repository.dart';
import 'application_repository.dart';
import 'announcement_repository.dart';
import 'document_upload_limits.dart';

/// Why a student currently cannot (re-)apply to a given scholarship, or
/// null if they can. Carries both a short label (for a disabled button) and
/// a longer reason (for an error message if the block is ever hit anyway —
/// e.g. a stale draft opened before a deadline/slot state changed).
class ApplyBlock {
  final String label;
  final String reason;
  const ApplyBlock(this.label, this.reason);
}

/// Firestore-backed app state, scoped to the signed-in user. Subscribes to
/// live Firestore streams so Create/Update/Delete performed anywhere (by an
/// admin, or by the OCR verification pipeline) reflect instantly across
/// every screen without manual refreshing.
class AppState extends ChangeNotifier {
  AppUser user;

  final _scholarshipRepo = ScholarshipRepository();
  final _applicationRepo = ApplicationRepository();
  final _announcementRepo = AnnouncementRepository();
  final _storageService = SupabaseStorageService();
  final _ocrService = OcrService();
  final _validationService = DocumentValidationService();

  late final StreamSubscription _scholarshipsSub;
  late final StreamSubscription _announcementsSub;
  late final StreamSubscription _applicationsSub;

  AppState({required this.user}) {
    // Students and Admin browse/manage every program; a Provider only ever
    // sees their own (see ScholarshipRepository.watchForProvider).
    final scholarshipStream = user.role == UserRole.provider
        ? _scholarshipRepo.watchForProvider(user.uid)
        : _scholarshipRepo.watchAll();
    _scholarshipsSub = scholarshipStream.listen((data) {
      scholarships = data;
      notifyListeners();
    });
    _announcementsSub = _announcementRepo.watchAll().listen((data) {
      announcements = data;
      notifyListeners();
    });
    final applicationStream = switch (user.role) {
      UserRole.admin => _applicationRepo.watchAll(),
      UserRole.provider => _applicationRepo.watchForProvider(user.uid),
      UserRole.student => _applicationRepo.watchForStudent(user.uid),
    };
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
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update(updated.toMap());
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

  int get approvedCount => myApplications
      .where((a) => a.status == ApplicationStatus.approved)
      .length;

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

  /// Null if [user] may apply (or re-apply) to [scholarship] right now;
  /// otherwise explains why the Apply button should be disabled.
  ///
  /// A REJECTED application never blocks — rejection means "fix the issue
  /// and try again", not "permanently barred". Every other status
  /// (submitted, document verification, under review, approved) does
  /// block: there's no legitimate reason for the same student to have two
  /// simultaneous applications open for the same program. Falls back to
  /// matching on [Scholarship.title] for applications created before
  /// [ScholarshipApplication.scholarshipId] existed.
  ApplyBlock? blockReasonFor(Scholarship scholarship) {
    final existing = applications.where(
      (a) =>
          a.studentUid == user.uid &&
          a.status != ApplicationStatus.rejected &&
          (a.scholarshipId.isNotEmpty
              ? a.scholarshipId == scholarship.id
              : a.scholarshipTitle == scholarship.title),
    );
    if (existing.isNotEmpty) {
      final status = existing.first.status;
      final isApproved = status == ApplicationStatus.approved;
      return ApplyBlock(
        isApproved ? 'Already Approved' : 'Already Applied',
        isApproved
            ? 'You already have an approved application for this scholarship.'
            : 'You already have an application for this scholarship (status: ${status.label}).',
      );
    }
    // Everything else — deadline, slots, and a manual admin close — is
    // decided by the one shared function the admin's Manage Scholarships
    // list also uses, so the two sides can never disagree about whether a
    // program is still open.
    final status = getScholarshipStatus(scholarship);
    if (!status.acceptsApplications) {
      final reason = switch (status) {
        ScholarshipStatus.deadlinePassed =>
          'The application deadline for this scholarship has already passed.',
        ScholarshipStatus.slotsFull =>
          'All slots for this scholarship have already been filled.',
        ScholarshipStatus.manuallyClosed =>
          'This scholarship is no longer accepting applications.',
        _ => 'This scholarship is not currently accepting applications.',
      };
      return ApplyBlock(status.label, reason);
    }
    return null;
  }

  /// Create: submits a new application, then kicks off async document
  /// upload + OCR verification in the background. Re-checks
  /// [blockReasonFor] right before writing — the UI already disables the
  /// Apply button for a blocked scholarship, but a draft can sit open for a
  /// while (mid-form-filling) during which the deadline could pass or the
  /// last slot could fill, so this is the one check that's actually
  /// reachable no matter which screen got the student here.
  Future<void> submitApplication({
    required Scholarship scholarship,
    required String applicantFullName,
    required List<DocumentItem> documents,
  }) async {
    final block = blockReasonFor(scholarship);
    if (block != null) {
      throw StateError(block.reason);
    }
    final draft = ScholarshipApplication(
      id: '',
      scholarshipId: scholarship.id,
      scholarshipTitle: scholarship.title,
      providerUid: scholarship.providerUid,
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
    unawaited(_verifyDocuments(id, documents));
  }

  /// Runs each document through OCR directly from its in-memory bytes and
  /// fuzzy-matches the recognized text against the *currently signed-in
  /// student's own profile name* (see [_processDocument] — always
  /// `user.fullName`, never the applicant-typed form field, so a student
  /// can't accidentally or deliberately have their documents checked
  /// against the wrong name) — persisting a live status (verifying /
  /// matched / needs manual review) to Firestore after each document so the
  /// Tracker and Admin Dashboard update in place. Also saves the file
  /// itself (see [_processDocument]) so an admin can actually open it, not
  /// just see the OCR verdict.
  Future<void> _verifyDocuments(
    String applicationId,
    List<DocumentItem> documents,
  ) async {
    for (final doc in documents) {
      if (!doc.uploaded || doc.bytes == null) continue;
      doc.matchStatus = DocMatchStatus.verifying;
      await _applicationRepo.updateDocuments(applicationId, documents);

      await _processDocument(applicationId: applicationId, doc: doc);

      await _applicationRepo.updateDocuments(applicationId, documents);
    }

    await _applicationRepo.updateStatus(
      applicationId,
      ApplicationStatus.documentVerification,
    );
    await Future.delayed(const Duration(milliseconds: 500));
    await _applicationRepo.updateStatus(
      applicationId,
      ApplicationStatus.underReview,
    );
  }

  /// True for requirements like "Valid ID of Parent/Guardian" — these
  /// legitimately carry a *different* person's name than the applicant's own
  /// account, so auto-matching them against `user.fullName` would be
  /// checking the wrong name entirely (and could produce a misleading
  /// "Matched"). These are always routed to manual review instead of run
  /// through name-matching.
  bool _isGuardianDocument(String name) {
    final lower = name.toLowerCase();
    return lower.contains('guardian') || lower.contains('parent');
  }

  /// Saves the uploaded file for admin viewing, then either skips
  /// name-matching (see [_isGuardianDocument]) or runs it against the
  /// *currently signed-in* student's own profile name (`user.fullName` —
  /// this `AppState` is always scoped to whichever account is logged in, so
  /// there's nothing to parameterize: switching accounts naturally switches
  /// whose name gets checked). Mutates [doc] in place; callers are
  /// responsible for persisting it afterward.
  Future<void> _processDocument({
    required String applicationId,
    required DocumentItem doc,
  }) async {
    final bytes = doc.bytes;
    if (bytes == null) return;

    if (bytes.length > kMaxDocumentFileBytes) {
      doc.matchStatus = DocMatchStatus.mismatch;
      doc.matchNote =
          'File is too large to store for review (max ${(kMaxDocumentFileBytes / (1024 * 1024)).round()}MB). Please upload a smaller file.';
      return;
    }

    String? fileSaveError;
    try {
      final path = objectPathFor(
        applicationId,
        doc.name,
        doc.fileName ?? 'document',
      );
      await _storageService.upload(
        path: path,
        bytes: bytes,
        mimeType: mimeTypeForFileName(doc.fileName ?? 'document'),
      );
      doc.storagePath = path;
    } catch (e) {
      // Not fatal to OCR verification below, but must NOT be swallowed
      // silently — this is exactly the kind of failure (e.g. Supabase
      // Storage policies not yet applied to the bucket) that otherwise
      // shows up only as an unexplained "No file was stored" in the
      // admin's viewer, with no clue why.
      fileSaveError = e.toString();
      debugPrint('Could not save document file for admin review: $e');
    }

    if (_isGuardianDocument(doc.name)) {
      doc.matchStatus = DocMatchStatus.mismatch;
      doc.matchNote =
          "This document belongs to the applicant's parent/guardian, so it can't "
          "be auto-checked against the applicant's own name — flagged for manual review.";
      if (fileSaveError != null) {
        doc.matchNote =
            '${doc.matchNote} (File could not be saved for viewing: $fileSaveError)';
      }
      return;
    }

    try {
      // Belt-and-suspenders timeout on top of OcrService's own internal
      // ones: whatever the cause, a document must never sit on "Verifying
      // with OCR…" forever with no way out.
      final ocr = await _ocrService
          .extractText(bytes: bytes, fileName: doc.fileName ?? 'document')
          .timeout(const Duration(seconds: 45));

      // Two independent checks, both must pass for an automatic "Matched":
      // does the signed-in student's own profile name appear on it, AND
      // does the content actually look like the kind of document it's
      // supposed to be (not just "some text was extracted" — a blank or
      // noisy scan used to sail through that check as long as a stray OCR
      // artifact happened to fuzzy-match a name fragment).
      final nameResult = matchNameAgainstText(user.fullName, ocr.text);
      final contentResult = _validationService.validate(
        documentName: doc.name,
        ocr: ocr,
      );

      doc.matchStatus = (nameResult.nameMatched && contentResult.valid)
          ? DocMatchStatus.matched
          : DocMatchStatus.mismatch;

      final detectedName = nameResult.extractedName.isNotEmpty
          ? nameResult.extractedName
          : '(not clearly detected)';
      final nameNote =
          'Name on document: $detectedName | '
          'Name on profile: ${nameResult.expectedName} | '
          'Match: ${(nameResult.matchConfidence * 100).round()}%';
      doc.matchNote = '$nameNote. ${contentResult.reason}';
    } on OcrException catch (e) {
      doc.matchStatus = DocMatchStatus.mismatch;
      doc.matchNote = e.message;
    } on TimeoutException {
      doc.matchStatus = DocMatchStatus.mismatch;
      doc.matchNote = 'OCR verification timed out. Flagged for manual review.';
    } catch (_) {
      doc.matchStatus = DocMatchStatus.mismatch;
      doc.matchNote =
          'Could not verify this document automatically. Flagged for manual review.';
    }
    if (fileSaveError != null) {
      doc.matchNote =
          '${doc.matchNote} (File could not be saved for viewing: $fileSaveError)';
    }
  }

  /// Updates an application's status and keeps [Scholarship.slotsFilled] in
  /// sync — a slot is claimed the moment an application becomes Approved,
  /// and released if it's ever moved away from Approved again (e.g. an
  /// admin correcting a mistaken approval). Previously `slotsFilled` was
  /// never touched by anything — the numbers shown across the dashboard
  /// were just whatever the scholarship was created/seeded with.
  Future<void> updateApplicationStatus(
    String id,
    ApplicationStatus status,
  ) async {
    final app = applications.firstWhere((a) => a.id == id);
    final wasApproved = app.status == ApplicationStatus.approved;
    await _applicationRepo.updateStatus(id, status);
    final nowApproved = status == ApplicationStatus.approved;
    if (wasApproved == nowApproved || app.scholarshipId.isEmpty) return;
    await _scholarshipRepo.adjustSlotsFilled(
      app.scholarshipId,
      nowApproved ? 1 : -1,
    );
  }

  Future<void> sendAdminMessage(String applicationId, String message) {
    final app = applications.firstWhere((a) => a.id == applicationId);
    return _applicationRepo.addMessage(
      applicationId,
      AdminMessage(
        sender: user.fullName,
        message: message,
        date: DateTime.now(),
      ),
      app.messages,
    );
  }

  /// Admin: flags a single document as needing a fresh upload, with a note
  /// explaining what's wrong. Shown to the student in the Application
  /// Tracker alongside a "Re-upload Document" action.
  Future<void> requestDocumentResubmission({
    required String applicationId,
    required String documentName,
    required String feedback,
  }) {
    final app = applications.firstWhere((a) => a.id == applicationId);
    final doc = app.documents.firstWhere((d) => d.name == documentName);
    doc.matchStatus = DocMatchStatus.needsResubmission;
    doc.adminFeedback = feedback;
    return _applicationRepo.updateDocuments(applicationId, app.documents);
  }

  /// Student: uploads a replacement file for a single document that was
  /// flagged by an admin, then re-runs the same OCR verification pipeline
  /// as the original submission for just that document.
  Future<void> resubmitDocument({
    required String applicationId,
    required String documentName,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final app = applications.firstWhere((a) => a.id == applicationId);
    final doc = app.documents.firstWhere((d) => d.name == documentName);
    doc.uploaded = true;
    doc.fileName = fileName;
    doc.bytes = bytes;
    doc.adminFeedback = null;
    doc.matchStatus = DocMatchStatus.verifying;
    await _applicationRepo.updateDocuments(applicationId, app.documents);

    await _processDocument(applicationId: applicationId, doc: doc);

    await _applicationRepo.updateDocuments(applicationId, app.documents);
  }

  // --- Scholarship CRUD (Admin or Provider: "Manage Scholarships") --------

  /// A Provider always owns what they create — stamped here, not left to
  /// the form, so a provider can never create a scholarship under another
  /// org's name or leave it ownerless. Admin keeps using its own freeform
  /// `provider` text field untouched.
  Future<void> createScholarship(Scholarship draft) {
    if (user.role != UserRole.provider) return _scholarshipRepo.create(draft);
    return _scholarshipRepo.create(
      draft.copyWith(provider: user.organizationName, providerUid: user.uid),
    );
  }
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

  Future<void> createAnnouncement(Announcement draft) =>
      _announcementRepo.create(draft);
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
