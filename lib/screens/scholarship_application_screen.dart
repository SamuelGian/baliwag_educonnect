import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../data/document_upload_limits.dart';
import '../models/application.dart';
import '../models/scholarship.dart';
import '../services/document_gate_service.dart';
import '../services/file_signature_validator.dart';
import '../services/image_compression_service.dart';
import '../theme/app_theme_context.dart';
import '../theme/breakpoints.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_panel.dart';
import '../widgets/local_file_preview_dialog.dart';
import '../widgets/scholarship_card.dart';

const _stepTitles = ['Scholarship', 'Applicant Info', 'Documents', 'Review'];

/// Per-scholarship application-in-progress: its own step, its own form
/// values, its own document list. Kept in a map keyed by scholarship id so a
/// student can have several of these open at once (apply to multiple
/// programs in parallel without losing progress on any of them).
class _ApplicationDraft {
  final Scholarship scholarship;
  int step = 0;
  bool submitting = false;
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

  /// Names of documents currently being checked by [DocumentGateService] —
  /// drives the "Checking…" state on their upload tile (see
  /// _DocumentUploader) while the Gemini call for that specific document is
  /// in flight.
  final Set<String> checkingDocs = {};

  /// Keyed by document name: the most recent [DocumentGateService]
  /// rejection reason for that document, if its last pick attempt was
  /// turned away. Shown as a persistent note on the upload tile (see
  /// _DocumentUploader) — not just the transient SnackBar shown at the
  /// moment of rejection, which is easy to miss. Cleared the moment that
  /// document is successfully uploaded.
  final Map<String, String> gateRejections = {};

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
  final _gateService = DocumentGateService();

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

