import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ApplicationStatus {
  submitted,
  documentVerification,
  underReview,
  approved,
  rejected,
}

ApplicationStatus applicationStatusFromName(String? name) =>
    ApplicationStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => ApplicationStatus.submitted,
    );

extension ApplicationStatusX on ApplicationStatus {
  String get label {
    switch (this) {
      case ApplicationStatus.submitted:
        return 'Submitted';
      case ApplicationStatus.documentVerification:
        return 'Document Verification';
      case ApplicationStatus.underReview:
        return 'Under Review';
      case ApplicationStatus.approved:
        return 'Approved';
      case ApplicationStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case ApplicationStatus.submitted:
        return AppColors.statusSubmitted;
      case ApplicationStatus.documentVerification:
        return AppColors.statusVerifying;
      case ApplicationStatus.underReview:
        return AppColors.statusReviewing;
      case ApplicationStatus.approved:
        return AppColors.success;
      case ApplicationStatus.rejected:
        return AppColors.danger;
    }
  }

  Color get bgColor {
    switch (this) {
      case ApplicationStatus.submitted:
        return AppColors.statusSubmittedBg;
      case ApplicationStatus.documentVerification:
        return AppColors.statusVerifyingBg;
      case ApplicationStatus.underReview:
        return AppColors.statusReviewingBg;
      case ApplicationStatus.approved:
        return AppColors.successBg;
      case ApplicationStatus.rejected:
        return AppColors.dangerBg;
    }
  }

  int get stepIndex {
    switch (this) {
      case ApplicationStatus.submitted:
        return 0;
      case ApplicationStatus.documentVerification:
        return 1;
      case ApplicationStatus.underReview:
        return 2;
      case ApplicationStatus.approved:
      case ApplicationStatus.rejected:
        return 3;
    }
  }
}

enum DocMatchStatus { pending, verifying, matched, mismatch, needsResubmission }

DocMatchStatus docMatchStatusFromName(String? name) => DocMatchStatus.values
    .firstWhere((s) => s.name == name, orElse: () => DocMatchStatus.pending);

class DocumentItem {
  final String name;
  bool uploaded;
  String? fileName;
  Uint8List? bytes;

  /// Object path of the uploaded file in the Supabase Storage `documents`
  /// bucket (not a URL — the bucket is private, so a viewer must mint a
  /// fresh signed URL from this path on demand; see
  /// SupabaseStorageService.createSignedUrl). Null for documents uploaded
  /// before this feature existed, or if the storage upload failed.
  String? storagePath;
  DocMatchStatus matchStatus;
  String? matchNote;

  /// Set by an admin (via "Request resubmission" in the Review dialog) to
  /// explain what's wrong with this specific document — distinct from
  /// [matchNote], which is the OCR pipeline's own automated note. Cleared
  /// automatically once the student uploads a replacement file.
  String? adminFeedback;

  DocumentItem({
    required this.name,
    this.uploaded = false,
    this.fileName,
    this.bytes,
    this.storagePath,
    this.matchStatus = DocMatchStatus.pending,
    this.matchNote,
    this.adminFeedback,
  });

  factory DocumentItem.fromMap(Map<String, dynamic> data) {
    return DocumentItem(
      name: data['name'] as String? ?? '',
      uploaded: data['uploaded'] as bool? ?? false,
      fileName: data['fileName'] as String?,
      storagePath: data['storagePath'] as String?,
      matchStatus: docMatchStatusFromName(data['matchStatus'] as String?),
      matchNote: data['matchNote'] as String?,
      adminFeedback: data['adminFeedback'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'uploaded': uploaded,
      'fileName': fileName,
      'storagePath': storagePath,
      'matchStatus': matchStatus.name,
      'matchNote': matchNote,
      'adminFeedback': adminFeedback,
    };
  }
}

class AdminMessage {
  final String sender;
  final String message;
  final DateTime date;

  const AdminMessage({
    required this.sender,
    required this.message,
    required this.date,
  });

  factory AdminMessage.fromMap(Map<String, dynamic> data) {
    return AdminMessage(
      sender: data['sender'] as String? ?? '',
      message: data['message'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'message': message,
      'date': Timestamp.fromDate(date),
    };
  }
}

class ScholarshipApplication {
  final String id;

  /// Stable reference to the `scholarships/{id}` document this application
  /// is for. Added alongside [scholarshipTitle] (kept as a display
  /// snapshot) because matching on title alone breaks the moment an admin
  /// renames a scholarship, or if two programs ever share a title —
  /// duplicate-application checks and slot bookkeeping both need something
  /// that can't drift. Empty string for applications created before this
  /// field existed; those fall back to title-matching (see
  /// AppState.blockReasonFor).
  final String scholarshipId;
  final String scholarshipTitle;

  /// Snapshot of the owning [Scholarship.providerUid] at submission time —
  /// same reasoning as [scholarshipTitle] above: lets a provider's
  /// "Applications" view query `where('providerUid', ==, uid)` directly
  /// instead of an unbounded `whereIn` over all of their scholarship ids.
  /// Empty for applications to an Admin-created scholarship.
  final String providerUid;
  final String studentUid;
  final String studentName;
  final String studentNumber;
  final DateTime dateSubmitted;
  ApplicationStatus status;
  final List<DocumentItem> documents;
  final List<AdminMessage> messages;

  /// Full name as typed by the applicant on the form (Screen 2). This is
  /// what each uploaded document's OCR text is checked against.
  final String applicantFullName;

  ScholarshipApplication({
    required this.id,
    this.scholarshipId = '',
    required this.scholarshipTitle,
    this.providerUid = '',
    required this.studentUid,
    required this.studentName,
    required this.studentNumber,
    required this.dateSubmitted,
    required this.status,
    required this.documents,
    required this.messages,
    String? applicantFullName,
  }) : applicantFullName = applicantFullName ?? studentName;

  int get matchedDocs =>
      documents.where((d) => d.matchStatus == DocMatchStatus.matched).length;

  factory ScholarshipApplication.fromMap(String id, Map<String, dynamic> data) {
    return ScholarshipApplication(
      id: id,
      scholarshipId: data['scholarshipId'] as String? ?? '',
      scholarshipTitle: data['scholarshipTitle'] as String? ?? '',
      providerUid: data['providerUid'] as String? ?? '',
      studentUid: data['studentUid'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      studentNumber: data['studentNumber'] as String? ?? '',
      dateSubmitted:
          (data['dateSubmitted'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: applicationStatusFromName(data['status'] as String?),
      documents:
          (data['documents'] as List<dynamic>?)
              ?.map(
                (e) =>
                    DocumentItem.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          [],
      messages:
          (data['messages'] as List<dynamic>?)
              ?.map(
                (e) =>
                    AdminMessage.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          [],
      applicantFullName: data['applicantFullName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scholarshipId': scholarshipId,
      'scholarshipTitle': scholarshipTitle,
      'providerUid': providerUid,
      'studentUid': studentUid,
      'studentName': studentName,
      'studentNumber': studentNumber,
      'dateSubmitted': Timestamp.fromDate(dateSubmitted),
      'status': status.name,
      'documents': documents.map((d) => d.toMap()).toList(),
      'messages': messages.map((m) => m.toMap()).toList(),
      'applicantFullName': applicantFullName,
    };
  }
}
