import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_state.dart';
import '../data/user_repository.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/application.dart';
import '../models/scholarship.dart';
import '../services/supabase_storage_service.dart';
import '../theme/app_theme_context.dart';
import '../theme/breakpoints.dart';
import '../widgets/doc_match_badge.dart';
import '../widgets/glass_panel.dart';
import '../widgets/stat_card.dart';
import '../widgets/stat_card_row.dart';
import '../widgets/status_chip.dart';

// The Admin sections below (Applications, Scholarships, Announcements,
// Settings) are hosted directly by AdminShell's nav rail / bottom nav
// (mirroring the Student shell) — see admin_shell.dart. Applications itself
// additionally splits into its own "Applicants" / "Analytics" TabBar (see
// ApplicationsTabState below) so the search/filter/review workflow is never
// buried below the stats and charts.

// ============================================================================
// Applications tab (review + approve/reject)
// ============================================================================

enum _ApplicantSort {
  newest,
  name,
  status;

  String get label => switch (this) {
    _ApplicantSort.newest => 'Newest',
    _ApplicantSort.name => 'Name',
    _ApplicantSort.status => 'Status',
  };
}

class ApplicationsTab extends StatefulWidget {
  const ApplicationsTab({super.key});

  @override
  State<ApplicationsTab> createState() => ApplicationsTabState();
}

