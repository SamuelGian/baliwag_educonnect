import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AnnouncementType { info, urgent, event }

AnnouncementType announcementTypeFromName(String? name) => AnnouncementType.values
    .firstWhere((t) => t.name == name, orElse: () => AnnouncementType.info);

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

  String get label {
    switch (this) {
      case AnnouncementType.info:
        return 'Info';
      case AnnouncementType.urgent:
        return 'Urgent';
      case AnnouncementType.event:
        return 'Event';
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
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final AnnouncementType type;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.type,
  });

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    return Announcement(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: announcementTypeFromName(data['type'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'date': Timestamp.fromDate(date),
      'type': type.name,
    };
  }
}
