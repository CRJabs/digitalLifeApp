import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import 'auth_gate.dart';

/// Splash / loading screen.
/// Full-screen gradient (Oceanic Noir → Nocturnal Expedition → Forsythia),
/// with the LiFe wordmark centred and the UB footer pinned at the bottom.
/// Navigates to [LoginScreen] after 3 seconds.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _goToLogin);
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 5),
              Image.asset('assets/life.png', width: 200, fit: BoxFit.contain),
              const SizedBox(height: 12),
              Text(
                'LOG OF INFORMATIVE AND\nFUN-FILLED EXPERIENCES',
                style: AppTextStyles.splashTagline,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 6),
              Image.asset(
                'assets/loginFooter.png',
                width: 180,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
