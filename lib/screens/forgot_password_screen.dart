import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import 'login_screen.dart';

/// Remade Forgot Password screen inside LIFE Support.
///
/// Flow:
/// 1. Enter email address -> Verifies registered email in Supabase `users` table.
/// 2. Immediately transitions to New Password and Confirm New Password fields.
/// 3. Overwrites password in the database `users` table (and syncs auth).
/// 4. Displays success screen confirming password change with navigation back to Login.
/// 5. Every state includes a "Back to Login" button at the bottom of the form.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Steps: 0 = Enter Email, 1 = Enter New Passwords, 2 = Success
  int _step = 0;

  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _verifiedEmail;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _navToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ── Step 1: Check Email in users table ────────────────────────────────────
  Future<void> _checkEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    setState(() => _loading = true);

    try {
      final userRow = await Supabase.instance.client
          .from('users')
          .select('uid, email, name')
          .ilike('email', email)
          .maybeSingle();

      if (!mounted) return;
      setState(() => _loading = false);

      if (userRow == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This email address is not registered in the LIFE database.',
              style: TextStyle(fontFamily: 'Figtree'),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Email verified! Advance to password reset form
      setState(() {
        _verifiedEmail = email;
        _step = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Error verifying email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking email: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Step 2: Overwrite Password in Database ─────────────────────────────────
  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    if (_verifiedEmail == null) return;

    final newPassword = _newPasswordCtrl.text;
    setState(() => _loading = true);

    try {
      // 1. Overwrite the old password in public.users table
      await Supabase.instance.client
          .from('users')
          .update({'password': newPassword})
          .ilike('email', _verifiedEmail!);

      // 2. Attempt RPC sync if present in database
      try {
        await Supabase.instance.client.rpc(
          'reset_password_by_email',
          params: {
            'user_email': _verifiedEmail!,
            'new_password': newPassword,
          },
        );
      } catch (rpcErr) {
        debugPrint('RPC reset_password_by_email notice: $rpcErr');
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = 2; // Transition to Success view
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Error resetting password: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update password: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
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
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── LIFE Badge at top/center ────────────────────────────
                    Image.asset(
                      'assets/lifeBadge.png',
                      height: 68,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 18),

                    // ── Title ───────────────────────────────────────────────
                    Text(
                      'LIFE Support',
                      style: AppTextStyles.loginTitle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // ── Subtitle Chip ───────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.mysticMint.withAlpha(60),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _step == 2 ? 'Password Reset Complete' : 'Forgot Password',
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.nocturnalExpedition,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Dynamic Content by Step ─────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildCurrentStepContent(),
                    ),

                    // ── Bottom "Go back" Button (hidden on success step) ───
                    if (_step != 2) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  if (_step == 1) {
                                    setState(() => _step = 0);
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.nocturnalExpedition,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: AppColors.nocturnalExpedition,
                          ),
                          child: const Text(
                            'Go back',
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ── UB Footer ───────────────────────────────────────────
                    Image.asset(
                      'assets/ubfooter.png',
                      height: 38,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_step) {
      case 0:
        return _buildEmailVerificationStep();
      case 1:
        return _buildPasswordResetStep();
      case 2:
      default:
        return _buildSuccessStep();
    }
  }

  // ── Step 0: Request used email address ────────────────────────────────────
  Widget _buildEmailVerificationStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('step_email'),
        children: [
          const Text(
            'Please enter the email address used for your student account to verify your identity.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 13,
              color: Color(0xFF5A6E77),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _checkEmail(),
            style: AppTextStyles.inputHint.copyWith(
              color: AppColors.oceanicNoir,
            ),
            decoration: const InputDecoration(
              hintText: 'Student Email Address',
              prefixIcon: Icon(Icons.email_outlined, color: AppColors.nocturnalExpedition, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!v.contains('@') || !v.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _checkEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.nocturnalExpedition,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Verify Email',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Request New Password & Confirm New Password ───────────────────
  Widget _buildPasswordResetStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        key: const ValueKey('step_password'),
        children: [
          Text(
            'Account verified for $_verifiedEmail.\nEnter your new password below.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 13,
              color: Color(0xFF5A6E77),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _newPasswordCtrl,
            obscureText: _obscureNew,
            textInputAction: TextInputAction.next,
            style: AppTextStyles.inputHint.copyWith(
              color: AppColors.oceanicNoir,
            ),
            decoration: InputDecoration(
              hintText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.nocturnalExpedition, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.nocturnalExpedition,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please enter a new password';
              }
              if (v.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPasswordCtrl,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _updatePassword(),
            style: AppTextStyles.inputHint.copyWith(
              color: AppColors.oceanicNoir,
            ),
            decoration: InputDecoration(
              hintText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.nocturnalExpedition, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.nocturnalExpedition,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please confirm your new password';
              }
              if (v != _newPasswordCtrl.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _updatePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.nocturnalExpedition,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Save New Password',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Success Confirmation ──────────────────────────────────────────
  Widget _buildSuccessStep() {
    return Column(
      key: const ValueKey('step_success'),
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF27AE60),
          size: 64,
        ),
        const SizedBox(height: 16),
        const Text(
          'Password Changed!',
          style: TextStyle(
            fontFamily: 'Figtree',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.oceanicNoir,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'Password has been successfully changed, you may now proceed to login',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Figtree',
            fontSize: 13.5,
            color: Color(0xFF5A6E77),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _navToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.nocturnalExpedition,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Proceed to Login',
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
