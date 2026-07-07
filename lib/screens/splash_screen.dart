import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/session_service.dart';
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
    Widget nextScreen = const LoginScreen(); // safe default
    String? errorMessage;

    try {
      // ── Step 1: Run session invalidation checks ───────────────────────────
      // Signs out automatically if build number changed, user changed, or
      // the session has been inactive for more than 3 days.
      final wasInvalidated =
          await SessionService().checkAndInvalidateIfNeeded();
      if (wasInvalidated) {
        nextScreen = const LoginScreen();
      } else {
        // ── Step 2: Check Supabase session ──────────────────────────────────
        final session = Supabase.instance.client.auth.currentSession;

        if (session == null || session.isExpired) {
          nextScreen = const LoginScreen();
        } else {
          // ── Step 3: Load user profile ────────────────────────────────────
          await UserProfileService().loadProfile().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('Splash: loadProfile timed out');
            },
          );

          final hasLocalProfile = UserProfileService().name.isNotEmpty;

          if (hasLocalProfile) {
            // Returning user with cached data — proceed normally.
            await SessionService().recordActivity();
            nextScreen = const MainShell();
          } else {
            // Cache is empty; attempt a definitive first-login check.
            bool isFirst = false;
            try {
              isFirst = await UserProfileService()
                  .checkIsFirstLogin()
                  .timeout(const Duration(seconds: 5));
            } catch (e) {
              // Network unavailable and no local cache — cannot verify this
              // account. Deny entry and ask the user to reconnect.
              debugPrint('Splash: checkIsFirstLogin failed or timed out: $e');
              await Supabase.instance.client.auth.signOut();
              errorMessage =
                  'Account authentication failed. Please try again later.';
              nextScreen = const LoginScreen();
              isFirst = false; // skip the block below
            }

            if (errorMessage == null) {
              if (isFirst) {
                nextScreen =
                    RegistrationScreen(email: session.user.email ?? '');
              } else {
                await SessionService().recordActivity();
                nextScreen = const MainShell();
              }
            }
          }
        }
      }
    } catch (e) {
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

    // Show error snackbar after navigation completes, if applicable.
    if (errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    }
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
