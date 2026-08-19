import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/application.dart';
import '../models/scholarship.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_panel.dart';
import '../widgets/scholarship_card.dart';

const _stepTitles = ['Scholarship', 'Applicant Info', 'Documents', 'Review'];

/// Per-scholarship application-in-progress: its own step, its own form
/// values, its own document list. Kept in a map keyed by scholarship id so a
/// student can have several of these open at once (apply to multiple
/// programs in parallel without losing progress on any of them).
class _ApplicationDraft {
  final Scholarship scholarship;
  int step = 0;
  final formKey = GlobalKey<FormState>();
  final fullName = TextEditingController();
  final courseYear = TextEditingController();
  final contact = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final guardian = TextEditingController();
  final income = TextEditingController();
  final gwa = TextEditingController();
  late final List<DocumentItem> docs = scholarship.requirements
      .map((r) => DocumentItem(name: r))
      .toList();

  _ApplicationDraft({required this.scholarship});

  void dispose() {
    for (final c in [
      fullName,
      courseYear,
      contact,
      email,
      address,
      guardian,
      income,
      gwa,
    ]) {
      c.dispose();
    }
  }
}

class ScholarshipApplicationScreen extends StatefulWidget {
  const ScholarshipApplicationScreen({super.key});

  @override
  State<ScholarshipApplicationScreen> createState() =>
      _ScholarshipApplicationScreenState();
}

