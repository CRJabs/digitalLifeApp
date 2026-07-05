import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      // Get current Supabase session
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null || session.isExpired) {
        nextScreen = const LoginScreen();
      } else {
        // Load user profile from Supabase with a timeout to prevent hanging
        await UserProfileService().loadProfile().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Splash: loadProfile timed out, using local cache');
          },
        );

        // Check if local cache has profile (if name is not empty, they are not a first-time user)
        bool isFirst = false;
        if (UserProfileService().name.isEmpty) {
          try {
            isFirst = await UserProfileService()
                .checkIsFirstLogin()
                .timeout(const Duration(seconds: 3));
          } catch (e) {
            debugPrint('Splash: checkIsFirstLogin failed or timed out: $e');
            // Fallback: If offline and cache is empty, we assume they need to register
            isFirst = true;
          }
        }

        if (isFirst) {
          nextScreen = RegistrationScreen(email: session.user.email ?? '');
        } else {
          nextScreen = const MainShell();
        }
      }
    } catch (e) {
      // If anything fails, fallback to the login screen
      debugPrint('Splash: Error initializing app: $e');
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
