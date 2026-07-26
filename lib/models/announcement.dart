import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AnnouncementType { info, urgent, event }

extension AnnouncementTypeX on AnnouncementType {
  IconData get icon {
    switch (this) {
      case AnnouncementType.info:
        return Icons.campaign_rounded;
      case AnnouncementType.urgent:
        return Icons.priority_high_rounded;
      case AnnouncementType.event:
        return Icons.event_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AnnouncementType.info:
        return AppColors.info;
      case AnnouncementType.urgent:
        return AppColors.danger;
      case AnnouncementType.event:
        return AppColors.accentDark;
    }
  }
}

class Announcement {
  final String title;
  final String body;
  final DateTime date;
  final AnnouncementType type;

  const Announcement({
    required this.title,
    required this.body,
    required this.date,
    required this.type,
  });
}