class ApplicationsTabState extends State<ApplicationsTab>
    with SingleTickerProviderStateMixin {
  ApplicationStatus? _filter;
  String _query = '';
  _ApplicantSort _sortBy = _ApplicantSort.newest;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _filter = null;
      _query = '';
      _sortBy = _ApplicantSort.newest;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= kDesktopBreakpoint;
    final horizontalPadding = wide ? 32.0 : 18.0;

    // Always a fresh copy — app.applications is AppState's own list, and
    // list.sort() below would otherwise mutate it in place.
    var list = app.applications.toList();
    if (_filter != null) {
      list = list.where((a) => a.status == _filter).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (a) =>
                a.studentName.toLowerCase().contains(q) ||
                a.scholarshipTitle.toLowerCase().contains(q) ||
                a.id.toLowerCase().contains(q),
          )
          .toList();
    }
    switch (_sortBy) {
      case _ApplicantSort.newest:
        list.sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));
      case _ApplicantSort.name:
        list.sort((a, b) => a.studentName.compareTo(b.studentName));
      case _ApplicantSort.status:
        list.sort((a, b) => a.status.index.compareTo(b.status.index));
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review applications, verify documents, and manage scholarship programs.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              // Applicants first/default — that's the tab an admin needs
              // instantly, every time, without scrolling past analytics to
              // reach it. Analytics moved to its own tab rather than being
              // buried below the search bar on the same page.
              TabBar(
                controller: _tabController,
                isScrollable: false,
                labelColor: context.scheme.primary,
                unselectedLabelColor: context.appColors.textSecondary,
                indicatorColor: context.scheme.primary,
                dividerColor: context.appColors.border,
                tabs: const [
                  Tab(text: 'Applicants'),
                  Tab(text: 'Analytics'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ApplicantsView(
                list: list,
                allApplications: app.applications,
                query: _query,
                filter: _filter,
                sortBy: _sortBy,
                onQueryChanged: (v) => setState(() => _query = v),
                onFilterChanged: (f) => setState(() => _filter = f),
                onSortChanged: (s) => setState(() => _sortBy = s),
                onResetFilters: _resetFilters,
                wide: wide,
                horizontalPadding: horizontalPadding,
              ),
              _AnalyticsView(
                app: app,
                wide: wide,
                horizontalPadding: horizontalPadding,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The "Applicants" tab — an enterprise-style toolbar (search + sort on one
/// row, horizontally-scrolling status filter chips with counts on the next)
/// sits as a fixed header, always in view without scrolling; the matching
/// applicant cards scroll independently underneath it.
class _ApplicantsView extends StatelessWidget {
  final List<ScholarshipApplication> list;
  final List<ScholarshipApplication> allApplications;
  final String query;
  final ApplicationStatus? filter;
  final _ApplicantSort sortBy;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ApplicationStatus?> onFilterChanged;
  final ValueChanged<_ApplicantSort> onSortChanged;
  final VoidCallback onResetFilters;
  final bool wide;
  final double horizontalPadding;

  const _ApplicantsView({
    required this.list,
    required this.allApplications,
    required this.query,
    required this.filter,
    required this.sortBy,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onResetFilters,
    required this.wide,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            14,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.appColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1 — search + sort. Single horizontal toolbar on wide
              // viewports, stacked on narrow ones (its own LayoutBuilder,
              // not the page-level `wide` flag, so it responds to this
              // toolbar's actual available width).
              LayoutBuilder(
                builder: (context, constraints) {
                  final sortMenu = _SortMenu(
                    value: sortBy,
                    onChanged: onSortChanged,
                  );
                  final search = _SearchField(
                    value: query,
                    onChanged: onQueryChanged,
                  );
                  if (constraints.maxWidth >= 480) {
                    return Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 12),
                        sortMenu,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      search,
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: sortMenu),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              // Row 2 — status filters as a wrapping chip strip, each with a
              // live count. Wrap (not a horizontal scroll) guarantees every
              // chip is always simultaneously visible — on desktop all six
              // fit on one line same as before, on narrow screens the ones
              // that don't fit flow onto a second line instead of depending
              // on a swipe gesture the user has to discover.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'All',
                    count: allApplications.length,
                    selected: filter == null,
                    onTap: () => onFilterChanged(null),
                  ),
                  for (final s in ApplicationStatus.values)
                    _FilterChip(
                      label: s.label,
                      count: allApplications.where((a) => a.status == s).length,
                      selected: filter == s,
                      onTap: () => onFilterChanged(s),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? _EmptyApplicantsState(
                  hasAnyApplications: allApplications.isNotEmpty,
                  onResetFilters: onResetFilters,
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    // Extra bottom clearance on narrow screens only — the
                    // floating GlassNavBar sits over the page there.
                    wide ? 24 : 120,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i < list.length - 1 ? 10 : 0,
                      ),
                      child: _ApplicantCard(app: a),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// The "Analytics" tab — the stats grid and charts that used to sit above
/// the search bar, now moved out of the way of the primary applicant-review
/// workflow instead of forcing a scroll past them every time.
class _AnalyticsView extends StatelessWidget {
  final AppState app;
  final bool wide;
  final double horizontalPadding;

  const _AnalyticsView({
    required this.app,
    required this.wide,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        20,
        horizontalPadding,
        wide ? 24 : 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsGrid(app: app),
          const SizedBox(height: 24),
          // Side-by-side only when there's genuinely enough room: the
          // status chart draws 5 bar labels that need real width to avoid
          // overlapping each other — the page-level `wide` flag alone isn't
          // a reliable proxy for that once a side rail is also competing
          // for space (see the matching comment on StudentDashboardScreen's
          // OCR-preview/Weather row).
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 20.0;
              const minSideBySideWidth = 640.0;
              final sideBySide = constraints.maxWidth >= minSideBySideWidth;
              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _StatusChart(app: app)),
                    const SizedBox(width: gap),
                    Expanded(flex: 2, child: _ProgramBreakdown(app: app)),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusChart(app: app),
                  const SizedBox(height: gap),
                  _ProgramBreakdown(app: app),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final AppState app;

  const _StatsGrid({required this.app});

  @override
  Widget build(BuildContext context) {
    final items = [
      StatCard(
        label: 'Total Applicants',
        value: '${app.applications.length}',
        icon: Icons.groups_rounded,
        color: context.scheme.primary,
      ),
      StatCard(
        label: 'Pending Review',
        value:
            '${app.countByStatus(ApplicationStatus.submitted) + app.countByStatus(ApplicationStatus.documentVerification) + app.countByStatus(ApplicationStatus.underReview)}',
        icon: Icons.hourglass_top_rounded,
        color: context.appColors.warning,
      ),
      StatCard(
        label: 'Approved',
        value: '${app.countByStatus(ApplicationStatus.approved)}',
        icon: Icons.verified_rounded,
        color: context.appColors.success,
      ),
      StatCard(
        label: 'Rejected',
        value: '${app.countByStatus(ApplicationStatus.rejected)}',
        icon: Icons.cancel_rounded,
        color: context.scheme.error,
      ),
      StatCard(
        label: 'Funds Disbursed',
        value: '₱${app.totalDisbursed.toStringAsFixed(0)}',
        icon: Icons.payments_rounded,
        color: context.appColors.accentDark,
      ),
    ];

    return StatCardRow(children: items);
  }
}

class _StatusChart extends StatelessWidget {
  final AppState app;

  const _StatusChart({required this.app});

  @override
  Widget build(BuildContext context) {
    final statuses = ApplicationStatus.values;
    final maxVal = statuses
        .map((s) => app.countByStatus(s))
        .fold<int>(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 300,
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(20, 20, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Applications by Status',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: (maxVal + 2).toDouble(),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= statuses.length) {
                            return const SizedBox.shrink();
                          }
                          final label = statuses[i].label.split(' ').first;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.appColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < statuses.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: app.countByStatus(statuses[i]).toDouble(),
                            color: statuses[i].color,
                            width: 26,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramBreakdown extends StatelessWidget {
  final AppState app;

  const _ProgramBreakdown({required this.app});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Slot Utilization',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: app.scholarships.isEmpty
                  ? Center(
                      child: Text(
                        'No scholarship programs yet.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: app.scholarships.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final s = app.scholarships[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.title,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${s.slotsFilled}/${s.totalSlots}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.appColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: LinearProgressIndicator(
                                value: s.fillRatio,
                                minHeight: 6,
                                backgroundColor: context.appColors.neutralBg,
                                valueColor: AlwaysStoppedAnimation(
                                  context.scheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? context.scheme.primary
              : context.appColors.neutralBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? context.scheme.primary : context.appColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : context.appColors.textSecondary,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '($count)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : context.appColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact "Sort by: X" control for the applicants toolbar.
class _SortMenu extends StatelessWidget {
  final _ApplicantSort value;
  final ValueChanged<_ApplicantSort> onChanged;

  const _SortMenu({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ApplicantSort>(
      tooltip: 'Sort',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final s in _ApplicantSort.values)
          PopupMenuItem(value: s, child: Text('Sort by: ${s.label}')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: context.appColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 16,
              color: context.appColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Sort: ${value.label}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: context.appColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The applicants search box — a [TextEditingController] (rather than a bare
/// `onChanged`) so it can be cleared both by its own suffix "x" button and
/// externally by "Reset Filters", while still not fighting the user's own
/// typing: it only pulls in an external [value] change when the field isn't
/// currently focused.
class _SearchField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.value, required this.onChanged});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: 'Search applicant, ID, program…',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        isDense: true,
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              ),
      ),
    );
  }
}

/// Shown when no applicants match the current search/filter — or when
/// there simply aren't any applications yet, which gets its own message
/// rather than a misleading "Reset Filters" with nothing to reset.
class _EmptyApplicantsState extends StatelessWidget {
  final bool hasAnyApplications;
  final VoidCallback onResetFilters;

  const _EmptyApplicantsState({
    required this.hasAnyApplications,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.appColors.neutralBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasAnyApplications
                    ? Icons.search_off_rounded
                    : Icons.inbox_outlined,
                size: 30,
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasAnyApplications
                  ? 'No applicants found'
                  : 'No applications yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.appColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasAnyApplications
                  ? 'Try adjusting your search or status filter.'
                  : 'Applications will show up here once students start applying.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: context.appColors.textSecondary,
              ),
            ),
            if (hasAnyApplications) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onResetFilters,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status pill with distinct semantic colors — deliberately local to this
/// card rather than reusing the shared [StatusChip] (used elsewhere, e.g.
/// the student's own Application Tracker), whose color mapping stays
/// unchanged so this redesign doesn't ripple into other screens.
class _StatusPill extends StatelessWidget {
  final ApplicationStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, String label) = switch (status) {
      ApplicationStatus.submitted => (
        context.scheme.primary,
        context.scheme.primary.withValues(alpha: 0.12),
        'Submitted',
      ),
      ApplicationStatus.documentVerification => (
        context.scheme.primary,
        context.scheme.primary.withValues(alpha: 0.12),
        'Document Verification',
      ),
      ApplicationStatus.underReview => (
        context.appColors.warning,
        context.appColors.warningBg,
        'Under Review',
      ),
      ApplicationStatus.approved => (
        context.appColors.success,
        context.appColors.successBg,
        'Approved',
      ),
      ApplicationStatus.rejected => (
        context.scheme.error,
        context.appColors.dangerBg,
        'Rejected',
      ),
    };
    // No hard width cap here — the previous fix's ConstrainedBox(maxWidth:
    // 130) was tighter than "Document Verification" needs even at full
    // width, so it was truncating unconditionally instead of only when
    // space was actually tight. The surrounding Wrap (in _ApplicantCard)
    // already reflows this onto its own line when space runs out, so the
    // pill itself is free to size to its natural text width.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// Small metadata pill (scholarship program, date submitted, …) shown in an
/// applicant card's middle section.
class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.appColors.neutralBg,
        borderRadius: BorderRadius.circular(8),
      ),
      // No hard width cap on the label — same lesson as _StatusPill: a
      // fixed maxWidth here truncated "Educational Assistance Program"
      // unconditionally, even in the stacked card layout where this Wrap
      // already has the card's full width to itself. The surrounding Wrap
      // reflows onto its own line when space is actually short, so the
      // badge is free to size to its natural text width.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.appColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern SaaS-style applicant row: avatar + identity, metadata badges,
/// status pill, and quick actions (view / approve / reject) — with a subtle
/// hover lift on desktop/web (MouseRegion has no effect on touch, so this
/// is a no-op there rather than something that needs its own branch).
class _ApplicantCard extends StatefulWidget {
  final ScholarshipApplication app;

  const _ApplicantCard({required this.app});

  @override
  State<_ApplicantCard> createState() => _ApplicantCardState();
}

class _ApplicantCardState extends State<_ApplicantCard> {
  bool _hovering = false;

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .map((e) => e[0])
      .take(2)
      .join()
      .toUpperCase();

  void _openReview(BuildContext context, ScholarshipApplication app) {
    final appState = context.read<AppState>();
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: _ReviewDialog(app: app),
      ),
    );
  }

  /// Awaits and surfaces errors from the quick-action menu — previously
  /// fire-and-forget, so a failed write (offline, a rules rejection, etc.)
  /// gave the admin no feedback at all; the status just silently didn't
  /// change.
  Future<void> _quickUpdateStatus(
    BuildContext context,
    ScholarshipApplication app,
    ApplicationStatus status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().updateApplicationStatus(app.id, status);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not update status. Please try again.'),
        ),
      );
    }
  }

  Widget _identity(BuildContext context, ScholarshipApplication app) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: context.scheme.primary.withValues(alpha: 0.1),
          child: Text(
            _initials(app.studentName),
            style: TextStyle(
              color: context.scheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // maxLines/ellipsis stay on as a safety net for a pathological
              // edge case (an extremely long name) — not the primary means
              // of fitting text anymore. Once this row gets its own full
              // card width (stacked layout) or a generous Expanded share,
              // it practically never triggers.
              Text(
                app.studentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                app.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  Widget _metaBadges(BuildContext context, ScholarshipApplication app) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _MetaBadge(icon: Icons.school_outlined, label: app.scholarshipTitle),
        _MetaBadge(
          icon: Icons.event_outlined,
          label: DateFormat('MMM d, y').format(app.dateSubmitted),
        ),
      ],
    );
  }

  Widget _statusAndActions(BuildContext context, ScholarshipApplication app) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 4,
      children: [
        _StatusPill(status: app.status),
        IconButton(
          tooltip: 'View details',
          icon: const Icon(Icons.visibility_outlined, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => _openReview(context, app),
        ),
        PopupMenuButton<ApplicationStatus>(
          tooltip: 'Quick actions',
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.more_vert_rounded,
            size: 20,
            color: context.appColors.textSecondary,
          ),
          onSelected: (status) => _quickUpdateStatus(context, app, status),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: ApplicationStatus.approved,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: context.appColors.success,
                  ),
                  const SizedBox(width: 8),
                  const Text('Approve'),
                ],
              ),
            ),
            PopupMenuItem(
              value: ApplicationStatus.rejected,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: context.scheme.error,
                  ),
                  const SizedBox(width: 8),
                  const Text('Reject'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hovering ? context.appColors.neutralBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appColors.border),
        ),
        // Genuinely reflows instead of shrinking text to fit: below
        // `stackWidth` the card stacks into a Column (identity on its own
        // full-width row, then metadata, then status/actions) so every
        // piece of text gets the whole card's width rather than a squeezed
        // fraction of it. Between that and `metaWidth` it stays a single
        // row but drops the metadata badges, which are the least essential
        // piece, before anything is forced to truncate.
        child: LayoutBuilder(
          builder: (context, constraints) {
            const stackWidth = 620.0;
            const metaWidth = 900.0;

            if (constraints.maxWidth < stackWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _identity(context, app),
                  const SizedBox(height: 10),
                  _metaBadges(context, app),
                  const SizedBox(height: 10),
                  _statusAndActions(context, app),
                ],
              );
            }

            final showMeta = constraints.maxWidth >= metaWidth;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: _identity(context, app)),
                if (showMeta) ...[
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _metaBadges(context, app)),
                ],
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _statusAndActions(context, app)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReviewDialog extends StatelessWidget {
  final ScholarshipApplication app;

  const _ReviewDialog({required this.app});

  @override
  Widget build(BuildContext context) {
    // Watches AppState (not read) so this dialog keeps reflecting the live
    // application while it's open — e.g. a student resubmitting a document
    // mid-review used to leave this dialog frozen on whatever the document's
    // status was at the moment it was opened, since the [app] field above is
    // just a snapshot passed in once by the caller.
    final appState = context.watch<AppState>();
    final app = appState.applications.firstWhere(
      (a) => a.id == this.app.id,
      orElse: () => this.app,
    );
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      app.studentName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusChip(status: app.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${app.id} • ${app.scholarshipTitle}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Document Verification',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 10),
              // A scholarship can list an arbitrary number of requirements,
              // so this list has no fixed size — Flexible+SingleChildScrollView
              // lets it grow up to the dialog's own maxHeight and then scroll,
              // instead of pushing the Reject/Approve row off the bottom of a
              // short viewport.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final d in app.documents)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                              Flexible(
                                child: DocMatchBadge(
                                  status: d.matchStatus,
                                  note: d.adminFeedback ?? d.matchNote,
                                ),
                              ),
                              IconButton(
                                tooltip: 'View submitted file',
                                icon: Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                  color: context.appColors.textSecondary,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: () =>
                                    _viewDocument(context, app.id, d),
                              ),
                              IconButton(
                                tooltip: 'Request resubmission',
                                icon: Icon(
                                  Icons.flag_outlined,
                                  size: 18,
                                  color: context.scheme.error,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: () =>
                                    _requestResubmission(context, appState, d),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.scheme.error,
                        side: BorderSide(color: context.scheme.error),
                      ),
                      onPressed: () => _updateStatusAndClose(
                        context,
                        appState,
                        app.id,
                        ApplicationStatus.rejected,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: context.appColors.success,
                      ),
                      onPressed: () => _updateStatusAndClose(
                        context,
                        appState,
                        app.id,
                        ApplicationStatus.approved,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Awaits the write and only closes the dialog on success — previously
  /// fire-and-forget, closing immediately regardless of whether the update
  /// actually succeeded, which could show a stale status if it silently
  /// failed (offline, a rules rejection, etc.).
  Future<void> _updateStatusAndClose(
    BuildContext context,
    AppState appState,
    String applicationId,
    ApplicationStatus status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await appState.updateApplicationStatus(applicationId, status);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not update status. Please try again.'),
        ),
      );
      return;
    }
    navigator.pop();
  }

  void _viewDocument(
    BuildContext context,
    String applicationId,
    DocumentItem doc,
  ) {
    showDialog(
      context: context,
      builder: (_) =>
          _DocumentPreviewDialog(applicationId: applicationId, doc: doc),
    );
  }

  void _requestResubmission(
    BuildContext context,
    AppState appState,
    DocumentItem doc,
  ) {
    final controller = TextEditingController(text: doc.adminFeedback ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Request resubmission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doc.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Tell the student what's wrong",
                hintText:
                    'e.g. Uploaded file is blurry, wrong document, or name mismatch',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.scheme.error,
            ),
            onPressed: () {
              final feedback = controller.text.trim();
              if (feedback.isEmpty) return;
              appState.requestDocumentResubmission(
                applicationId: app.id,
                documentName: doc.name,
                feedback: feedback,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

/// Fetches and shows the file a student actually uploaded for a document —
/// the OCR verdict is only ever a first pass; this is what lets an admin
/// exercise real judgment on it, as the OCR-verification proposal intends.
class _DocumentPreviewDialog extends StatefulWidget {
  final String applicationId;
  final DocumentItem doc;

  const _DocumentPreviewDialog({
    required this.applicationId,
    required this.doc,
  });

  @override
  State<_DocumentPreviewDialog> createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<_DocumentPreviewDialog> {
  final _storageService = SupabaseStorageService();
  String? _signedUrl;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = widget.doc.storagePath;
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error =
            'No file was stored for this document (it may predate this feature, '
            'the Supabase Storage policies may not allow saving it yet, or it '
            'was too large to store).';
        _loading = false;
      });
      return;
    }
    try {
      final url = await _storageService.createSignedUrl(path);
      if (!mounted) return;
      setState(() {
        _signedUrl = url;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this file: $e';
        _loading = false;
      });
    }
  }

  bool get _isImage =>
      mimeTypeForFileName(widget.doc.fileName ?? '').startsWith('image/');

  Future<void> _openInNewTab() async {
    final url = _signedUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.doc.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_signedUrl != null)
                    IconButton(
                      tooltip: 'Open in New Tab',
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: _openInNewTab,
                    ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    final url = _signedUrl;
    if (url == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _error ?? 'Could not load this file.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      );
    }
    if (!_isImage) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 14),
              Text(
                widget.doc.fileName ?? widget.doc.name,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openInNewTab,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open PDF in New Tab'),
              ),
            ],
          ),
        ),
      );
    }
    // Full-screen, pinch/scroll-to-zoom image so an admin can actually
    // inspect fine detail (a printed name, a signature, a stamp) instead
    // of squinting at a small thumbnail.
    return InteractiveViewer(
      minScale: 1,
      maxScale: 6,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          },
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This image could not be loaded.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Scholarships tab — full CRUD (Create / Read / Update / Delete)
// ============================================================================

class ScholarshipsTab extends StatefulWidget {
  const ScholarshipsTab({super.key});

  @override
  State<ScholarshipsTab> createState() => ScholarshipsTabState();
}

enum _ScholarshipFilter {
  all,
  active,
  closed;

  String get label => switch (this) {
    _ScholarshipFilter.all => 'Show All',
    _ScholarshipFilter.active => 'Active Only',
    _ScholarshipFilter.closed => 'Closed Only',
  };

  bool matches(ScholarshipStatus status) => switch (this) {
    _ScholarshipFilter.all => true,
    _ScholarshipFilter.active => status.acceptsApplications,
    _ScholarshipFilter.closed => !status.acceptsApplications,
  };
}

class ScholarshipsTabState extends State<ScholarshipsTab> {
  bool _seeding = false;
  _ScholarshipFilter _filter = _ScholarshipFilter.all;

  Future<void> _loadSamples() async {
    setState(() => _seeding = true);
    try {
      await context.read<AppState>().seedSampleScholarships();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not load sample scholarships. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final width = MediaQuery.of(context).size.width;
    final wide = width >= kDesktopBreakpoint;
    final narrow = width < 560;
    // Sample scholarships are seeded ownerless (providerUid: '') — visible
    // to Admin/students via their unscoped view, but never to a specific
    // Provider, whose own view is always filtered to just their own
    // programs (see AppState's scholarshipStream). Offering this button on
    // the Provider dashboard would create scholarships the provider who
    // clicked it could then never see or manage — confusing, not useful.
    final isProvider = app.user.role == UserRole.provider;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Manage Scholarships',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.appColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Create, edit, or remove scholarship programs. Changes appear for students instantly.',
          style: TextStyle(
            fontSize: 13,
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
    final addButton = FilledButton.icon(
      onPressed: () {
        final appState = context.read<AppState>();
        showDialog(
          context: context,
          builder: (_) => ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: const _ScholarshipFormDialog(),
          ),
        );
      },
      style: FilledButton.styleFrom(backgroundColor: context.scheme.primary),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Add Scholarship'),
    );

    return SingleChildScrollView(
      // Extra bottom clearance on narrow screens only — the floating
      // GlassNavBar sits over the page there; wide screens use a side
      // rail instead, so there's nothing to clear.
      padding: EdgeInsets.fromLTRB(
        wide ? 32 : 18,
        24,
        wide ? 32 : 18,
        wide ? 24 : 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (narrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: addButton),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: titleBlock),
                addButton,
              ],
            ),
          const SizedBox(height: 22),
          if (app.scholarships.isEmpty)
            SizedBox(
              width: double.infinity,
              child: GlassPanel(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Text(
                      isProvider
                          ? 'No scholarship programs yet. Tap "Add Scholarship" to create your first one.'
                          : 'No scholarship programs yet. Tap "Add Scholarship" to create one,\nor load a few ready-made programs to get started quickly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appColors.textSecondary),
                    ),
                    if (!isProvider) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _seeding ? null : _loadSamples,
                        icon: _seeding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: Text(
                          _seeding ? 'Loading…' : 'Load Sample Scholarships',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in _ScholarshipFilter.values)
                  _FilterChip(
                    label: f.label,
                    count: app.scholarships
                        .where((s) => f.matches(getScholarshipStatus(s)))
                        .length,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final filtered = app.scholarships
                    .where((s) => _filter.matches(getScholarshipStatus(s)))
                    .toList();
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text(
                        'No scholarships match "${_filter.label}".',
                        style: TextStyle(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final s in filtered) ...[
                      _ScholarshipAdminCard(scholarship: s),
                      const SizedBox(height: 14),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ScholarshipAdminCard extends StatelessWidget {
  final Scholarship scholarship;

  const _ScholarshipAdminCard({required this.scholarship});

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    final status = getScholarshipStatus(s);
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              s.category.icon,
              color: context.scheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    _ScholarshipStatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  s.provider,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _metaChip(
                      Icons.payments_rounded,
                      '₱${s.amount.toStringAsFixed(0)}',
                    ),
                    _metaChip(
                      status == ScholarshipStatus.slotsFull
                          ? Icons.error_outline_rounded
                          : Icons.groups_rounded,
                      '${s.slotsFilled}/${s.totalSlots} slots',
                    ),
                    _metaChip(
                      Icons.event_rounded,
                      DateFormat('MMM d, y').format(s.deadline),
                    ),
                    _metaChip(Icons.category_rounded, s.category.label),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: s.manuallyClosed
                ? 'Reopen applications'
                : 'Close applications early',
            icon: Icon(
              s.manuallyClosed
                  ? Icons.play_circle_outline_rounded
                  : Icons.block_rounded,
              size: 20,
              color: s.manuallyClosed
                  ? context.appColors.success
                  : context.appColors.warning,
            ),
            onPressed: () => context.read<AppState>().updateScholarship(
              s.copyWith(manuallyClosed: !s.manuallyClosed),
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () {
              final appState = context.read<AppState>();
              showDialog(
                context: context,
                builder: (_) => ChangeNotifierProvider<AppState>.value(
                  value: appState,
                  child: _ScholarshipFormDialog(existing: s),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: context.scheme.error,
            ),
            onPressed: () => _confirmDelete(context, s),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Builder(
      builder: (context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.appColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Scholarship s) {
    final appState = context.read<AppState>();
    // Applications keep their own snapshot of the scholarship's title, so
    // deleting the program itself never breaks or orphans them — but the
    // admin should still know they exist before removing the program those
    // applicants applied to.
    final applicationCount = appState.applications
        .where((a) => a.scholarshipId == s.id)
        .length;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete scholarship?'),
        content: Text(
          applicationCount > 0
              ? 'This will permanently remove "${s.title}", which has '
                    '$applicationCount existing application${applicationCount == 1 ? '' : 's'}. '
                    'Those applications will remain in the system with their own '
                    'record of it, but the program itself will be gone. This cannot be undone.'
              : 'This will permanently remove "${s.title}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.scheme.error,
            ),
            onPressed: () {
              appState.deleteScholarship(s.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Status badge for the admin's Manage Scholarships list — same
/// [getScholarshipStatus] the student side uses, so the two can never show
/// conflicting information about the same program.
class _ScholarshipStatusBadge extends StatelessWidget {
  final ScholarshipStatus status;

  const _ScholarshipStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (status) {
      ScholarshipStatus.active => (
        context.appColors.success,
        context.appColors.successBg,
      ),
      ScholarshipStatus.closingSoon => (
        context.appColors.warning,
        context.appColors.warningBg,
      ),
      ScholarshipStatus.slotsFull => (
        context.appColors.warning,
        context.appColors.warningBg,
      ),
      ScholarshipStatus.deadlinePassed => (
        context.appColors.textMuted,
        context.appColors.neutralBg,
      ),
      ScholarshipStatus.manuallyClosed => (
        context.appColors.textMuted,
        context.appColors.neutralBg,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _ScholarshipFormDialog extends StatefulWidget {
  final Scholarship? existing;

  const _ScholarshipFormDialog({this.existing});

  @override
  State<_ScholarshipFormDialog> createState() => _ScholarshipFormDialogState();
}

class _ScholarshipFormDialogState extends State<_ScholarshipFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _provider;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _totalSlots;
  late final TextEditingController _slotsFilled;
  late final TextEditingController _customRequirement;
  late List<String> _requirementsList;
  late ScholarshipCategory _category;
  late DateTime _deadline;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  bool _isProviderAccount = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    // A Provider account always owns what it creates, so its org name
    // isn't a freeform field here the way Admin's is (see
    // AppState.createScholarship, which stamps it regardless) — pre-filled
    // and locked so the field doesn't mislead by looking editable.
    _isProviderAccount =
        context.read<AppState>().user.role == UserRole.provider;
    _title = TextEditingController(text: e?.title ?? '');
    _provider = TextEditingController(
      text: _isProviderAccount
          ? context.read<AppState>().user.organizationName
          : (e?.provider ?? ''),
    );
    _description = TextEditingController(text: e?.description ?? '');
    _amount = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(0) : '',
    );
    _totalSlots = TextEditingController(
      text: e != null ? '${e.totalSlots}' : '',
    );
    _slotsFilled = TextEditingController(
      text: e != null ? '${e.slotsFilled}' : '0',
    );
    _customRequirement = TextEditingController();
    _requirementsList = List<String>.from(e?.requirements ?? const []);
    _category = e?.category ?? ScholarshipCategory.academic;
    _deadline = e?.deadline ?? DateTime.now().add(const Duration(days: 14));
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _provider,
      _description,
      _amount,
      _totalSlots,
      _slotsFilled,
      _customRequirement,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _addRequirement(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final alreadyAdded = _requirementsList.any(
      (r) => r.toLowerCase() == trimmed.toLowerCase(),
    );
    if (alreadyAdded) return;
    setState(() => _requirementsList.add(trimmed));
  }

  void _removeRequirement(String value) {
    setState(() => _requirementsList.remove(value));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final requirements = _requirementsList;
    if (requirements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one document requirement.')),
      );
      return;
    }

    final totalSlots = int.parse(_totalSlots.text);
    final slotsFilled = int.tryParse(_slotsFilled.text) ?? 0;
    if (slotsFilled > totalSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Filled slots cannot exceed total slots.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final draft = Scholarship(
      id: widget.existing?.id ?? '',
      title: _title.text.trim(),
      provider: _provider.text.trim(),
      description: _description.text.trim(),
      amount: double.parse(_amount.text),
      totalSlots: totalSlots,
      slotsFilled: slotsFilled,
      deadline: _deadline,
      category: _category,
      requirements: requirements,
      // Preserve the existing owner on edit — AppState.createScholarship
      // stamps this on first create, but an update here builds a fresh
      // Scholarship from the form fields, which otherwise default back to
      // ownerless and would silently un-scope the program.
      providerUid: widget.existing?.providerUid ?? '',
    );

    try {
      if (_isEdit) {
        await appState.updateScholarship(draft);
      } else {
        await appState.createScholarship(draft);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          // Relative to the viewport, not a fixed pixel value — a fixed
          // 640 could still exceed a short/landscape window; this way the
          // dialog always leaves room to see it's a dialog at all, and the
          // Flexible+SingleChildScrollView below picks up the rest.
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit Scholarship' : 'Add Scholarship',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field('Title', _title),
                        _field('Provider', _provider, enabled: !_isProviderAccount),
                        _field('Description', _description, maxLines: 3),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                'Amount (₱)',
                                _amount,
                                keyboardType: TextInputType.number,
                                numeric: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child:
                                  DropdownButtonFormField<ScholarshipCategory>(
                                    initialValue: _category,
                                    // Without this, the dropdown's internal
                                    // Row (selected label + arrow) sizes to
                                    // its own content instead of the space
                                    // the outer Expanded actually gives it —
                                    // a long label like "Financial
                                    // Assistance" then overflows inside the
                                    // dropdown itself, independent of the
                                    // outer Row's own constraints.
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                    ),
                                    items: [
                                      for (final c
                                          in ScholarshipCategory.values)
                                        DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                            c.label,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _category = v!),
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                'Total Slots',
                                _totalSlots,
                                keyboardType: TextInputType.number,
                                numeric: true,
                                min: 1,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                'Slots Filled',
                                _slotsFilled,
                                keyboardType: TextInputType.number,
                                numeric: true,
                                min: 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _pickDeadline,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Application Deadline',
                            ),
                            child: Text(
                              DateFormat('MMM d, y').format(_deadline),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _requirementsField(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: context.scheme.primary,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isEdit ? 'Save Changes' : 'Create'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Common Philippine scholarship document types — these exact labels
  /// match what DocumentValidationService's keyword-matching recognizes
  /// (see lib/services/document_validation_service.dart), so a requirement
  /// picked from here gets real content validation during OCR review
  /// instead of falling back to the generic length/word-quality-only check
  /// a freeform/misspelled name would get.
  static const List<String> _commonRequirements = [
    'Certificate of Indigency',
    'Certificate of Enrollment / Registration',
    'Grade Slip / Form 137',
    'Barangay Certificate of Residency',
    'Certificate of Good Moral Character',
    'Recommendation Letter',
    'Valid ID of Parent/Guardian',
    'Valid ID (Student)',
    'Portfolio of Work',
    'Certificate from Sports Coordinator',
  ];

  /// Requirements picker — replaces the old one-per-line free-text textarea
  /// with a chip list of what's already been added, a dropdown of the
  /// common types above, and a free-text fallback for anything not in that
  /// list. Easier to scan than a textarea, and impossible to end up with
  /// stray blank lines or inconsistently-worded duplicates of the same
  /// document type.
  Widget _requirementsField() {
    final available = _commonRequirements
        .where((r) => !_requirementsList.contains(r))
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Requirements'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_requirementsList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'No requirements added yet.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.appColors.textSecondary,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _requirementsList)
                    Chip(
                      label: Text(r, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () => _removeRequirement(r),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            const SizedBox(height: 12),
            if (available.isNotEmpty)
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text(
                    'Add a common requirement…',
                    style: TextStyle(fontSize: 13),
                  ),
                  items: [
                    for (final r in available)
                      DropdownMenuItem(
                        value: r,
                        child: Text(r, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) _addRequirement(v);
                  },
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customRequirement,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Or type a custom requirement',
                    ),
                    onSubmitted: (v) {
                      _addRequirement(v);
                      _customRequirement.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Add requirement',
                  icon: Icon(
                    Icons.add_circle_rounded,
                    color: context.scheme.primary,
                  ),
                  onPressed: () {
                    _addRequirement(_customRequirement.text);
                    _customRequirement.clear();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool numeric = false,
    int? min,
    String? hint,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (numeric) {
            final n = num.tryParse(v.trim());
            if (n == null) return 'Enter a number';
            if (min != null && n < min) return 'Must be at least $min';
          }
          return null;
        },
      ),
    );
  }
}

// ============================================================================
// Announcements tab — full CRUD
// ============================================================================

class AnnouncementsTab extends StatelessWidget {
  const AnnouncementsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final width = MediaQuery.of(context).size.width;
    final wide = width >= kDesktopBreakpoint;
    final narrow = width < 560;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Announcements',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.appColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Post updates that students see on their dashboard.',
          style: TextStyle(
            fontSize: 13,
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
    final addButton = FilledButton.icon(
      onPressed: () {
        final appState = context.read<AppState>();
        showDialog(
          context: context,
          builder: (_) => ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: const _AnnouncementFormDialog(),
          ),
        );
      },
      style: FilledButton.styleFrom(backgroundColor: context.scheme.primary),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('New Announcement'),
    );

    return SingleChildScrollView(
      // Extra bottom clearance on narrow screens only — the floating
      // GlassNavBar sits over the page there; wide screens use a side
      // rail instead, so there's nothing to clear.
      padding: EdgeInsets.fromLTRB(
        wide ? 32 : 18,
        24,
        wide ? 32 : 18,
        wide ? 24 : 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (narrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: addButton),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: titleBlock),
                addButton,
              ],
            ),
          const SizedBox(height: 22),
          if (app.announcements.isEmpty)
            SizedBox(
              width: double.infinity,
              child: GlassPanel(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No announcements yet.',
                    style: TextStyle(color: context.appColors.textSecondary),
                  ),
                ),
              ),
            )
          else
            for (final a in app.announcements) ...[
              _AnnouncementAdminCard(announcement: a),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _AnnouncementAdminCard extends StatelessWidget {
  final Announcement announcement;

  const _AnnouncementAdminCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      child: Row(
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
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  a.body,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${a.type.label} • ${DateFormat('MMM d, y').format(a.date)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () {
              final appState = context.read<AppState>();
              showDialog(
                context: context,
                builder: (_) => ChangeNotifierProvider<AppState>.value(
                  value: appState,
                  child: _AnnouncementFormDialog(existing: a),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: context.scheme.error,
            ),
            onPressed: () {
              final appState = context.read<AppState>();
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Delete announcement?'),
                  content: Text('This will permanently remove "${a.title}".'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: context.scheme.error,
                      ),
                      onPressed: () {
                        appState.deleteAnnouncement(a.id);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnnouncementFormDialog extends StatefulWidget {
  final Announcement? existing;

  const _AnnouncementFormDialog({this.existing});

  @override
  State<_AnnouncementFormDialog> createState() =>
      _AnnouncementFormDialogState();
}

class _AnnouncementFormDialogState extends State<_AnnouncementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late AnnouncementType _type;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _type = e?.type ?? AnnouncementType.info;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final draft = Announcement(
      id: widget.existing?.id ?? '',
      title: _title.text.trim(),
      body: _body.text.trim(),
      date: widget.existing?.date ?? DateTime.now(),
      type: _type,
    );
    try {
      if (_isEdit) {
        await appState.updateAnnouncement(draft);
      } else {
        await appState.createAnnouncement(draft);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit Announcement' : 'New Announcement',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _title,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _body,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<AnnouncementType>(
                          initialValue: _type,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: [
                            for (final t in AnnouncementType.values)
                              DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _type = v!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: context.scheme.primary,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isEdit ? 'Save Changes' : 'Post'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Providers tab (Admin-only: approve/reject Scholarship Provider accounts)
// ============================================================================

enum _ProviderFilter {
  all,
  pending,
  approved,
  rejected;

  String get label => switch (this) {
    _ProviderFilter.all => 'All',
    _ProviderFilter.pending => 'Pending',
    _ProviderFilter.approved => 'Approved',
    _ProviderFilter.rejected => 'Rejected',
  };

  bool matches(ProviderStatus status) => switch (this) {
    _ProviderFilter.all => true,
    _ProviderFilter.pending => status == ProviderStatus.pending,
    _ProviderFilter.approved => status == ProviderStatus.approved,
    _ProviderFilter.rejected => status == ProviderStatus.rejected,
  };
}

/// Admin's gate for Scholarship Provider accounts — every provider self-
/// registers as `pending` (see RegisterScreen/AuthService.registerProvider)
/// and sits on a "waiting for approval" screen (AuthGate's
/// `_ProviderGateScreen`) until approved here. Not AppState-backed like the
/// other tabs since it needs every provider account platform-wide, not
/// just the signed-in admin's own scoped data — see UserRepository.
class ProvidersTab extends StatefulWidget {
  const ProvidersTab({super.key});

  @override
  State<ProvidersTab> createState() => _ProvidersTabState();
}

class _ProvidersTabState extends State<ProvidersTab> {
  final _userRepo = UserRepository();
  _ProviderFilter _filter = _ProviderFilter.all;

  Future<void> _setStatus(
    BuildContext context,
    AppUser provider,
    ProviderStatus status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _userRepo.setProviderStatus(provider.uid, status);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not update this provider. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= kDesktopBreakpoint;
    final horizontalPadding = wide ? 32.0 : 18.0;

    return StreamBuilder<List<AppUser>>(
      stream: _userRepo.watchProviders(),
      builder: (context, snapshot) {
        final providers = snapshot.data ?? const <AppUser>[];
        final filtered = providers
            .where((p) => _filter.matches(p.providerStatus))
            .toList();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            wide ? 24 : 120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scholarship Providers',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Approve or reject organizations that want to run their own scholarship programs.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in _ProviderFilter.values)
                    _FilterChip(
                      label: f.label,
                      count: providers.where((p) => f.matches(p.providerStatus)).length,
                      selected: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      providers.isEmpty
                          ? 'No provider accounts have registered yet.'
                          : 'No providers match "${_filter.label}".',
                      style: TextStyle(color: context.appColors.textSecondary),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (final p in filtered) ...[
                      _ProviderCard(
                        provider: p,
                        onApprove: () =>
                            _setStatus(context, p, ProviderStatus.approved),
                        onReject: () =>
                            _setStatus(context, p, ProviderStatus.rejected),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final AppUser provider;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ProviderCard({
    required this.provider,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, String label) = switch (provider.providerStatus) {
      ProviderStatus.pending => (
        context.appColors.warning,
        context.appColors.warningBg,
        'Pending',
      ),
      ProviderStatus.approved => (
        context.appColors.success,
        context.appColors.successBg,
        'Approved',
      ),
      ProviderStatus.rejected => (
        context.scheme.error,
        context.appColors.dangerBg,
        'Rejected',
      ),
    };

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.corporate_fare_rounded,
              color: context.scheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.organizationName.isEmpty
                      ? '(unnamed organization)'
                      : provider.organizationName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                const SizedBox(height: 3),
                Text(
                  '${provider.fullName} • ${provider.email}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (provider.providerStatus != ProviderStatus.approved)
                OutlinedButton(
                  onPressed: onApprove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.appColors.success,
                    side: BorderSide(color: context.appColors.success),
                  ),
                  child: const Text('Approve'),
                ),
              if (provider.providerStatus != ProviderStatus.rejected)
                OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.scheme.error,
                    side: BorderSide(color: context.scheme.error),
                  ),
                  child: const Text('Reject'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
