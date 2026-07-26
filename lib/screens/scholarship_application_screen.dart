import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/application.dart';
import '../models/scholarship.dart';
import '../theme/app_colors.dart';

class ScholarshipApplicationScreen extends StatefulWidget {
  const ScholarshipApplicationScreen({super.key});

  @override
  State<ScholarshipApplicationScreen> createState() =>
      _ScholarshipApplicationScreenState();
}

const _stepTitles = ['Scholarship', 'Applicant Info', 'Documents', 'Review'];

class _ScholarshipApplicationScreenState
    extends State<ScholarshipApplicationScreen> {
  int _step = 0;
  Scholarship? _selected;
  List<DocumentItem> _docs = [];

  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _courseYear = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _guardian = TextEditingController();
  final _income = TextEditingController();
  final _gwa = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _courseYear,
      _contact,
      _email,
      _address,
      _guardian,
      _income,
      _gwa,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectScholarship(Scholarship s) {
    setState(() {
      _selected = s;
      _docs = s.requirements.map((r) => DocumentItem(name: r)).toList();
    });
  }

  Future<void> _pickFile(DocumentItem doc) async {
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

  bool get _canProceedFromInfo => _formKey.currentState?.validate() ?? false;

  bool get _canProceedFromDocs => _docs.every((d) => d.uploaded);

  void _next() {
    if (_step == 0 && _selected == null) return;
    if (_step == 1 && !_canProceedFromInfo) return;
    if (_step == 2 && !_canProceedFromDocs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required documents.')),
      );
      return;
    }
    if (_step == 3) {
      _submit();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  void _submit() {
    final app = context.read<AppState>();
    final id =
        'APP-2026-${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}';
    app.submitApplication(
      ScholarshipApplication(
        id: id,
        scholarshipTitle: _selected!.title,
        studentName: app.studentName,
        studentNumber: app.studentNumber,
        dateSubmitted: DateTime.now(),
        status: ApplicationStatus.submitted,
        documents: _docs,
        messages: const [],
        applicantFullName: _fullName.text.trim(),
      ),
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
          'Your application to "${_selected!.title}" ($id) has been submitted. '
          'Your documents are now being auto-checked against your student records. '
          'Track its progress in the Application Tracker tab.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _step = 0;
                _selected = null;
                _docs = [];
                _formKey.currentState?.reset();
              });
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 18, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scholarship Application',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete the steps below to submit your application.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                _StepIndicator(step: _step),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildStep(app),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_step > 0)
                      OutlinedButton(onPressed: _back, child: const Text('Back')),
                    const Spacer(),
                    FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      ),
                      child: Text(_step == 3 ? 'Submit Application' : 'Continue'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(AppState app) {
    switch (_step) {
      case 0:
        return _ScholarshipPicker(
          key: const ValueKey(0),
          scholarships: app.scholarships,
          selected: _selected,
          onSelect: _selectScholarship,
        );
      case 1:
        return _ApplicantInfoForm(
          key: const ValueKey(1),
          formKey: _formKey,
          fullName: _fullName,
          courseYear: _courseYear,
          contact: _contact,
          email: _email,
          address: _address,
          guardian: _guardian,
          income: _income,
          gwa: _gwa,
          initialName: app.studentName,
        );
      case 2:
        return _DocumentUploader(
          key: const ValueKey(2),
          docs: _docs,
          onPick: _pickFile,
        );
      default:
        return _ReviewStep(
          key: const ValueKey(3),
          scholarship: _selected,
          fullName: _fullName.text,
          courseYear: _courseYear.text,
          contact: _contact.text,
          email: _email.text,
          docs: _docs,
        );
    }
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
                            : (i <= step ? AppColors.primary : AppColors.border),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= step ? AppColors.primary : AppColors.neutralBg,
                        border: Border.all(
                          color: i <= step ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: i < step
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: i == step ? Colors.white : AppColors.textMuted,
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

class _ScholarshipPicker extends StatelessWidget {
  final List<Scholarship> scholarships;
  final Scholarship? selected;
  final ValueChanged<Scholarship> onSelect;

  const _ScholarshipPicker({
    super.key,
    required this.scholarships,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select a scholarship program', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 14),
        for (final s in scholarships)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: s.slotsLeft == 0 ? null : () => onSelect(s),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected?.id == s.id ? AppColors.primary.withValues(alpha: 0.06) : AppColors.neutralBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected?.id == s.id ? AppColors.primary : AppColors.border,
                    width: selected?.id == s.id ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(s.category.icon, color: AppColors.primary, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          const SizedBox(height: 2),
                          Text(
                            '${s.provider} • ₱${s.amount.toStringAsFixed(0)} • ${s.slotsLeft} slots left',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (s.slotsLeft == 0)
                      Text('Full', style: TextStyle(color: AppColors.danger, fontSize: 11.5, fontWeight: FontWeight.w700))
                    else
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected?.id == s.id ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: selected?.id == s.id ? AppColors.primary : AppColors.textMuted,
                            width: 1.6,
                          ),
                        ),
                        child: selected?.id == s.id
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                  ],
                ),
              ),
            ),
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
  final String initialName;

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
    required this.initialName,
  });

  @override
  Widget build(BuildContext context) {
    if (fullName.text.isEmpty) fullName.text = initialName;
    final narrow = MediaQuery.of(context).size.width < 480;
    return Form(
      key: formKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Applicant information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 14),
          _field('Full Name', fullName),
          _field('Course & Year Level', courseYear, hint: 'e.g. BS Information Technology - 3rd Year'),
          _fieldPair(
            narrow,
            _field('Contact Number', contact, keyboardType: TextInputType.phone),
            _field('Email Address', email, keyboardType: TextInputType.emailAddress),
          ),
          _field('Complete Address', address),
          _fieldPair(
            narrow,
            _field('Parent / Guardian Name', guardian),
            _field('Household Monthly Income', income, keyboardType: TextInputType.number),
          ),
          _field('General Weighted Average (GWA)', gwa, keyboardType: TextInputType.number),
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

  const _DocumentUploader({super.key, required this.docs, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upload required documents', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
                  d.uploaded ? Icons.description_rounded : Icons.upload_file_rounded,
                  color: d.uploaded ? AppColors.success : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (d.uploaded)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            d.fileName ?? '',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
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
  final Scholarship? scholarship;
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
        const Text('Review your application', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 14),
        _row('Scholarship', scholarship?.title ?? '-'),
        _row('Full Name', fullName),
        _row('Course & Year', courseYear),
        _row('Contact', contact),
        _row('Email', email),
        const SizedBox(height: 10),
        const Text('Documents', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        for (final d in docs)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(child: Text(d.name, style: const TextStyle(fontSize: 12.5))),
                Text(d.fileName ?? '', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
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
            child: Text(label, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