  void _showDetails(BuildContext context, AppState app, Scholarship s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScholarshipDetailSheet(
        scholarship: s,
        block: app.blockReasonFor(s),
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
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.single;
      var bytes = file.bytes;
      var fileName = file.name;
      // The file picker's allowedExtensions filter only looks at the
      // filename — it never verifies what's actually inside. Checking the
      // magic bytes here catches a mismatched/renamed file before it gets
      // anywhere near storage or OCR.
      if (bytes != null && !looksLikeAcceptedDocument(bytes)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "This file doesn't look like a valid PDF, JPG, or PNG. "
              'Please choose a different file.',
            ),
          ),
        );
        return;
      }
      if (bytes != null &&
          !await _passesDocumentGate(draft: draft, doc: doc, bytes: bytes, fileName: fileName)) {
        return;
      }
      if (!mounted) return;
      if (bytes != null && bytes.length > kMaxDocumentFileBytes) {
        final compressed = compressImageToFit(
          bytes,
          fileName,
          kMaxDocumentFileBytes,
        );
        bytes = compressed.bytes;
        fileName = compressed.fileName;
      }
      if (bytes != null && bytes.length > kMaxDocumentFileBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This file is too large even after compression (max ${(kMaxDocumentFileBytes / (1024 * 1024)).round()}MB). '
              'Please upload a smaller PDF or a lower-resolution photo.',
            ),
          ),
        );
        return;
      }
      setState(() {
        doc.uploaded = true;
        doc.fileName = fileName;
        doc.bytes = bytes;
        draft.gateRejections.remove(doc.name);
      });
    } catch (_) {
      setState(() {
        doc.uploaded = true;
        doc.fileName = 'document.pdf';
        draft.gateRejections.remove(doc.name);
      });
    }
  }

  /// Immediate pick-time gate: asks Gemini whether [bytes] actually looks
  /// like the kind of document [doc.name] asks for, before it's ever
  /// accepted into the draft. Shown as a "Checking…" state on the document's
  /// tile while it runs (see [_ApplicationDraft.checkingDocs]).
  ///
  /// Fails open on an infrastructure problem (missing key, network error,
  /// timeout) rather than blocking the applicant over an outage — same
  /// philosophy as the OCR pipeline's own exception handling, which falls
  /// back to "flagged for manual review" instead of erroring out. Only a
  /// confident "this isn't the right document" verdict blocks the upload.
  Future<bool> _passesDocumentGate({
    required _ApplicationDraft draft,
    required DocumentItem doc,
    required Uint8List bytes,
    required String fileName,
  }) async {
    setState(() => draft.checkingDocs.add(doc.name));
    try {
      final result = await _gateService
          .check(bytes: bytes, fileName: fileName, expectedDocumentName: doc.name)
          .timeout(const Duration(seconds: 30));
      if (!result.accepted) {
        final message =
            'This looks like ${result.detectedContent}, not "${doc.name}". '
            'Please upload the correct document.';
        setState(() => draft.gateRejections[doc.name] = message);
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        return false;
      }
      return true;
    } catch (e) {
      // Infrastructure failure, not a content verdict — let it through to
      // the existing OCR pipeline rather than blocking the applicant. Still
      // surfaced (not silent) so a persistent failure here is visible and
      // diagnosable instead of looking like the gate quietly approved it.
      debugPrint('Document gate check failed, letting file through: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not auto-verify this document right now — it will '
              'still be checked after you submit.',
            ),
          ),
        );
      }
      return true;
    } finally {
      if (mounted) setState(() => draft.checkingDocs.remove(doc.name));
    }
  }

  void _next(_ApplicationDraft draft) {
    if (draft.submitting) return;
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

  Future<void> _submit(_ApplicationDraft draft) async {
    // Was previously fire-and-forget: the "Application Submitted" success
    // dialog showed unconditionally, even if the Firestore write itself
    // failed (offline, blocked by a last-second deadline/slot check in
    // AppState.submitApplication, etc.) — a false-positive success message.
    // `submitting` also closes the double-submit window: the button below
    // disables for the duration of the call instead of staying tappable.
    final app = context.read<AppState>();
    final scholarshipTitle = draft.scholarship.title;
    setState(() => draft.submitting = true);
    try {
      await app.submitApplication(
        scholarship: draft.scholarship,
        applicantFullName: draft.fullName.text.trim(),
        documents: draft.docs,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => draft.submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError
                ? e.message
                : 'Could not submit your application. Please try again.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => draft.submitting = false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: context.appColors.success),
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
    final wide = MediaQuery.of(context).size.width >= kDesktopBreakpoint;
    final active = _activeId == null ? null : _findScholarship(app, _activeId!);

    return AmbientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          // Extra bottom clearance on narrow screens only, so page content
          // (and the final "Submit"/"Next" button) can scroll clear of the
          // floating GlassNavBar instead of ending up hidden under it.
          padding: EdgeInsets.fromLTRB(
            wide ? 32 : 18,
            24,
            wide ? 32 : 18,
            wide ? 24 : 120,
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
            color: context.appColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'The program may have been removed by the scholarship office.',
          style: TextStyle(
            fontSize: 13,
            color: context.appColors.textSecondary,
          ),
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
            color: context.appColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Browse open programs and apply to as many as you\'d like — each keeps its own progress.',
          style: TextStyle(
            fontSize: 13,
            color: context.appColors.textSecondary,
          ),
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
                  style: TextStyle(color: context.appColors.textSecondary),
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
                        block: app.blockReasonFor(s),
                        draftStep: _drafts[s.id]?.step,
                        onApply: () => _openScholarship(s),
                        onViewDetails: () => _showDetails(context, app, s),
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
            color: context.appColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Complete the steps below to submit your application.',
          style: TextStyle(
            fontSize: 13,
            color: context.appColors.textSecondary,
          ),
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
                onPressed: draft.submitting ? null : () => _back(draft),
                child: const Text('Back'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: draft.submitting ? null : () => _next(draft),
              style: FilledButton.styleFrom(
                backgroundColor: context.scheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
              ),
              child: draft.submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(draft.step == 3 ? 'Submit Application' : 'Continue'),
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
          checkingDocs: draft.checkingDocs,
          gateRejections: draft.gateRejections,
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

  /// Non-null when the student can't (re-)apply right now — see
  /// AppState.blockReasonFor. Disables the card's Apply button and shows
  /// the reason as a badge, instead of leaving it clickable and letting a
  /// duplicate application through.
  final ApplyBlock? block;
  final int? draftStep;
  final VoidCallback onApply;
  final VoidCallback onViewDetails;

  const _BrowseCard({
    required this.scholarship,
    required this.block,
    required this.draftStep,
    required this.onApply,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block != null || draftStep != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _statusBadge(context),
          ),
        ScholarshipCard(
          scholarship: scholarship,
          onApply: block == null ? onApply : null,
          applyLabel: block?.label,
          onTap: onViewDetails,
        ),
      ],
    );
  }

  Widget _statusBadge(BuildContext context) {
    final label = block?.label ?? 'Draft • Step ${draftStep! + 1} of 4';
    final (Color color, Color bg, IconData icon) = switch (block?.label) {
      null => (
        context.appColors.info,
        context.appColors.infoBg,
        Icons.edit_note_rounded,
      ),
      'Already Approved' => (
        context.appColors.success,
        context.appColors.successBg,
        Icons.check_circle_rounded,
      ),
      'Already Applied' => (
        context.appColors.info,
        context.appColors.infoBg,
        Icons.check_circle_rounded,
      ),
      _ => (
        context.appColors.warning,
        context.appColors.warningBg,
        Icons.info_rounded,
      ), // Deadline Passed, Slots Full
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
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
  final ApplyBlock? block;
  final VoidCallback onApply;

  const _ScholarshipDetailSheet({
    required this.scholarship,
    required this.block,
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
                        color: context.appColors.border,
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
                          color: context.scheme.primary.withValues(alpha: 0.1),
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
                                color: context.appColors.textSecondary,
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
                      color: context.appColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _stat(
                        context,
                        'Amount',
                        '₱${s.amount.toStringAsFixed(0)}',
                      ),
                      _stat(
                        context,
                        'Slots left',
                        '${s.slotsLeft} / ${s.totalSlots}',
                      ),
                      _stat(
                        context,
                        'Deadline',
                        DateFormat('MMM d, y').format(s.deadline),
                      ),
                      _stat(context, 'Category', s.category.label),
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
                            color: context.appColors.textMuted,
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
                      onPressed: block == null ? onApply : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: context.scheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(block == null ? 'Apply Now' : block!.label),
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

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.appColors.textMuted),
        ),
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
                                  ? context.scheme.primary
                                  : context.appColors.border),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= step
                            ? context.scheme.primary
                            : context.appColors.neutralBg,
                        border: Border.all(
                          color: i <= step
                              ? context.scheme.primary
                              : context.appColors.border,
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
                                    : context.appColors.textMuted,
                              ),
                            ),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == _stepTitles.length - 1
                            ? Colors.transparent
                            : (i < step
                                  ? context.scheme.primary
                                  : context.appColors.border),
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
                    color: i == step
                        ? context.scheme.primary
                        : context.appColors.textMuted,
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
                      color: context.appColors.textSecondary,
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
            color: context.appColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 22,
          runSpacing: 10,
          children: [
            _stat(context, 'Amount', '₱${s.amount.toStringAsFixed(0)}'),
            _stat(context, 'Slots left', '${s.slotsLeft} / ${s.totalSlots}'),
            _stat(
              context,
              'Deadline',
              DateFormat('MMM d, y').format(s.deadline),
            ),
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
                  color: context.appColors.textMuted,
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

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.appColors.textMuted),
        ),
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
            style: TextStyle(
              fontSize: 12,
              color: context.appColors.textSecondary,
            ),
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
                  foregroundColor: context.appColors.textSecondary,
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
  final Set<String> checkingDocs;
  final Map<String, String> gateRejections;
  final ValueChanged<DocumentItem> onPick;

  const _DocumentUploader({
    super.key,
    required this.docs,
    required this.checkingDocs,
    required this.gateRejections,
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
          style: TextStyle(
            fontSize: 12,
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        for (final d in docs)
          Builder(
            builder: (context) {
              final checking = checkingDocs.contains(d.name);
              return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appColors.neutralBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.appColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                checking
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: context.scheme.primary,
                        ),
                      )
                    : Icon(
                        d.uploaded
                            ? Icons.description_rounded
                            : Icons.upload_file_rounded,
                        color: d.uploaded
                            ? context.appColors.success
                            : context.appColors.textMuted,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.appColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (d.uploaded && d.bytes != null) ...[
                  IconButton(
                    tooltip: 'Preview',
                    icon: Icon(
                      Icons.visibility_outlined,
                      color: context.appColors.textSecondary,
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => LocalFilePreviewDialog(
                        bytes: d.bytes!,
                        fileName: d.fileName ?? d.name,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: checking ? null : () => onPick(d),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    checking ? 'Checking…' : (d.uploaded ? 'Replace' : 'Upload'),
                  ),
                ),
                  ],
                ),
                if (gateRejections[d.name] != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.appColors.dangerBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 16,
                            color: context.scheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              gateRejections[d.name]!,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.scheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
            },
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
        _row(context, 'Scholarship', scholarship.title),
        _row(context, 'Full Name', fullName),
        _row(context, 'Course & Year', courseYear),
        _row(context, 'Contact', contact),
        _row(context, 'Email', email),
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
                  color: context.appColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(d.name, style: const TextStyle(fontSize: 12.5)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  flex: 2,
                  child: Text(
                    d.fileName ?? '',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.appColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.appColors.infoBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_rounded, size: 16, color: context.appColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'By submitting, you confirm all information and documents provided are true and correct.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.appColors.info,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: context.appColors.textSecondary,
              ),
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
