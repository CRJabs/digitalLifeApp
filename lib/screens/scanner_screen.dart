import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/app_colors.dart';
import '../core/user_profile_service.dart';

/// Scanner / QR tab (tab 1).
/// Shows the LiFe logo at the top, the user's own QR code centered on screen,
/// and the user's student information below.
/// The full background uses the splash gradient.
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.splashGradient),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: UserProfileService(),
          builder: (context, _) {
            final profile = UserProfileService();
            return Column(
              children: [
                // ── LiFe white logo at the top ────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 8),
                  child: Image.asset(
                    'assets/life.png',
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                ),

                // ── Center everything else in remaining space ─────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 128px gap between Life logo and QR card
                        const SizedBox(height: 128),

                        // ── QR Code card ──────────────────────────────────
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // QR fills card inner width: available width minus card padding (24 each side)
                            final qrSize = constraints.maxWidth - 48;
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(30),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: profile.toQrData(),
                                version: QrVersions.auto,
                                size: qrSize,
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── Student Info Card ─────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.oceanicNoir.withAlpha(120),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withAlpha(60),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                profile.name,
                                style: const TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${profile.department}  |  ${profile.program} - ${profile.yearLevel}',
                                style: TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withAlpha(200),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Notice text ───────────────────────────────────
                        Text(
                          'Note: The generated QR code is temporary and will change after 24 hours.',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 12,
                            color: Colors.white.withAlpha(180),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Bottom padding to account for floating navbar
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
