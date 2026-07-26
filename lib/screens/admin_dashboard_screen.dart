import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/application.dart';
import '../theme/app_colors.dart';
import '../widgets/doc_match_badge.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_chip.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  ApplicationStatus? _filter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= 900;

    var list = app.applications;
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 18, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Review applications, verify documents, and manage scholarship programs.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 22),
            _StatsGrid(app: app, wide: wide),
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _StatusChart(app: app)),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: _ProgramBreakdown(app: app)),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusChart(app: app),
                  const SizedBox(height: 20),
                  _ProgramBreakdown(app: app),
                ],
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 240,
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            hintText: 'Search applicant, ID, program…',
                            prefixIcon: Icon(Icons.search_rounded, size: 20),
                            isDense: true,
                          ),
                        ),
                      ),
                      _FilterChip(label: 'All', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                      for (final s in ApplicationStatus.values)
                        _FilterChip(
                          label: s.label,
                          selected: _filter == s,
                          onTap: () => setState(() => _filter = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text('No applications match your filter.', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    for (final a in list) ...[
                      _ApplicantRow(app: a),
                      if (a != list.last) const Divider(height: 22),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final AppState app;
  final bool wide;

  const _StatsGrid({required this.app, required this.wide});

  @override
  Widget build(BuildContext context) {
    final items = [
      StatCard(
        label: 'Total Applicants',
        value: '${app.applications.length}',
        icon: Icons.groups_rounded,
        color: AppColors.primary,
      ),
      StatCard(
        label: 'Pending Review',
        value: '${app.countByStatus(ApplicationStatus.submitted) + app.countByStatus(ApplicationStatus.documentVerification) + app.countByStatus(ApplicationStatus.underReview)}',
        icon: Icons.hourglass_top_rounded,
        color: AppColors.warning,
      ),
      StatCard(
        label: 'Approved',
        value: '${app.countByStatus(ApplicationStatus.approved)}',
        icon: Icons.verified_rounded,
        color: AppColors.success,
      ),
      StatCard(
        label: 'Rejected',
        value: '${app.countByStatus(ApplicationStatus.rejected)}',
        icon: Icons.cancel_rounded,
        color: AppColors.danger,
      ),
      StatCard(
        label: 'Funds Disbursed',
        value: '₱${app.totalDisbursed.toStringAsFixed(0)}',
        icon: Icons.payments_rounded,
        color: AppColors.accentDark,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final columns = wide ? 5 : 2;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items) SizedBox(width: cardWidth, child: item),
          ],
        );
      },
    );
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

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(20, 20, 24, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Applications by Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 18),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: (maxVal + 2).toDouble(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= statuses.length) return const SizedBox.shrink();
                        final label = statuses[i].label.split(' ').first;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
    );
  }
}

class _ProgramBreakdown extends StatelessWidget {
  final AppState app;

  const _ProgramBreakdown({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Slot Utilization', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
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
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${s.slotsFilled}/${s.totalSlots}',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        value: s.fillRatio,
                        minHeight: 6,
                        backgroundColor: AppColors.neutralBg,
                        valueColor: AlwaysStoppedAnimation(AppColors.accent),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.neutralBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ApplicantRow extends StatelessWidget {
  final ScholarshipApplication app;

  const _ApplicantRow({required this.app});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 700;
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            app.studentName.split(' ').map((e) => e[0]).take(2).join(),
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(app.studentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(app.id, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
        if (wide)
          Expanded(
            flex: 3,
            child: Text(
              app.scholarshipTitle,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (wide)
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('MMM d, y').format(app.dateSubmitted),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        Expanded(flex: 2, child: StatusChip(status: app.status, compact: true)),
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 20),
          onPressed: () => _openReview(context, app),
        ),
      ],
    );
  }

  void _openReview(BuildContext context, ScholarshipApplication app) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ReviewDialog(app: app),
    );
  }
}

class _ReviewDialog extends StatelessWidget {
  final ScholarshipApplication app;

  const _ReviewDialog({required this.app});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusChip(status: app.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${app.id} • ${app.scholarshipTitle}',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              const Text('Document Verification', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 10),
              for (final d in app.documents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(d.name, style: const TextStyle(fontSize: 12.5))),
                      Flexible(child: DocMatchBadge(status: d.matchStatus, note: d.matchNote)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger)),
                      onPressed: () {
                        appState.updateApplicationStatus(app.id, ApplicationStatus.rejected);
                        Navigator.pop(context);
                      },
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: () {
                        appState.updateApplicationStatus(app.id, ApplicationStatus.approved);
                        Navigator.pop(context);
                      },
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
}
