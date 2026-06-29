import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/user_profile_service.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'registration_screen.dart';

/// Splash / loading screen.
/// Full-screen gradient (Oceanic Noir → Nocturnal Expedition → Forsythia),
/// with the LiFe wordmark centred and the UB footer pinned at the bottom.
/// Performs authentication and session loading in the background,
/// transitioning immediately to the relevant screen when ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();
    Widget nextScreen;

    try {
      // 1. Get current auth state (resolve Firebase's cached user)
      final user = await FirebaseAuth.instance.authStateChanges().first;

      if (user == null) {
        nextScreen = const LoginScreen();
      } else {
        // 2. Check if the session is expired
        final isExpired = await UserProfileService().isSessionExpired(user.uid);
        if (isExpired) {
          await FirebaseAuth.instance.signOut();
          UserProfileService().clearProfile();
          nextScreen = const LoginScreen();
        } else {
          // 3. Load user profile from Firestore and check if it's first-time login
          await UserProfileService().loadFromFirestore(user.uid);
          final isFirst = await UserProfileService().checkIsFirstLogin(user.uid);
          if (isFirst) {
            nextScreen = RegistrationScreen(email: user.email ?? '');
          } else {
            nextScreen = const MainShell();
          }
        }
      }
    } catch (e) {
      // If anything fails (e.g. network timeout), fallback to the login screen
      nextScreen = const LoginScreen();
    }

    // Ensure the splash screen is visible for at least 2 seconds for branding
    final elapsed = DateTime.now().difference(startTime);
    const minDuration = Duration(milliseconds: 2000);
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
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
              const Spacer(flex: 5),
            ],
          ),
        ),
      ),
    );
  }
}
