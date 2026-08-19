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

enum DocMatchStatus { pending, verifying, matched, mismatch }

DocMatchStatus docMatchStatusFromName(String? name) => DocMatchStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => DocMatchStatus.pending,
    );

class DocumentItem {
  final String name;
  bool uploaded;
  String? fileName;
  Uint8List? bytes;

  /// Download URL of the uploaded file in Firebase Storage. Populated once
  /// the file has actually been uploaded (not before).
  String? storageUrl;
  DocMatchStatus matchStatus;
  String? matchNote;

  DocumentItem({
    required this.name,
    this.uploaded = false,
    this.fileName,
    this.bytes,
    this.storageUrl,
    this.matchStatus = DocMatchStatus.pending,
    this.matchNote,
  });

  factory DocumentItem.fromMap(Map<String, dynamic> data) {
    return DocumentItem(
      name: data['name'] as String? ?? '',
      uploaded: data['uploaded'] as bool? ?? false,
      fileName: data['fileName'] as String?,
      storageUrl: data['storageUrl'] as String?,
      matchStatus: docMatchStatusFromName(data['matchStatus'] as String?),
      matchNote: data['matchNote'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'uploaded': uploaded,
      'fileName': fileName,
      'storageUrl': storageUrl,
      'matchStatus': matchStatus.name,
      'matchNote': matchNote,
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
  final String scholarshipTitle;
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
    required this.scholarshipTitle,
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
      scholarshipTitle: data['scholarshipTitle'] as String? ?? '',
      studentUid: data['studentUid'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      studentNumber: data['studentNumber'] as String? ?? '',
      dateSubmitted: (data['dateSubmitted'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: applicationStatusFromName(data['status'] as String?),
      documents: (data['documents'] as List<dynamic>?)
              ?.map((e) => DocumentItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      messages: (data['messages'] as List<dynamic>?)
              ?.map((e) => AdminMessage.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      applicantFullName: data['applicantFullName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scholarshipTitle': scholarshipTitle,
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
