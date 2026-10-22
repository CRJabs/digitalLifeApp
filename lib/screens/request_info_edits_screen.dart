import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

/// Screen displayed when user selects "Request edits to Information" in LIFE Support.
class RequestInfoEditsScreen extends StatelessWidget {
  const RequestInfoEditsScreen({super.key});

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
                    // ── LIFE Badge ──────────────────────────────────────────
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

                    // ── Subtitle / Badge ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.mysticMint.withAlpha(60),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Edit Information',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.nocturnalExpedition,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Body Text ───────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'In compliance with the Data Privacy Act and under the agreement with the UB National SSG, all student information is kept safely stored under limited access. For changes regarding their personal information, kindly reach out to the UB National SSG Officers and raise the concern, or send a request through the Send Feedback section in the settings page.',
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 13.5,
                          height: 1.6,
                          color: AppColors.oceanicNoir,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Go back Button ──────────────────────────────────────
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

                    // ── UB footer ───────────────────────────────────────────
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
