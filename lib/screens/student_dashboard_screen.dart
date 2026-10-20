import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/announcement.dart';
import '../models/scholarship.dart';
import '../theme/app_theme_context.dart';
import '../theme/breakpoints.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_panel.dart';
import '../widgets/scholarship_card.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import '../widgets/stat_card_row.dart';
import '../widgets/weather_badge.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    return AmbientBackground(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(app: app, wide: wide),
            ),
            SliverPadding(
              // Extra bottom clearance on narrow screens only — that's
              // where the floating GlassNavBar sits over the page content;
              // on wide screens navigation is a side rail, nothing to clear.
              padding: EdgeInsets.fromLTRB(
                wide ? 32 : 18,
                24,
                wide ? 32 : 18,
                wide ? 24 : 120,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  StatCardRow(
                    maxCardWidth: 240,
                    children: [
                      StatCard(
                        label: 'Active Applications',
                        value: '${app.pendingCount}',
                        icon: Icons.pending_actions_rounded,
                        color: context.appColors.info,
                      ),
                      StatCard(
                        label: 'Approved',
                        value: '${app.approvedCount}',
                        icon: Icons.verified_rounded,
                        color: context.appColors.success,
                      ),
                    ],
                  ),
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
                      final columns =
                          (constraints.maxWidth / (minCardWidth + spacing))
                              .floor()
                              .clamp(1, 4);
                      final cardWidth =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final s in app.scholarships)
                            SizedBox(
                              width: cardWidth,
                              child: ScholarshipCard(
                                scholarship: s,
                                onApply: () {},
                              ),
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
                          child: _AnnouncementsPanel(
                            announcements: app.announcements,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 2,
                          child: _DeadlinesPanel(
                            scholarships: app.scholarships,
                          ),
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
      padding: EdgeInsets.fromLTRB(
        wide ? 32 : 18,
        wide ? 28 : 20,
        wide ? 32 : 18,
        36,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.appColors.heroGradient,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const WeatherBadge(),
              const SizedBox(width: 10),
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
          _AnnouncementBanner(announcements: app.announcements),
        ],
      ),
    );
  }
}

/// Collapsed by default to a single-line preview of the highest-priority
/// announcement (urgent ones first, then newest-first) — tap to expand into
/// the full list, right where a student already is instead of only further
/// down the dashboard (see [_AnnouncementsPanel]). Previously this banner
/// only ever showed `announcements.first`, silently hiding everything else
/// AppState already had (announcements are always fetched in full — see
/// AnnouncementRepository.watchAll — this was a display-only gap).
class _AnnouncementBanner extends StatefulWidget {
  final List<Announcement> announcements;

  const _AnnouncementBanner({required this.announcements});

  @override
  State<_AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<_AnnouncementBanner> {
  bool _expanded = false;

  // Session-only — resets on refresh/re-login. A persistent "read" state
  // would need either a local-storage package or a per-student Firestore
  // write per announcement; this covers the actual ask ("stop showing me
  /// the one I just dismissed while I'm sitting here") without either.
  final Set<String> _dismissedIds = {};

  List<Announcement> get _visible {
    final list = widget.announcements
        .where((a) => !_dismissedIds.contains(a.id))
        .toList();
    // AppState's list is already newest-first; stably promoting urgent ones
    // to the front preserves that date order within each group.
    list.sort((a, b) {
      final aUrgent = a.type == AnnouncementType.urgent;
      final bUrgent = b.type == AnnouncementType.urgent;
      if (aUrgent == bUrgent) return 0;
      return aUrgent ? -1 : 1;
    });
    return list;
  }

  void _dismiss(String id) {
    setState(() {
      _dismissedIds.add(id);
      if (_visible.isEmpty) _expanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: visible.isEmpty
                    ? null
                    : () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        visible.isNotEmpty &&
                                visible.first.type == AnnouncementType.urgent
                            ? Icons.priority_high_rounded
                            : Icons.notifications_active_rounded,
                        color:
                            visible.isNotEmpty &&
                                visible.first.type == AnnouncementType.urgent
                            ? context.scheme.error
                            : context.scheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          visible.isEmpty
                              ? 'No new announcements'
                              : visible.length == 1
                              ? visible.first.title
                              : '${visible.first.title} (+${visible.length - 1} more)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (visible.isNotEmpty)
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
              if (_expanded && visible.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    children: [
                      Divider(color: Colors.white.withValues(alpha: 0.25)),
                      const SizedBox(height: 6),
                      for (final a in visible) ...[
                        _AnnouncementBannerTile(
                          announcement: a,
                          onDismiss: () => _dismiss(a.id),
                        ),
                        if (a != visible.last) const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementBannerTile extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback onDismiss;

  const _AnnouncementBannerTile({
    required this.announcement,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final urgent = a.type == AnnouncementType.urgent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: a.type.color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(a.type.icon, size: 13, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      a.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: urgent ? FontWeight.w800 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: a.type.color.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      a.type.label,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                a.body,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('MMM d, y').format(a.date),
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Dismiss',
          icon: const Icon(
            Icons.close_rounded,
            size: 16,
            color: Colors.white70,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: onDismiss,
        ),
      ],
    );
  }
}

class _AnnouncementsPanel extends StatelessWidget {
  final List<Announcement> announcements;

  const _AnnouncementsPanel({required this.announcements});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
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
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                a.body,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.appColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d, y').format(a.date),
                style: TextStyle(
                  fontSize: 11,
                  color: context.appColors.textMuted,
                ),
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
    final sorted = [...scholarships]
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return GlassPanel(
      padding: const EdgeInsets.all(18),
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
                      color: s.daysLeft <= 5
                          ? context.appColors.dangerBg
                          : context.appColors.infoBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${s.daysLeft}d',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: s.daysLeft <= 5
                            ? context.scheme.error
                            : context.appColors.info,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
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
