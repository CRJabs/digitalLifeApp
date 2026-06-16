import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/user_profile_service.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Listens to Firebase Auth state changes and routes the user accordingly:
///   - No session  →  [LoginScreen]
///   - Active session →  loads Firestore profile, then shows [MainShell]
///
/// This is the root widget shown after the splash screen, replacing the old
/// hard-coded "always go to LoginScreen" approach.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While the stream is resolving the cached auth state, show a spinner.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.splashGradient),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          // No authenticated session — show login.
          return const LoginScreen();
        }

        // Authenticated session found — load the profile then show the shell.
        return FutureBuilder<void>(
          future: UserProfileService().loadFromFirestore(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                backgroundColor: Colors.transparent,
                body: DecoratedBox(
                  decoration:
                      BoxDecoration(gradient: AppColors.splashGradient),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              );
            }
            return const MainShell();
          },
        );
      },
    );
  }
}
