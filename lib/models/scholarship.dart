import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum ScholarshipCategory { academic, financial, arts, sports, technical }

extension ScholarshipCategoryX on ScholarshipCategory {
  String get label {
    switch (this) {
      case ScholarshipCategory.academic:
        return 'Academic Excellence';
      case ScholarshipCategory.financial:
        return 'Financial Assistance';
      case ScholarshipCategory.arts:
        return 'Arts & Culture';
      case ScholarshipCategory.sports:
        return 'Sports';
      case ScholarshipCategory.technical:
        return 'Technical-Vocational';
    }
  }

  IconData get icon {
    switch (this) {
      case ScholarshipCategory.academic:
        return Icons.school_rounded;
      case ScholarshipCategory.financial:
        return Icons.volunteer_activism_rounded;
      case ScholarshipCategory.arts:
        return Icons.palette_rounded;
      case ScholarshipCategory.sports:
        return Icons.sports_basketball_rounded;
      case ScholarshipCategory.technical:
        return Icons.build_rounded;
    }
  }
}

ScholarshipCategory categoryFromName(String? name) =>
    ScholarshipCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => ScholarshipCategory.academic,
    );

/// A scholarship's current lifecycle state. Below this, at or above it: the
/// deadline. Chosen as 3 days per the "closing soon" threshold this was
/// built for — change here, not per-screen, if that window should differ.
const int kClosingSoonDays = 3;

enum ScholarshipStatus {
  active,
  closingSoon,
  slotsFull,
  deadlinePassed,
  manuallyClosed,
}

extension ScholarshipStatusX on ScholarshipStatus {
  String get label {
    switch (this) {
      case ScholarshipStatus.active:
        return 'Active';
      case ScholarshipStatus.closingSoon:
        return 'Closing Soon';
      case ScholarshipStatus.slotsFull:
        return 'Slots Full';
      case ScholarshipStatus.deadlinePassed:
        return 'Deadline Passed';
      case ScholarshipStatus.manuallyClosed:
        return 'Closed';
    }
  }

  /// Whether a student may still submit a *new* application under this
  /// status. Everything except [active]/[closingSoon] blocks new
  /// applications — see AppState.blockReasonFor, which enforces this same
  /// rule on the student side.
  bool get acceptsApplications =>
      this == ScholarshipStatus.active || this == ScholarshipStatus.closingSoon;
}

/// Single source of truth for a scholarship's current status — used by both
/// the admin's "Manage Scholarships" list and every student-facing screen
/// (browse grid, detail sheet, and AppState.blockReasonFor's Apply-button
/// gating) so the two sides can never disagree about whether a given
/// program is still open. A manual admin close (see
/// [Scholarship.manuallyClosed]) always wins, even if the deadline hasn't
/// arrived yet and slots remain — that's the point of the override.
ScholarshipStatus getScholarshipStatus(Scholarship s) {
  if (s.manuallyClosed) return ScholarshipStatus.manuallyClosed;
  if (s.deadline.isBefore(DateTime.now())) {
    return ScholarshipStatus.deadlinePassed;
  }
  if (s.slotsLeft <= 0) return ScholarshipStatus.slotsFull;
  if (s.daysLeft <= kClosingSoonDays) return ScholarshipStatus.closingSoon;
  return ScholarshipStatus.active;
}

class Scholarship {
  final String id;
  final String title;
  final String provider;
  final String description;
  final double amount;
  final int totalSlots;
  final int slotsFilled;
  final DateTime deadline;
  final ScholarshipCategory category;
  final List<String> requirements;

  /// Admin override to stop accepting new applications immediately,
  /// regardless of deadline or remaining slots — see "Close Applications
  /// Early" in the Manage Scholarships list. Always takes priority in
  /// [getScholarshipStatus].
  final bool manuallyClosed;

  /// UID of the [UserRole.provider] account that owns this program, or
  /// empty for a scholarship created by Admin. Used to scope a provider's
  /// own "Manage Scholarships" and "Applications" views to just their own
  /// programs (see AppState and ScholarshipRepository.watchForProvider) —
  /// [provider] above stays the free-text display name either way.
  final String providerUid;

  const Scholarship({
    required this.id,
    required this.title,
    required this.provider,
    required this.description,
    required this.amount,
    required this.totalSlots,
    required this.slotsFilled,
    required this.deadline,
    required this.category,
    required this.requirements,
    this.manuallyClosed = false,
    this.providerUid = '',
  });

  int get slotsLeft => totalSlots - slotsFilled;
  double get fillRatio => totalSlots == 0 ? 0 : slotsFilled / totalSlots;
  int get daysLeft => deadline.difference(DateTime.now()).inDays;

  factory Scholarship.fromMap(String id, Map<String, dynamic> data) {
    return Scholarship(
      id: id,
      title: data['title'] as String? ?? '',
      provider: data['provider'] as String? ?? '',
      description: data['description'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      totalSlots: (data['totalSlots'] as num?)?.toInt() ?? 0,
      slotsFilled: (data['slotsFilled'] as num?)?.toInt() ?? 0,
      deadline: (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: categoryFromName(data['category'] as String?),
      requirements:
          (data['requirements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      manuallyClosed: data['manuallyClosed'] as bool? ?? false,
      providerUid: data['providerUid'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'provider': provider,
      'description': description,
      'amount': amount,
      'totalSlots': totalSlots,
      'slotsFilled': slotsFilled,
      'deadline': Timestamp.fromDate(deadline),
      'category': category.name,
      'requirements': requirements,
      'manuallyClosed': manuallyClosed,
      'providerUid': providerUid,
    };
  }

  Scholarship copyWith({
    String? title,
    String? provider,
    String? description,
    double? amount,
    int? totalSlots,
    int? slotsFilled,
    DateTime? deadline,
    ScholarshipCategory? category,
    List<String>? requirements,
    bool? manuallyClosed,
    String? providerUid,
  }) {
    return Scholarship(
      id: id,
      title: title ?? this.title,
      provider: provider ?? this.provider,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      totalSlots: totalSlots ?? this.totalSlots,
      slotsFilled: slotsFilled ?? this.slotsFilled,
      deadline: deadline ?? this.deadline,
      category: category ?? this.category,
      requirements: requirements ?? this.requirements,
      manuallyClosed: manuallyClosed ?? this.manuallyClosed,
      providerUid: providerUid ?? this.providerUid,
    );
  }
}
