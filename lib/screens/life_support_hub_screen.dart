import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import 'forgot_password_screen.dart';
import 'request_info_edits_screen.dart';

/// Central support hub screen accessed from "Need help signing in?".
class LifeSupportHubScreen extends StatelessWidget {
  const LifeSupportHubScreen({super.key});

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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── LIFE Badge at Center ────────────────────────────────
                    Image.asset(
                      'assets/lifeBadge.png',
                      height: 68,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 18),

                    // ── Title: LIFE Support ─────────────────────────────────
                    Text(
                      'LIFE Support',
                      style: AppTextStyles.loginTitle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // ── Subtitle ────────────────────────────────────────────
                    const Text(
                      'Select an option below for assistance with your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 13,
                        color: Color(0xFF5A6E77),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Button 1: Edit Information ──────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RequestInfoEditsScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.nocturnalExpedition,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          side: const BorderSide(
                            color: AppColors.mysticMint,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_note_rounded, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Edit Information',
                              style: TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Button 2: Forgot Password ───────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.nocturnalExpedition,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_reset_rounded, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Forgot Password',
                              style: TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Bottom "Go back" Button ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.nocturnalExpedition, width: 1.2),
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
}
