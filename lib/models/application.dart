import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ApplicationStatus {
  submitted,
  documentVerification,
  underReview,
  approved,
  rejected,
}

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

enum DocMatchStatus { pending, verifying, matched, mismatch }

class DocumentItem {
  final String name;
  bool uploaded;
  String? fileName;
  Uint8List? bytes;
  DocMatchStatus matchStatus;
  String? matchNote;

  DocumentItem({
    required this.name,
    this.uploaded = false,
    this.fileName,
    this.bytes,
    this.matchStatus = DocMatchStatus.pending,
    this.matchNote,
  });
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
}

class ScholarshipApplication {
  final String id;
  final String scholarshipTitle;
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
    required this.scholarshipTitle,
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
}