class _ScholarshipApplicationScreenState
    extends State<ScholarshipApplicationScreen> {
  String? _activeId;
  final Map<String, _ApplicationDraft> _drafts = {};

  @override
  void dispose() {
    for (final d in _drafts.values) {
      d.dispose();
    }
    super.dispose();
  }

  _ApplicationDraft _draftFor(Scholarship s) =>
      _drafts.putIfAbsent(s.id, () => _ApplicationDraft(scholarship: s));

  Scholarship? _findScholarship(AppState app, String id) {
    for (final s in app.scholarships) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _openScholarship(Scholarship s) {
    _draftFor(s);
    setState(() => _activeId = s.id);
  }

  void _exitToGrid() => setState(() => _activeId = null);

  void _discardDraft(String id) => _drafts.remove(id)?.dispose();

  void _showDetails(BuildContext context, Scholarship s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScholarshipDetailSheet(
        scholarship: s,
        onApply: () {
          Navigator.pop(context);
          _openScholarship(s);
        },
      ),
    );
  }

  bool _canProceedFromInfo(_ApplicationDraft draft) =>
      draft.formKey.currentState?.validate() ?? false;

  bool _canProceedFromDocs(_ApplicationDraft draft) =>
      draft.docs.every((d) => d.uploaded);

  Future<void> _pickFile(_ApplicationDraft draft, DocumentItem doc) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() {
        doc.uploaded = true;
        doc.fileName = result.files.single.name;
        doc.bytes = result.files.single.bytes;
      });
    } catch (_) {
      setState(() {
        doc.uploaded = true;
        doc.fileName = 'document.pdf';
      });
    }
  }

  void _next(_ApplicationDraft draft) {
    if (draft.step == 1 && !_canProceedFromInfo(draft)) return;
    if (draft.step == 2 && !_canProceedFromDocs(draft)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required documents.')),
      );
      return;
    }
    if (draft.step == 3) {
      _submit(draft);
      return;
    }
    setState(() => draft.step++);
  }

  void _back(_ApplicationDraft draft) {
    if (draft.step == 0) return;
    setState(() => draft.step--);
  }

  /// Fills Applicant Info from the student's saved Profile Settings.
  /// Deliberately leaves Household Monthly Income and GWA untouched — those
  /// change per application and are always typed in manually.
  void _autoFillFromProfile(AppState app, _ApplicationDraft draft) {
    setState(() {
      draft.fullName.text = app.user.fullName;
      draft.courseYear.text = app.user.course;
      draft.contact.text = app.user.contactNumber;
      draft.email.text = app.user.email;
      draft.address.text = app.user.address;
      draft.guardian.text = app.user.guardianName;
    });
  }

  void _clearApplicantInfo(_ApplicationDraft draft) {
    setState(() {
      draft.fullName.clear();
      draft.courseYear.clear();
      draft.contact.clear();
      draft.email.clear();
      draft.address.clear();
      draft.guardian.clear();
    });
  }

  void _submit(_ApplicationDraft draft) {
    final app = context.read<AppState>();
    final scholarshipTitle = draft.scholarship.title;
    app.submitApplication(
      scholarship: draft.scholarship,
      applicantFullName: draft.fullName.text.trim(),
      documents: draft.docs,
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            const Text('Application Submitted'),
          ],
        ),
        content: Text(
          'Your application to "$scholarshipTitle" has been submitted. '
          'Your documents are now being auto-checked against your student records. '
          'Track its progress in the Application Tracker tab.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _discardDraft(draft.scholarship.id);
              _exitToGrid();
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= 900;
    final active = _activeId == null ? null : _findScholarship(app, _activeId!);

    return AmbientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 32 : 18,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _activeId != null ? 760 : 1180,
              ),
              child: active != null
                  ? _buildFlow(app, active)
                  : (_activeId != null
                        ? _buildMissingScholarship()
                        : _buildGrid(app)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissingScholarship() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This scholarship is no longer available.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'The program may have been removed by the scholarship office.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            if (_activeId != null) _discardDraft(_activeId!);
            _exitToGrid();
          },
          child: const Text('Back to Scholarships'),
        ),
      ],
    );
  }

  Widget _buildGrid(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scholarship Application',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Browse open programs and apply to as many as you\'d like — each keeps its own progress.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 22),
        if (app.scholarships.isEmpty)
          SizedBox(
            width: double.infinity,
            child: GlassPanel(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No scholarship programs are open right now. Check back soon.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 16.0;
              const minCardWidth = 280.0;
              final columns = (constraints.maxWidth / (minCardWidth + spacing))
                  .floor()
                  .clamp(1, 3);
              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final s in app.scholarships)
                    SizedBox(
                      width: cardWidth,
                      child: _BrowseCard(
                        scholarship: s,
                        alreadyApplied: app.myApplications.any(
                          (a) => a.scholarshipTitle == s.title,
                        ),
                        draftStep: _drafts[s.id]?.step,
                        onApply: () => _openScholarship(s),
                        onViewDetails: () => _showDetails(context, s),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildFlow(AppState app, Scholarship scholarship) {
    final draft = _draftFor(scholarship);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _exitToGrid,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Back to Scholarships'),
        ),
        const SizedBox(height: 10),
        Text(
          'Applying to ${scholarship.title}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Complete the steps below to submit your application.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _StepIndicator(step: draft.step),
        const SizedBox(height: 24),
        GlassPanel(
          padding: const EdgeInsets.all(22),
          strong: true,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildStepContent(app, draft),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            if (draft.step > 0)
              OutlinedButton(
                onPressed: () => _back(draft),
                child: const Text('Back'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: () => _next(draft),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
              ),
              child: Text(draft.step == 3 ? 'Submit Application' : 'Continue'),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStepContent(AppState app, _ApplicationDraft draft) {
    switch (draft.step) {
      case 0:
        return _ScholarshipRecap(
          key: const ValueKey(0),
          scholarship: draft.scholarship,
        );
      case 1:
        return _ApplicantInfoForm(
          key: const ValueKey(1),
          formKey: draft.formKey,
          fullName: draft.fullName,
          courseYear: draft.courseYear,
          contact: draft.contact,
          email: draft.email,
          address: draft.address,
          guardian: draft.guardian,
          income: draft.income,
          gwa: draft.gwa,
          hasProfileDetails: app.user.hasProfileDetails,
          onAutoFill: () => _autoFillFromProfile(app, draft),
          onClear: () => _clearApplicantInfo(draft),
        );
      case 2:
        return _DocumentUploader(
          key: const ValueKey(2),
          docs: draft.docs,
          onPick: (d) => _pickFile(draft, d),
        );
      default:
        return _ReviewStep(
          key: const ValueKey(3),
          scholarship: draft.scholarship,
          fullName: draft.fullName.text,
          courseYear: draft.courseYear.text,
          contact: draft.contact.text,
          email: draft.email.text,
          docs: draft.docs,
        );
    }
  }
}

class _BrowseCard extends StatelessWidget {
  final Scholarship scholarship;
  final bool alreadyApplied;
  final int? draftStep;
  final VoidCallback onApply;
  final VoidCallback onViewDetails;

  const _BrowseCard({
    required this.scholarship,
    required this.alreadyApplied,
    required this.draftStep,
    required this.onApply,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (alreadyApplied || draftStep != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _statusBadge(),
          ),
        ScholarshipCard(
          scholarship: scholarship,
          onApply: onApply,
          onTap: onViewDetails,
        ),
      ],
    );
  }

  Widget _statusBadge() {
    final label = alreadyApplied
        ? 'Already applied'
        : 'Draft • Step ${draftStep! + 1} of 4';
    final color = alreadyApplied ? AppColors.success : AppColors.info;
    final bg = alreadyApplied ? AppColors.successBg : AppColors.infoBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            alreadyApplied
                ? Icons.check_circle_rounded
                : Icons.edit_note_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScholarshipDetailSheet extends StatelessWidget {
  final Scholarship scholarship;
  final VoidCallback onApply;

  const _ScholarshipDetailSheet({
    required this.scholarship,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    return SafeArea(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: GlassPanel(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(24),
            strong: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          s.category.icon,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.provider,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    s.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _stat('Amount', '₱${s.amount.toStringAsFixed(0)}'),
                      _stat('Slots left', '${s.slotsLeft} / ${s.totalSlots}'),
                      _stat(
                        'Deadline',
                        DateFormat('MMM d, y').format(s.deadline),
                      ),
                      _stat('Category', s.category.label),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Requirements',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  for (final r in s.requirements)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 15,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: s.slotsLeft == 0 ? null : onApply,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        s.slotsLeft == 0 ? 'Slots Full' : 'Apply Now',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;

  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _stepTitles.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= step
                                  ? AppColors.primary
                                  : AppColors.border),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= step
                            ? AppColors.primary
                            : AppColors.neutralBg,
                        border: Border.all(
                          color: i <= step
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: i < step
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: i == step
                                    ? Colors.white
                                    : AppColors.textMuted,
                              ),
                            ),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == _stepTitles.length - 1
                            ? Colors.transparent
                            : (i < step ? AppColors.primary : AppColors.border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _stepTitles[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                    color: i == step ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ScholarshipRecap extends StatelessWidget {
  final Scholarship scholarship;

  const _ScholarshipRecap({super.key, required this.scholarship});

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scholarship program',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 14),
        Row(
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
                      fontSize: 15,
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
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          s.description,
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 22,
          runSpacing: 10,
          children: [
            _stat('Amount', '₱${s.amount.toStringAsFixed(0)}'),
            _stat('Slots left', '${s.slotsLeft} / ${s.totalSlots}'),
            _stat('Deadline', DateFormat('MMM d, y').format(s.deadline)),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Documents you\'ll need to upload',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        for (final r in s.requirements)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r, style: const TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ApplicantInfoForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullName;
  final TextEditingController courseYear;
  final TextEditingController contact;
  final TextEditingController email;
  final TextEditingController address;
  final TextEditingController guardian;
  final TextEditingController income;
  final TextEditingController gwa;
  final bool hasProfileDetails;
  final VoidCallback onAutoFill;
  final VoidCallback onClear;

  const _ApplicantInfoForm({
    super.key,
    required this.formKey,
    required this.fullName,
    required this.courseYear,
    required this.contact,
    required this.email,
    required this.address,
    required this.guardian,
    required this.income,
    required this.gwa,
    required this.hasProfileDetails,
    required this.onAutoFill,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 480;
    return Form(
      key: formKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Applicant information',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            hasProfileDetails
                ? 'Pull your saved details from Profile Settings, or clear the form and type them in yourself.'
                : 'No saved Profile details yet — fill in manually below, or save them once in the Profile tab to auto-fill next time.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: hasProfileDetails ? onAutoFill : null,
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Auto-fill from Profile'),
              ),
              OutlinedButton.icon(
                onPressed: onClear,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _field('Full Name', fullName),
          _field(
            'Course & Year Level',
            courseYear,
            hint: 'e.g. BS Information Technology - 3rd Year',
          ),
          _fieldPair(
            narrow,
            _field(
              'Contact Number',
              contact,
              keyboardType: TextInputType.phone,
            ),
            _field(
              'Email Address',
              email,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          _field('Complete Address', address),
          _fieldPair(
            narrow,
            _field('Parent / Guardian Name', guardian),
            _field(
              'Household Monthly Income',
              income,
              keyboardType: TextInputType.number,
            ),
          ),
          _field(
            'General Weighted Average (GWA)',
            gwa,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _fieldPair(bool narrow, Widget a, Widget b) {
    if (narrow) {
      return Column(children: [a, b]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _DocumentUploader extends StatelessWidget {
  final List<DocumentItem> docs;
  final ValueChanged<DocumentItem> onPick;

  const _DocumentUploader({
    super.key,
    required this.docs,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload required documents',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          'Accepted formats: PDF, JPG, PNG. Files will be auto-checked against your student records.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        for (final d in docs)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.neutralBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  d.uploaded
                      ? Icons.description_rounded
                      : Icons.upload_file_rounded,
                  color: d.uploaded ? AppColors.success : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (d.uploaded)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            d.fileName ?? '',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => onPick(d),
                  child: Text(d.uploaded ? 'Replace' : 'Upload'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  final Scholarship scholarship;
  final String fullName;
  final String courseYear;
  final String contact;
  final String email;
  final List<DocumentItem> docs;

  const _ReviewStep({
    super.key,
    required this.scholarship,
    required this.fullName,
    required this.courseYear,
    required this.contact,
    required this.email,
    required this.docs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review your application',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 14),
        _row('Scholarship', scholarship.title),
        _row('Full Name', fullName),
        _row('Course & Year', courseYear),
        _row('Contact', contact),
        _row('Email', email),
        const SizedBox(height: 10),
        const Text(
          'Documents',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        for (final d in docs)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(d.name, style: const TextStyle(fontSize: 12.5)),
                ),
                Text(
                  d.fileName ?? '',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_rounded, size: 16, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'By submitting, you confirm all information and documents provided are true and correct.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
