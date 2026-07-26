import 'dart:async';
import 'package:flutter/material.dart';
import '../models/scholarship.dart';
import '../models/application.dart';
import '../models/announcement.dart';
import '../services/ocr_service.dart';
import '../services/text_match.dart';

/// In-memory app state with mock data. Simulates backend behavior
/// (like async document verification) so the UI can be demoed end-to-end
/// without a real server.
class AppState extends ChangeNotifier {
  final _ocrService = OcrService();

  /// Flip to true once a real OCR.space API key is in lib/config/secrets.dart.
  /// While false, document verification is simulated so the feature can be
  /// demoed without a live key.
  static const _useRealOcr = false;

  final String studentName = 'Samuel Batac';
  final String studentNumber = '2023-BEC-00417';
  final String course = 'BS Information Technology';

  bool isDarkMode = false;

  void toggleDarkMode() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  late final List<Scholarship> scholarships = _seedScholarships();
  late final List<Announcement> announcements = _seedAnnouncements();
  late final List<ScholarshipApplication> applications = [
    ..._seedApplications(),
    ..._seedOtherApplicants(),
  ];

  List<ScholarshipApplication> get myApplications =>
      applications.where((a) => a.studentNumber == studentNumber).toList();

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
        orElse: () => scholarships.first,
      );
      total += sch.amount;
    }
    return total;
  }

  void submitApplication(ScholarshipApplication application) {
    applications.insert(0, application);
    notifyListeners();
    _verifyDocuments(application);
  }

  /// Runs each uploaded document through OCR and checks whether the
  /// applicant's name (as typed on the form) appears in the recognized
  /// text. This is the "OCR auto-match against student record" feature.
  Future<void> _verifyDocuments(ScholarshipApplication application) async {
    for (final doc in application.documents) {
      if (!doc.uploaded) continue;
      doc.matchStatus = DocMatchStatus.verifying;
      notifyListeners();

      if (!_useRealOcr) {
        await Future.delayed(const Duration(milliseconds: 900));
        doc.matchStatus = DocMatchStatus.matched;
        doc.matchNote =
            'Name matched via OCR text extraction against "${application.applicantFullName}".';
        notifyListeners();
        continue;
      }

      final bytes = doc.bytes;
      if (bytes == null) {
        doc.matchStatus = DocMatchStatus.mismatch;
        doc.matchNote = 'Could not read the uploaded file for auto-verification.';
        notifyListeners();
        continue;
      }

      try {
        final text = await _ocrService.extractText(
          bytes: bytes,
          fileName: doc.fileName ?? 'document',
        );
        final result = matchNameAgainstText(application.applicantFullName, text);
        doc.matchStatus = result.matched
            ? DocMatchStatus.matched
            : DocMatchStatus.mismatch;
        doc.matchNote = result.matched
            ? 'Name matched (${(result.score * 100).round()}% of name tokens found).'
            : 'Name on document does not clearly match "${application.applicantFullName}".';
      } on OcrException catch (e) {
        doc.matchStatus = DocMatchStatus.mismatch;
        doc.matchNote = e.message;
      }
      notifyListeners();
    }
    application.status = ApplicationStatus.documentVerification;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));
    application.status = ApplicationStatus.underReview;
    notifyListeners();
  }

  void updateApplicationStatus(String id, ApplicationStatus status) {
    final app = applications.firstWhere((a) => a.id == id);
    app.status = status;
    notifyListeners();
  }

  List<Scholarship> _seedScholarships() {
    final now = DateTime.now();
    return [
      Scholarship(
        id: 'sch-01',
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
        id: 'sch-02',
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
        id: 'sch-03',
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
        id: 'sch-04',
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
        id: 'sch-05',
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
  }

  List<Announcement> _seedAnnouncements() {
    final now = DateTime.now();
    return [
      Announcement(
        title: 'Extended deadline for Educational Assistance Program',
        body:
            'Submission has been extended to give more applicants time to complete requirements.',
        date: now.subtract(const Duration(days: 1)),
        type: AnnouncementType.urgent,
      ),
      Announcement(
        title: 'Orientation for new scholars',
        body:
            'Mandatory orientation for newly approved scholars will be held at the Baliwag Bayan Hall.',
        date: now.subtract(const Duration(days: 2)),
        type: AnnouncementType.event,
      ),
      Announcement(
        title: 'Document upload now supports auto-verification',
        body:
            'Uploaded documents are now automatically checked against your student records for faster processing.',
        date: now.subtract(const Duration(days: 4)),
        type: AnnouncementType.info,
      ),
    ];
  }

  List<ScholarshipApplication> _seedApplications() {
    final now = DateTime.now();
    return [
      ScholarshipApplication(
        id: 'APP-2026-0142',
        scholarshipTitle: 'Baliwag Merit Scholarship',
        studentName: studentName,
        studentNumber: studentNumber,
        dateSubmitted: now.subtract(const Duration(days: 6)),
        status: ApplicationStatus.underReview,
        documents: [
          DocumentItem(
            name: 'Form 137 / Certificate of Grades',
            uploaded: true,
            fileName: 'form137.pdf',
            matchStatus: DocMatchStatus.matched,
          ),
          DocumentItem(
            name: 'Certificate of Enrollment',
            uploaded: true,
            fileName: 'cor_2026.pdf',
            matchStatus: DocMatchStatus.matched,
          ),
          DocumentItem(
            name: 'Barangay Certificate of Residency',
            uploaded: true,
            fileName: 'brgy_cert.jpg',
            matchStatus: DocMatchStatus.matched,
          ),
          DocumentItem(
            name: 'Income Tax Return / Certificate of Indigency',
            uploaded: true,
            fileName: 'itr_indigency.pdf',
            matchStatus: DocMatchStatus.mismatch,
          ),
        ],
        messages: [
          AdminMessage(
            sender: 'Scholarship Office',
            message:
                'Your Certificate of Indigency name does not fully match our records. Please re-upload a clearer copy.',
            date: now.subtract(const Duration(days: 1)),
          ),
        ],
      ),
      ScholarshipApplication(
        id: 'APP-2026-0098',
        scholarshipTitle: 'Educational Assistance Program',
        studentName: studentName,
        studentNumber: studentNumber,
        dateSubmitted: now.subtract(const Duration(days: 18)),
        status: ApplicationStatus.approved,
        documents: [
          DocumentItem(
            name: 'Certificate of Indigency',
            uploaded: true,
            fileName: 'indigency.pdf',
            matchStatus: DocMatchStatus.matched,
          ),
          DocumentItem(
            name: 'Certificate of Enrollment',
            uploaded: true,
            fileName: 'cor.pdf',
            matchStatus: DocMatchStatus.matched,
          ),
          DocumentItem(
            name: 'Valid ID of Parent/Guardian',
            uploaded: true,
            fileName: 'parent_id.jpg',
            matchStatus: DocMatchStatus.matched,
          ),
        ],
        messages: [
          AdminMessage(
            sender: 'Scholarship Office',
            message:
                'Congratulations! Your application has been approved. Please wait for the release schedule.',
            date: now.subtract(const Duration(days: 3)),
          ),
        ],
      ),
    ];
  }

  List<ScholarshipApplication> _seedOtherApplicants() {
    final now = DateTime.now();
    final names = [
      'Maria Santos',
      'John Paul Reyes',
      'Angela Cruz',
      'Mark Anthony Dela Cruz',
      'Kristine Bautista',
      'Rafael Garcia',
      'Nicole Fernandez',
      'Joshua Ramos',
      'Bea Villanueva',
      'Carlo Mendoza',
      'Ella Gonzales',
      'Patrick Aquino',
    ];
    final titles = scholarships.map((s) => s.title).toList();
    final statuses = [
      ApplicationStatus.submitted,
      ApplicationStatus.documentVerification,
      ApplicationStatus.underReview,
      ApplicationStatus.approved,
      ApplicationStatus.rejected,
    ];

    return List.generate(names.length, (i) {
      final status = statuses[i % statuses.length];
      final docCount = 2 + (i % 3);
      return ScholarshipApplication(
        id: 'APP-2026-0${200 + i}',
        scholarshipTitle: titles[i % titles.length],
        studentName: names[i],
        studentNumber: '2023-BEC-${(500 + i * 7).toString().padLeft(5, '0')}',
        dateSubmitted: now.subtract(Duration(days: 1 + i)),
        status: status,
        documents: List.generate(
          docCount,
          (d) => DocumentItem(
            name: 'Requirement ${d + 1}',
            uploaded: true,
            fileName: 'document_${d + 1}.pdf',
            matchStatus: status == ApplicationStatus.submitted
                ? DocMatchStatus.pending
                : (i % 5 == 0 ? DocMatchStatus.mismatch : DocMatchStatus.matched),
          ),
        ),
        messages: const [],
      );
    });
  }
}
