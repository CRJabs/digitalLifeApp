import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/user_profile_service.dart';
import '../core/security_service.dart';
import 'main_shell.dart';
import 'registration_screen.dart';
import 'life_support_hub_screen.dart';

/// Login screen.
/// The splash gradient is visible in the upper portion; a floating white
/// rounded card houses the LiFe colored logo, the login form, and the UB
/// footer image.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;


  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();

    // 1. Check local device cooldown
    final cooldownRemaining = await SecurityService().getLoginCooldownRemaining();
    if (!mounted) return;
    if (cooldownRemaining > 0) {
      String waitText = '$cooldownRemaining seconds';
      if (cooldownRemaining > 60) {
        waitText = '${(cooldownRemaining / 60).ceil()} minutes';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Too many failed login attempts. Please try again in $waitText.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 2. Check server-side account cooldown via fast RPC (0 bcrypt cost)
    final serverLimit = await SecurityService().checkServerRateLimit(email);
    if (!mounted) return;
    if (serverLimit['allowed'] == false) {
      final waitSec = (serverLimit['remaining_seconds'] as num?)?.toInt() ?? 60;
      await SecurityService().recordRateLimitHit(waitSec);
      if (!mounted) return;
      final waitText = waitSec > 60 ? '${(waitSec / 60).ceil()} minutes' : '$waitSec seconds';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account temporarily locked due to excessive failed attempts. Please try again in $waitText.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passwordCtrl.text,
      );

      final user = response.user;
      if (user == null) throw const AuthException('Login failed: User is null');

      // Clear both local and server failure counters on successful auth
      await SecurityService().recordLoginAttempt(true);
      await SecurityService().recordServerAttempt(email, true);

      // Load this user's profile from Supabase before routing.
      await UserProfileService().loadProfile();

      if (!mounted) return;

      // Check if the user has previously completed registration.
      final isFirstLogin = await UserProfileService().checkIsFirstLogin();

      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isFirstLogin
              ? RegistrationScreen(email: user.email ?? '')
              : const MainShell(),
        ),
      );
    } on AuthException catch (e) {
      final isRateLimit = e.statusCode == '429' ||
          e.message.toLowerCase().contains('rate limit') ||
          e.message.toLowerCase().contains('too many requests') ||
          e.code == 'over_request_rate_limit';
      final isNetwork = !isRateLimit && _isNetworkError(e.message);

      if (isRateLimit) {
        // Enforce 60-second backoff immediately
        await SecurityService().recordRateLimitHit(60);
      } else if (!isNetwork) {
        await SecurityService().recordLoginAttempt(false);
        await SecurityService().recordServerAttempt(email, false);
      }

      final newCooldown = await SecurityService().getLoginCooldownRemaining();

      if (!mounted) return;
      setState(() => _loading = false);
      
      String message;
      if (isRateLimit) {
        message = 'Server is busy due to high traffic. Rate limit reached; please wait 60 seconds before trying again.';
      } else if (isNetwork) {
        message = 'Network issue: Unable to connect to server. Please check your internet connection and try again.';
      } else if (newCooldown > 0) {
        String waitText = '$newCooldown seconds';
        if (newCooldown > 60) {
          waitText = '${(newCooldown / 60).ceil()} minutes';
        }
        message = 'Wrong credentials. Too many failed attempts: Login locked for $waitText.';
      } else {
        final lower = e.message.toLowerCase();
        if (lower.contains('invalid login credentials')) {
          message = 'Invalid email or password. Please try again.';
        } else if (lower.contains('email not confirmed')) {
          message = 'Please confirm your email address before logging in.';
        } else if (lower.contains('exception') || lower.contains('http') || lower.contains('uri=')) {
          message = 'Unable to log in. Please check your credentials and try again.';
        } else {
          message = e.message;
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      final isNetwork = _isNetworkError(e.toString());
      if (!isNetwork) {
        await SecurityService().recordLoginAttempt(false);
        await SecurityService().recordServerAttempt(email, false);
      }
      if (!mounted) return;
      debugPrint('Login unexpected error: $e');
      setState(() => _loading = false);
      
      final message = isNetwork
          ? 'Network issue: Unable to connect to server. Please check your internet connection and try again.'
          : 'Login failed. Please check your connection and try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  bool _isNetworkError(String errorMsg) {
    final lower = errorMsg.toLowerCase();
    if (lower.contains('rate limit') ||
        lower.contains('invalid login') ||
        lower.contains('over_request_rate_limit') ||
        lower.contains('429') ||
        lower.contains('400')) {
      return false;
    }
    return lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection timed out') ||
        lower.contains('timed out') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('handshakeexception') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('errno =');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── LiFe blue text logo ───────────────────────────
                      Image.asset(
                        'assets/lifeTextBlue.png',
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 32),

                      // ── Title ──────────────────────────────────────────
                      Text(
                        'Login to your account',
                        style: AppTextStyles.loginTitle,
                      ),
                      const SizedBox(height: 22),

                      // ── Email ──────────────────────────────────────────
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: AppTextStyles.inputHint.copyWith(
                          color: AppColors.oceanicNoir,
                        ),
                        decoration: const InputDecoration(hintText: 'Email'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your email';
                          }
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Password ───────────────────────────────────────
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (v) => _signIn(),
                        style: AppTextStyles.inputHint.copyWith(
                          color: AppColors.oceanicNoir,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.nocturnalExpedition,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),

                      // ── Sign In button ─────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signIn,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Sign In'),
                        ),
                      ),
                      // ── Need help signing in? ─────────────────────────
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LifeSupportHubScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Need help signing in?',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.nocturnalExpedition,
                          ),
                        ),
                      ),

                      // ── UB footer ──────────────────────────────────────
                      const SizedBox(height: 32),
                      Image.asset(
                        'assets/ubfooter.png',
                        height: 44,
                        fit: BoxFit.contain,
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
}
