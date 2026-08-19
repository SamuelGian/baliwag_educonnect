import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/announcement.dart';
import '../models/application.dart';
import '../models/scholarship.dart';
import '../theme/app_colors.dart';
import '../widgets/doc_match_badge.dart';
import '../widgets/glass_panel.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_chip.dart';

// The three Admin sections below (Applications, Scholarships, Announcements)
// are hosted directly by AdminShell's nav rail / bottom nav (mirroring the
// Student shell), rather than by an internal TabBar — see admin_shell.dart.

// ============================================================================
// Applications tab (review + approve/reject)
// ============================================================================

class ApplicationsTab extends StatefulWidget {
  const ApplicationsTab({super.key});

  @override
  State<ApplicationsTab> createState() => ApplicationsTabState();
}

class ApplicationsTabState extends State<ApplicationsTab> {
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

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 18, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Dashboard',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
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
          GlassPanel(
            padding: const EdgeInsets.all(20),
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
                    _FilterChip(
                      label: 'All',
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
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
                      child: Text(
                        'No applications match your filter.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
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
        value:
            '${app.countByStatus(ApplicationStatus.submitted) + app.countByStatus(ApplicationStatus.documentVerification) + app.countByStatus(ApplicationStatus.underReview)}',
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
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
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
                          color: AppColors.textSecondary,
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
                                    color: AppColors.textSecondary,
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
                                backgroundColor: AppColors.neutralBg,
                                valueColor: AlwaysStoppedAnimation(
                                  AppColors.accent,
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
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
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
          color: selected ? AppColors.primary : AppColors.neutralBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
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
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.studentName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                app.id,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
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
    final appState = context.read<AppState>();
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: _ReviewDialog(app: app),
      ),
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
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Document Verification',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 10),
              for (final d in app.documents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.name,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      Flexible(
                        child: DocMatchBadge(
                          status: d.matchStatus,
                          note: d.matchNote,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: BorderSide(color: AppColors.danger),
                      ),
                      onPressed: () {
                        appState.updateApplicationStatus(
                          app.id,
                          ApplicationStatus.rejected,
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      onPressed: () {
                        appState.updateApplicationStatus(
                          app.id,
                          ApplicationStatus.approved,
                        );
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

// ============================================================================
// Scholarships tab — full CRUD (Create / Read / Update / Delete)
// ============================================================================

class ScholarshipsTab extends StatefulWidget {
  const ScholarshipsTab({super.key});

  @override
  State<ScholarshipsTab> createState() => ScholarshipsTabState();
}

class ScholarshipsTabState extends State<ScholarshipsTab> {
  bool _seeding = false;

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
    final wide = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 18, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Scholarships',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create, edit, or remove scholarship programs. Changes appear for students instantly.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Scholarship'),
              ),
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
                      'No scholarship programs yet. Tap "Add Scholarship" to create one,\nor load a few ready-made programs to get started quickly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
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
                ),
              ),
            )
          else
            for (final s in app.scholarships) ...[
              _ScholarshipAdminCard(scholarship: s),
              const SizedBox(height: 14),
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
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.category.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  s.provider,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
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
                      Icons.groups_rounded,
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
              color: AppColors.danger,
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
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Scholarship s) {
    final appState = context.read<AppState>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete scholarship?'),
        content: Text(
          'This will permanently remove "${s.title}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
  late final TextEditingController _requirements;
  late ScholarshipCategory _category;
  late DateTime _deadline;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _provider = TextEditingController(text: e?.provider ?? '');
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
    _requirements = TextEditingController(
      text: e != null ? e.requirements.join('\n') : '',
    );
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
      _requirements,
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final requirements = _requirements.text
        .split('\n')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();
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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
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
                        _field('Provider', _provider),
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
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                    ),
                                    items: [
                                      for (final c
                                          in ScholarshipCategory.values)
                                        DropdownMenuItem(
                                          value: c,
                                          child: Text(c.label),
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
                        _field(
                          'Requirements (one per line)',
                          _requirements,
                          maxLines: 4,
                          hint:
                              'Certificate of Enrollment\nCertificate of Indigency',
                        ),
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
                          backgroundColor: AppColors.primary,
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

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool numeric = false,
    int? min,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
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
    final wide = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 18, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Announcements',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Post updates that students see on their dashboard.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Announcement'),
              ),
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
                    style: TextStyle(color: AppColors.textSecondary),
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
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${a.type.label} • ${DateFormat('MMM d, y').format(a.date)}',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
              color: AppColors.danger,
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
                        backgroundColor: AppColors.danger,
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
        constraints: const BoxConstraints(maxWidth: 460),
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
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _body,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<AnnouncementType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in AnnouncementType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) => setState(() => _type = v!),
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
                          backgroundColor: AppColors.primary,
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
