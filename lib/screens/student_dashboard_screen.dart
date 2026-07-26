import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/announcement.dart';
import '../models/application.dart';
import '../models/scholarship.dart';
import '../theme/app_colors.dart';
import '../widgets/doc_match_badge.dart';
import '../widgets/scholarship_card.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= 900;
    final urgentScholarship = app.scholarships.reduce(
      (a, b) => a.daysLeft <= b.daysLeft ? a : b,
    );

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Hero(app: app, wide: wide)),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 32 : 18,
              vertical: 24,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Active Applications',
                        value: '${app.pendingCount}',
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: StatCard(
                        label: 'Approved',
                        value: '${app.approvedCount}',
                        icon: Icons.verified_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    if (wide) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: StatCard(
                          label: 'Open Scholarships',
                          value: '${app.scholarships.length}',
                          icon: Icons.card_giftcard_rounded,
                          color: AppColors.accentDark,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: StatCard(
                          label: 'Closing Soonest',
                          value: '${urgentScholarship.daysLeft}d',
                          icon: Icons.timer_rounded,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 28),
                const _OcrPreviewPanel(),
                const SizedBox(height: 28),
                const SectionHeader(
                  title: 'Available Scholarships',
                  subtitle: 'Programs open for application right now',
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 14.0;
                    const minCardWidth = 260.0;
                    final columns = (constraints.maxWidth / (minCardWidth + spacing))
                        .floor()
                        .clamp(1, 4);
                    final cardWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) / columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final s in app.scholarships)
                          SizedBox(
                            width: cardWidth,
                            child: ScholarshipCard(scholarship: s, onApply: () {}),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _AnnouncementsPanel(announcements: app.announcements),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: _DeadlinesPanel(scholarships: app.scholarships),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AnnouncementsPanel(announcements: app.announcements),
                      const SizedBox(height: 20),
                      _DeadlinesPanel(scholarships: app.scholarships),
                    ],
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Always-visible sample of the OCR document-verification feature, so the
/// concept is visible on the dashboard without having to submit a full
/// application first.
class _OcrPreviewPanel extends StatelessWidget {
  const _OcrPreviewPanel();

  static const _sample = [
    ('Form 137 / Certificate of Grades', DocMatchStatus.matched, 'Name matched via OCR text extraction.'),
    ('Certificate of Enrollment', DocMatchStatus.matched, 'Name matched via OCR text extraction.'),
    ('Certificate of Indigency', DocMatchStatus.mismatch, 'Name on document does not clearly match applicant record.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.document_scanner_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: SectionHeader(
                  title: 'OCR Document Verification',
                  subtitle: 'Uploaded documents are auto-checked against your student record',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final (name, status, note) in _sample)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DocMatchBadge(status: status, note: note),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final AppState app;
  final bool wide;

  const _Hero({required this.app, required this.wide});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(wide ? 32 : 18, wide ? 28 : 20, wide ? 32 : 18, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kumusta, ${app.studentName.split(' ').first}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${app.course} • ${app.studentNumber}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    app.announcements.isNotEmpty
                        ? app.announcements.first.title
                        : 'No new announcements',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementsPanel extends StatelessWidget {
  final List<Announcement> announcements;

  const _AnnouncementsPanel({required this.announcements});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Announcements'),
          const SizedBox(height: 12),
          for (final a in announcements) ...[
            _AnnouncementTile(a: a),
            if (a != announcements.last) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final Announcement a;

  const _AnnouncementTile({required this.a});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: a.type.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(a.type.icon, size: 16, color: a.type.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                a.body,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d, y').format(a.date),
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeadlinesPanel extends StatelessWidget {
  final List<Scholarship> scholarships;

  const _DeadlinesPanel({required this.scholarships});

  @override
  Widget build(BuildContext context) {
    final sorted = [...scholarships]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Upcoming Deadlines'),
          const SizedBox(height: 12),
          for (final s in sorted.take(4)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.daysLeft <= 5 ? AppColors.dangerBg : AppColors.infoBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${s.daysLeft}d',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: s.daysLeft <= 5 ? AppColors.danger : AppColors.info,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.title,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
