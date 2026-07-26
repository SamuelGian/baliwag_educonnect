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
}
