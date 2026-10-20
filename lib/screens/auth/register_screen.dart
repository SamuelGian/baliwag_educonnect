import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme_context.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glass_panel.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

enum _RegisterRole { student, admin, provider }

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  _RegisterRole _role = _RegisterRole.student;

  final _fullName = TextEditingController();
  final _studentNumber = TextEditingController();
  final _course = TextEditingController();
  final _organizationName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _adminCode = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _studentNumber,
      _course,
      _organizationName,
      _email,
      _password,
      _confirmPassword,
      _adminCode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      switch (_role) {
        case _RegisterRole.student:
          await auth.registerStudent(
            email: _email.text,
            password: _password.text,
            fullName: _fullName.text,
            studentNumber: _studentNumber.text,
            course: _course.text,
          );
        case _RegisterRole.admin:
          await auth.registerAdmin(
            email: _email.text,
            password: _password.text,
            fullName: _fullName.text,
            accessCode: _adminCode.text,
          );
        case _RegisterRole.provider:
          await auth.registerProvider(
            email: _email.text,
            password: _password.text,
            organizationName: _organizationName.text,
            contactName: _fullName.text,
          );
      }
      // Sign the brand-new account back out immediately rather than
      // letting AuthGate auto-route straight into its dashboard: creating
      // the Firebase Auth account also signs it in, but the profile doc
      // above still needs a moment to land in Firestore — if AuthGate's
      // reactive routing beat that write, a freshly-registered user could
      // get bounced back to Login looking like a failure. Explicitly
      // signing out (after the write above is confirmed done, since it was
      // awaited) sidesteps that race entirely, and for Provider specifically
      // explains the "pending approval" status up front in a dialog the
      // user acknowledges, not as a surprise screen they land on.
      await auth.signOut();
      if (!mounted) return;
      await _showSuccessDialog();
      if (!mounted) return;
      Navigator.pop(context);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSuccessDialog() {
    final isProvider = _role == _RegisterRole.provider;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          Icons.check_circle_rounded,
          color: context.appColors.success,
          size: 36,
        ),
        title: const Text('Account created'),
        content: Text(
          isProvider
              ? 'Your organization account was created successfully. An '
                  "Admin needs to approve it before you can sign in — "
                  "you'll be able to sign in once that happens."
              : 'Your account was created successfully. You can now sign in.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Back to Sign In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = _role == _RegisterRole.student;
    final isProvider = _role == _RegisterRole.provider;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AmbientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: GlassPanel(
                padding: const EdgeInsets.all(24),
                strong: true,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RoleToggle(
                        role: _role,
                        onChanged: (r) => setState(() => _role = r),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.appColors.dangerBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_rounded,
                                size: 18,
                                color: context.scheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: context.scheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (isProvider) ...[
                        TextFormField(
                          controller: _organizationName,
                          decoration: const InputDecoration(
                            labelText: 'Organization Name',
                            hintText: 'e.g. TESDA Provincial Office',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _fullName,
                        decoration: InputDecoration(
                          labelText: isProvider ? 'Contact Person' : 'Full Name',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      if (isStudent) ...[
                        TextFormField(
                          controller: _studentNumber,
                          decoration: const InputDecoration(
                            labelText: 'Student Number',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _course,
                          decoration: const InputDecoration(
                            labelText: 'Course & Year Level',
                            hintText:
                                'e.g. BS Information Technology - 3rd Year',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'At least 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                        ),
                        validator: (v) => v != _password.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                      if (_role == _RegisterRole.admin) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _adminCode,
                          decoration: const InputDecoration(
                            labelText: 'Admin Access Code',
                            prefixIcon: Icon(Icons.vpn_key_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ],
                      if (isProvider) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.appColors.neutralBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 16,
                                color: context.appColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'An Admin needs to approve your organization '
                                  "before you can sign in and manage scholarships.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.appColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: context.scheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Create ${switch (_role) {
                                  _RegisterRole.student => 'Student',
                                  _RegisterRole.admin => 'Admin',
                                  _RegisterRole.provider => 'Provider',
                                }} Account',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  final _RegisterRole role;
  final ValueChanged<_RegisterRole> onChanged;

  const _RoleToggle({required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.appColors.neutralBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _segment(context, 'Student', _RegisterRole.student)),
          Expanded(child: _segment(context, 'Admin', _RegisterRole.admin)),
          Expanded(
            child: _segment(context, 'Provider', _RegisterRole.provider),
          ),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, _RegisterRole value) {
    final selected = role == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? Colors.white : context.appColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
