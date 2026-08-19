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

ScholarshipCategory categoryFromName(String? name) => ScholarshipCategory.values
    .firstWhere((c) => c.name == name, orElse: () => ScholarshipCategory.academic);

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
          (data['requirements'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              const [],
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
    );
  }
}
