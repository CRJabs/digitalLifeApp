import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/attendee_service.dart';
import '../core/user_profile_service.dart';
import 'main_shell.dart';

/// First-login registration screen.
///
/// Shown once — immediately after sign-in — when the user has no row
/// in the Supabase [users] table. Collects profile data, saves it to
/// both Firestore and Supabase, then routes to [MainShell].
class RegistrationScreen extends StatefulWidget {
  /// The Firebase Auth email, pre-filled and locked in the email field.
  final String email;

  const RegistrationScreen({super.key, required this.email});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _programCtrl;

  String? _selectedDept;
  String? _selectedYear;

  bool _loading = false;

  static const _departments = [
    'CAHS', 'CASE', 'CBA', 'CCJ', 'CETAFA',
    'CHMTN', 'COL', 'COM', 'COP', 'CPTOT',
    'GSPS', 'UBGS', 'UBJHS', 'VDTJHS', 'VDTSHS',
  ];

  static const _yearLevels = [
    '1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController();
    _phoneCtrl   = TextEditingController();
    _programCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _programCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not signed in');

      final profile = UserProfileService();

      // 1. Save to Firestore + local cache
      await profile.updateProfile(
        uid: uid,
        newName: _nameCtrl.text.trim(),
        newEmail: widget.email,
        newPhone: _phoneCtrl.text.trim(),
        newDept: _selectedDept!,
        newProgram: _programCtrl.text.trim(),
        newYearLevel: _selectedYear!,
      );

      // 2. Save to Supabase users table (updateProfile already calls this)
      //    Ensure email field is from Firebase Auth (read-only in the form)

      // 3. Start attendee listening keyed by email
      await AttendeeService().startListening(widget.email);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Logo ──────────────────────────────────────────────
                      Center(
                        child: Image.asset(
                          'assets/lifeColored.png',
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Title ─────────────────────────────────────────────
                      Text(
                        'Complete Your Profile',
                        style: AppTextStyles.loginTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This information is required to track your\nattendance and dues.',
                        style: AppTextStyles.activitySubtitle.copyWith(
                          fontSize: 12,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // ── Full Name ─────────────────────────────────────────
                      _buildLabel('Full Name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        style: AppTextStyles.inputHint.copyWith(
                          color: AppColors.oceanicNoir,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Juan Dela Cruz',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 2) {
                            return 'Enter your full name (at least 2 characters)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Email (read-only) ─────────────────────────────────
                      _buildLabel('Email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        initialValue: widget.email,
                        readOnly: true,
                        style: AppTextStyles.inputHint.copyWith(
                          color: AppColors.nocturnalExpedition.withAlpha(160),
                        ),
                        decoration: InputDecoration(
                          hintText: widget.email,
                          filled: true,
                          fillColor: AppColors.arcticPowder,
                          suffixIcon: Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: AppColors.nocturnalExpedition.withAlpha(120),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Phone Number ──────────────────────────────────────
                      _buildLabel('Phone Number'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        style: AppTextStyles.inputHint.copyWith(
                          color: AppColors.oceanicNoir,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g. 09171234567',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your phone number';
                          }
                          final digits = v.replaceAll(RegExp(r'[\s\-+]'), '');
                          if (!RegExp(r'^\d+$').hasMatch(digits)) {
                            return 'Phone number may only contain digits, +, -, or spaces';
                          }
                          if (digits.length < 7) {
                            return 'Phone number must be at least 7 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Department ────────────────────────────────────────
                      _buildLabel('Department'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDept,
                        hint: const Text('Select department'),
                        items: _departments.map((d) {
                          return DropdownMenuItem(value: d, child: Text(d));
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedDept = v),
                        style: AppTextStyles.inputHint.copyWith(
                          color: AppColors.oceanicNoir,
                        ),
                        decoration: const InputDecoration(),
                        validator: (v) =>
                            v == null ? 'Please select your department' : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Program ───────────────────────────────────────────
                      _buildLabel('Program'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _programCtrl,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.characters,
                        style: AppTextStyles.inputHint.copyWith(
                          color: AppColors.oceanicNoir,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g. BSCS, BSN, BSBA',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your program';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Year Level ────────────────────────────────────────
                      _buildLabel('Year Level'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedYear,
                        hint: const Text('Select year level'),
                        items: _yearLevels.map((y) {
                          return DropdownMenuItem(value: y, child: Text(y));
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedYear = v),
                        style: AppTextStyles.inputHint.copyWith(
                          color: AppColors.oceanicNoir,
                        ),
                        decoration: const InputDecoration(),
                        validator: (v) =>
                            v == null ? 'Please select your year level' : null,
                      ),
                      const SizedBox(height: 28),

                      // ── Submit ────────────────────────────────────────────
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Save & Continue'),
                        ),
                      ),

                      // ── UB footer ─────────────────────────────────────────
                      const SizedBox(height: 28),
                      Center(
                        child: Image.asset(
                          'assets/ubfooter.png',
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 4),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.inputHint.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.oceanicNoir,
      ),
    );
  }
}
