import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/app_user.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_panel.dart';

/// Lets a student save reusable applicant details once, so the Apply form's
/// "Auto-fill from Profile" button has something to pull from. Deliberately
/// excludes household income and GWA — those change per application and are
/// always typed in manually on the Apply form.
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _studentNumber;
  late final TextEditingController _course;
  late final TextEditingController _contact;
  late final TextEditingController _address;
  late final TextEditingController _guardian;

  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _studentNumber,
      _course,
      _contact,
      _address,
      _guardian,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadFrom(AppUser user) {
    _fullName = TextEditingController(text: user.fullName);
    _studentNumber = TextEditingController(text: user.studentNumber);
    _course = TextEditingController(text: user.course);
    _contact = TextEditingController(text: user.contactNumber);
    _address = TextEditingController(text: user.address);
    _guardian = TextEditingController(text: user.guardianName);
    _initialized = true;
    for (final c in [
      _fullName,
      _studentNumber,
      _course,
      _contact,
      _address,
      _guardian,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  int get _filledCount => [
    _fullName.text,
    _studentNumber.text,
    _course.text,
    _contact.text,
    _address.text,
    _guardian.text,
  ].where((v) => v.trim().isNotEmpty).length;

  static const _fieldTotal = 6;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final updated = appState.user.copyWith(
      fullName: _fullName.text.trim(),
      studentNumber: _studentNumber.text.trim(),
      course: _course.text.trim(),
      contactNumber: _contact.text.trim(),
      address: _address.text.trim(),
      guardianName: _guardian.text.trim(),
    );
    try {
      await appState.updateProfile(updated);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your profile. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!_initialized) _loadFrom(app.user);
    final wide = MediaQuery.of(context).size.width >= 900;
    final narrow = MediaQuery.of(context).size.width < 480;
    final initials = _fullName.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join()
        .toUpperCase();
    final completeness = _filledCount / _fieldTotal;

    return AmbientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 32 : 18,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Save your details once and use "Auto-fill from Profile" on the Apply form instead of retyping them every time.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // --- Identity header: avatar + completeness meter -------
                  GlassPanel(
                    padding: const EdgeInsets.all(22),
                    strong: true,
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: AppColors.heroGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials.isEmpty ? '?' : initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _fullName.text.trim().isEmpty
                                    ? 'Your Name'
                                    : _fullName.text.trim(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                app.user.email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: LinearProgressIndicator(
                                        value: completeness,
                                        minHeight: 6,
                                        backgroundColor: AppColors.neutralBg,
                                        valueColor: AlwaysStoppedAnimation(
                                          completeness >= 1
                                              ? AppColors.success
                                              : AppColors.accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '$_filledCount/$_fieldTotal',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // --- Form -------------------------------------------------
                  GlassPanel(
                    padding: const EdgeInsets.all(22),
                    strong: true,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(
                            Icons.badge_outlined,
                            'Personal Information',
                          ),
                          const SizedBox(height: 14),
                          _readOnlyField('Email', app.user.email),
                          _field('Full Name', _fullName, required: true),
                          _field('Student Number', _studentNumber),
                          _field(
                            'Course & Year Level',
                            _course,
                            hint: 'e.g. BS Information Technology - 3rd Year',
                          ),
                          const SizedBox(height: 8),
                          Divider(color: AppColors.border),
                          const SizedBox(height: 16),
                          _sectionLabel(
                            Icons.contact_phone_outlined,
                            'Contact Details',
                          ),
                          const SizedBox(height: 14),
                          _fieldPair(
                            narrow,
                            _field(
                              'Contact Number',
                              _contact,
                              keyboardType: TextInputType.phone,
                            ),
                            _field('Parent / Guardian Name', _guardian),
                          ),
                          _field('Complete Address', _address, maxLines: 2),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.infoBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_rounded,
                                  size: 16,
                                  color: AppColors.info,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Household Monthly Income and GWA aren\'t saved here since they '
                                    'usually change between applications — you\'ll always type those '
                                    'in directly on the Apply form.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.info,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: FilledButton(
                                onPressed: _saving ? null : _save,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 16,
                                  ),
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
                                    : const Text('Save Profile'),
                              ),
                            ),
                          ),
                        ],
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

  Widget _sectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _fieldPair(bool narrow, Widget a, Widget b) {
    if (narrow) return Column(children: [a, b]);
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
    int maxLines = 1,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        enabled: false,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
